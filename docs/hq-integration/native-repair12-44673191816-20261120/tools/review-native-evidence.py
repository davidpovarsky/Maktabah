#!/usr/bin/env python3
"""Read original native evidence. No app execution or synthesized pass result."""
from pathlib import Path
import argparse, collections, hashlib, json, zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(identifier):
    return identifier[:-2] if identifier.endswith('()') else identifier


def nodes(value):
    if isinstance(value, dict):
        yield value
        for item in value.values():
            yield from nodes(item)
    elif isinstance(value, list):
        for item in value:
            yield from nodes(item)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--expected-sha256', required=True)
    parser.add_argument('--checkout-sha', required=True)
    parser.add_argument('--application-sha', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    h = hashlib.sha256()
    with args.archive.open('rb') as source:
        for block in iter(lambda: source.read(4 * 1024 * 1024), b''):
            h.update(block)
    assert h.hexdigest() == args.expected_sha256, 'Original ZIP digest mismatch'
    manifest_bytes = args.manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    expected_groups = manifest['execution_groups']
    expected_ids = manifest['execution_case_ids']
    assert len(expected_ids) == len(set(expected_ids))
    assert set(expected_ids) == {c for g in expected_groups for c in g['case_ids']}
    errors, records, groups, entry_hashes = [], [], [], {}
    with zipfile.ZipFile(args.archive) as archive:
        names = set(archive.namelist())
        def read(name):
            data = archive.read(name)
            entry_hashes[name] = {'bytes': len(data), 'sha256': digest(data)}
            return json.loads(data)
        result = read('artifacts/runtime27/result.json')
        build = read('hq-stage2/result.json')
        for label, value, expected in [
            ('runtime checkout', result.get('checkout_sha'), args.checkout_sha),
            ('build checkout', build.get('checkout_sha'), args.checkout_sha),
            ('application source', build.get('application_source_sha'), args.application_sha),
            ('requested cases', result.get('requested_ui_case_count'), len(expected_ids)),
            ('manifest digest', result.get('case_manifest_sha256'), digest(manifest_bytes)),
        ]:
            if value != expected:
                errors.append({'check':label, 'actual':value, 'expected':expected})
        for group in expected_groups:
            label, expected = group['label'], group['case_ids']
            prefix = 'artifacts/runtime27/verified-' + label
            present = prefix + '.tests.json' in names and prefix + '.summary.json' in names
            if not present:
                groups.append({'label':label, 'expected':len(expected), 'recorded':0,
                               'passed':0, 'failed':0, 'skipped':0, 'not_run':len(expected),
                               'missing_original_xcresult_exports':True,
                               'driver_observation':result.get('actual_counts_by_device',{}).get(label)})
                for case in expected:
                    records.append({'case_id':case, 'group':label, 'result':'NOT_RUN', 'failures':[]})
                continue
            tree, summary = read(prefix+'.tests.json'), read(prefix+'.summary.json')
            actual = []
            for node in nodes(tree.get('testNodes', [])):
                if node.get('nodeType') != 'Test Case':
                    continue
                case = canonical(node.get('nodeIdentifier',''))
                failures = [{'text':n.get('name'), 'source':n.get('sourceLocation')}
                            for n in nodes(node.get('children', [])) if n.get('nodeType')=='Failure Message']
                if not failures and node.get('result') not in ['Passed','Skipped']:
                    failures = [{'text':f.get('failureText')} for f in summary.get('testFailures', [])
                                if canonical(f.get('testIdentifierString','')) == case]
                actual.append({'case_id':case, 'group':label, 'result':node.get('result'),
                               'duration_seconds':node.get('durationInSeconds'), 'failures':failures})
            ids = [n['case_id'] for n in actual]
            duplicate = [k for k,v in collections.Counter(ids).items() if v!=1]
            if duplicate:
                errors.append({'check':'duplicate case nodes', 'group':label,'cases':duplicate})
            unexpected = sorted(set(ids)-set(expected))
            if unexpected:
                errors.append({'check':'unexpected cases', 'group':label,'cases':unexpected})
            missing = sorted(set(expected)-set(ids))
            count = collections.Counter(n['result'] for n in actual)
            for key, observed in [('passedTests',count['Passed']),('failedTests',count['Failed']),
                                  ('skippedTests',count['Skipped']),('totalTestCount',len(actual))]:
                if summary.get(key) != observed:
                    errors.append({'check':'summary versus actual case nodes','group':label,
                                   'field':key,'summary':summary.get(key),'observed':observed})
            unknown = sorted(str(k) for k in count if k not in ['Passed','Failed','Skipped'])
            if unknown:
                errors.append({'check':'unaccepted case status','group':label,'values':unknown})
            groups.append({'label':label,'expected':len(expected),'recorded':len(actual),
                           'passed':count['Passed'],'failed':count['Failed'],'skipped':count['Skipped'],
                           'not_run':len(missing),'summary_result':summary.get('result'),
                           'summary_failures':summary.get('testFailures',[]),'devices':tree.get('devices',[])})
            records.extend(actual)
            records.extend({'case_id':c,'group':label,'result':'NOT_RUN','failures':[]} for c in missing)
        count = collections.Counter(n['result'] for n in records)
        for key, measured in [('executed_ui_pass',count['Passed']),('executed_ui_fail',count['Failed']),
                              ('executed_ui_skip',count['Skipped']),('ui_not_run',count['NOT_RUN'])]:
            if result.get(key)!=measured:
                errors.append({'check':'driver versus independent case counts','field':key,
                               'reported':result.get(key),'observed':measured})
        reported = {r['case_id']:r.get('actual') for r in result.get('case_outcomes',[])}
        for row in records:
            if reported.get(row['case_id']) != row['result']:
                errors.append({'check':'driver versus named case','case':row['case_id'],
                               'reported':reported.get(row['case_id']),'observed':row['result']})
        review = {'zip':{'path':str(args.archive),'bytes':args.archive.stat().st_size,'sha256':h.hexdigest()},
                  'checkout_sha':result.get('checkout_sha'),'application_sha':build.get('application_source_sha'),
                  'hanlin_gitlink':build.get('hanlin_gitlink'),'application_trees':build.get('application_trees'),
                  'manifest_sha256':digest(manifest_bytes),'expected_count':len(expected_ids),
                  'counts':{'passed':count['Passed'],'failed':count['Failed'],'skipped':count['Skipped'],
                            'not_run':count['NOT_RUN'],'recorded':len(records)-count['NOT_RUN']},
                  'provenance_or_count_errors':errors,'groups':groups,'cases':records,
                  'driver_status':result.get('status'),'driver_error':result.get('error'),
                  'original_entry_hashes':entry_hashes,
                  'zero_skips_observed':count['Skipped']==0,'all_required_executed':count['NOT_RUN']==0,
                  'all_required_passed':not errors and count['Passed']==len(expected_ids)
                                        and not count['Failed'] and not count['Skipped'] and not count['NOT_RUN'],
                  'new_execution_performed_by_this_review':False}
    args.output.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'output':str(args.output),'counts':review['counts'],'errors':errors,
                      'failures':[r for r in records if r['result'] not in ['Passed']]},ensure_ascii=False))


if __name__=='__main__':
    main()
