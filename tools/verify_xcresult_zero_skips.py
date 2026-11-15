#!/usr/bin/env python3
"""Fail closed on actual named xcresult UI execution; never infer DB effects."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote


def require(condition, message):
    if not condition:
        raise ValueError(message)


def case_id(value):
    match = re.search(r'(?:^|/)(\w+)/(test\w+)(?:\(\))?$', unquote(value))
    require(match is not None, 'Invalid named UI case: ' + value)
    return match[1] + '/' + match[2]


def parse_xcodebuild_log(text):
    results = {'passed': set(), 'failed': set(), 'skipped': set()}
    for line in text.splitlines():
        match = re.search(r"Test Case '-\[(\S+)\s+(test\w+)\]'\s+(passed|failed|skipped)", line)
        if not match:
            match = re.search(r"Test [Cc]ase '(\w+)\.(test\w+)\(\)'\s+(passed|failed|skipped)", line)
        if match:
            results[match[3]].add(match[1].split('.')[-1] + '/' + match[2])
    counts = [int(v) for v in re.findall(r'Executed\s+(\d+)\s+tests?', text)]
    return {**{k: sorted(v) for k, v in results.items()}, 'executed': max(counts, default=0)}


def parse_test_tree(tree, target):
    require(isinstance(tree, dict) and isinstance(tree.get('testNodes'), list), 'Missing xcresult testNodes')
    cases = {}

    def visit(node, bundle=None, suite=None):
        require(isinstance(node, dict), 'Corrupt xcresult node')
        kind, name, result = node.get('nodeType'), node.get('name', ''), node.get('result')
        if result is not None:
            require(result in ('Passed', 'Success'), 'Nonpassing xcresult node: ' + str(result))
        require(kind != 'Unit test bundle', 'Unit test bundle cannot satisfy UI acceptance')
        if kind == 'UI test bundle':
            bundle = name.removesuffix('.xctest')
        elif kind == 'Test Suite':
            suite = name.split('.')[-1]
        elif kind == 'Test Case':
            require(bundle == target, 'Unexpected/non-UI test bundle: ' + str(bundle))
            require(result == 'Passed', 'Test case has no explicit Passed result')
            identifier = node.get('testIdentifier') or node.get('nodeIdentifier')
            if identifier and re.search(r'/test\w+(?:\(\))?$', unquote(identifier)):
                identity = case_id(identifier)
            else:
                require(suite is not None, 'UI case has no suite identity')
                identity = case_id(suite + '/' + name)
            require(identity not in cases, 'Duplicate/retried UI case: ' + identity)
            cases[identity] = {'status': result, 'identifier': identifier,
                               'identifierURL': node.get('nodeIdentifierURL'), 'target': bundle}
        children = node.get('children', [])
        require(isinstance(children, list), 'Corrupt xcresult children')
        for child in children:
            visit(child, bundle, suite)

    for node in tree['testNodes']:
        visit(node)
    require(bool(cases), 'No parsed executed UI test cases')
    return cases


def verify(summary, tree, log, required_cases, min_tests, target='Maktabah-iOSUITests', min_total_tests=1):
    require(type(min_tests) is int and min_tests > 0, '--min-tests must be positive')
    require(type(min_total_tests) is int and min_total_tests > 0, '--min-total-tests must be positive')
    required = [case_id(value) for value in required_cases]
    require(required and len(required) == len(set(required)), 'Required named UI scope missing/duplicated')
    require(len(required) >= min_tests, 'Required UI scope smaller than --min-tests')
    require(isinstance(summary, dict), 'Missing/corrupt xcresult summary')
    for key in ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests'):
        require(type(summary.get(key)) is int and summary[key] >= 0, 'Missing/invalid xcresult count: ' + key)
    require(summary.get('result') == 'Passed', 'xcresult summary did not pass')
    require(summary['failedTests'] == 0 and summary['skippedTests'] == 0, 'xcresult contains failed/skipped tests')
    require(not summary.get('testFailures') and not summary.get('expectedFailures'), 'xcresult contains failures/expected failures')
    require(summary['totalTestCount'] == summary['passedTests'] >= min_total_tests, 'xcresult total/passed count empty/inconsistent')
    cases = parse_test_tree(tree, target)
    require(len(cases) == summary['totalTestCount'], 'xcresult summary/tree count mismatch')
    require(set(required) <= cases.keys(), 'Required UI cases absent: ' + str(sorted(set(required) - cases.keys())))
    logs = parse_xcodebuild_log(log)
    require(not logs['failed'] and not logs['skipped'], 'Log contradicts zero-failure/zero-skip results')
    require(set(logs['passed']) == cases.keys(), 'Log/xcresult case identity mismatch')
    require(logs['executed'] == len(cases), 'Log/xcresult execution count mismatch')
    require('** TEST SUCCEEDED **' in log and '** TEST FAILED **' not in log, 'Missing/contradictory final test outcome')
    return {'status': 'EXECUTED_PASS', 'target': target, 'executed_total': len(cases),
            'required_ui_passed': len(required), 'required_ui_cases': sorted(required),
            'cases': cases, 'skipped': 0, 'failed': 0, 'database_open': 'NOT_VERIFIED_BY_TEST_COUNTS'}


def read_xcresult(path, subcommand):
    require(path.is_dir(), 'Missing xcresult bundle')
    # Modern subcommands emit JSON by default; retain installed help/schema in CI.
    result = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', subcommand, '--path', str(path)],
                            check=True, capture_output=True, text=True, timeout=120)
    value = json.loads(result.stdout)
    require(isinstance(value, dict), 'Invalid xcresult JSON object')
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--xcresult', required=True, type=Path)
    parser.add_argument('--log', required=True, type=Path)
    parser.add_argument('--scope', required=True, choices=['focused-ui', 'production-ui'])
    parser.add_argument('--required-case', required=True, action='append', help='Reviewed real UI Suite/testMethod; unit/SDK probes do not count')
    parser.add_argument('--min-tests', type=int, default=1, help='Positive minimum of required real UI cases')
    parser.add_argument('--min-total-tests', type=int, default=1, help='Positive minimum actual total, including separate non-UI probes')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    report = {'status': 'FAIL', 'scope': args.scope, 'database_open': 'NOT_VERIFIED_BY_TEST_COUNTS'}
    try:
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
        summary = read_xcresult(args.xcresult, 'summary')
        tree = read_xcresult(args.xcresult, 'tests')
        for label, value in [('summary', summary), ('tests', tree)]:
            encoded = json.dumps(value, sort_keys=True).encode()
            report[label + '_sha256'] = hashlib.sha256(encoded).hexdigest()
            if args.out:
                args.out.with_suffix('.' + label + '.json').write_text(json.dumps(value, indent=2) + '\n')
        report.update(verify(summary, tree, args.log.read_text(encoding='utf-8'), args.required_case,
                             args.min_tests, min_total_tests=args.min_total_tests))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        report['error'] = str(error)
        print('::error::' + str(error), file=sys.stderr)
    finally:
        if args.out:
            args.out.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2))
    return 0 if report['status'] == 'EXECUTED_PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
