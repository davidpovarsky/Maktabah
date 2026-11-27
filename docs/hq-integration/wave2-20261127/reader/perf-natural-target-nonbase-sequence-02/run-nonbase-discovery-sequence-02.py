#!/usr/bin/env python3
"""Eight authorized sequential bounded metadata batches; never native acceptance."""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path('/mnt/development/projects/worktrees/Maktabah-wave2-reader-20261127')
EVIDENCE = ROOT / 'docs/hq-integration/wave2-20261127/reader'
OUT = EVIDENCE / 'perf-natural-target-nonbase-sequence-02'
PRIOR = EVIDENCE / 'perf-natural-target-batch17-recovered-v40'
PRIOR_SHA = '8af14e90b134f165878f46d60e1117066bbad8c55bf672167244c5c7d43545a2'
BASE_SCRIPT_SHA = 'e19936b68fbbdebf54241e98b0ffd3f782880c299662610b0a9acf91c7bd13cf'
SELECTION = '''SELECT b.id,b.title,b.totalLines,b.isBaseBook
FROM book b WHERE b.isBaseBook=0 AND b.totalLines BETWEEN 100 AND 10000
AND b.id > {after_id} AND b.id NOT IN (103,28,3152)
AND EXISTS (SELECT 1 FROM tocEntry t WHERE t.bookId=b.id)
ORDER BY b.id LIMIT 40'''

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    assert OUT.is_dir() and not (OUT / 'SEQUENCE_RESULT.json').exists()
    prior_bytes = (PRIOR / 'DISCOVERY.json').read_bytes()
    assert sha(prior_bytes) == PRIOR_SHA
    assert json.loads((PRIOR / 'RUN_RESULT.json').read_text())['exit'] == 0
    base = (EVIDENCE / 'perf-natural-target-batch08-recovered-v40/discover-natural-inspector-batch08.py').read_text()
    assert sha(base.encode()) == BASE_SCRIPT_SHA
    old_selection = next(ast.literal_eval(n.value) for n in ast.parse(base).body
        if isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', None) == 'SELECTION')
    report = {'schema': 1, 'status': 'RUNNING_BOUNDED_READ_ONLY_DISCOVERY',
        'startedAtUnix': time.time(), 'maxBatches': 8, 'maxAttemptedBooks': 320,
        'scope': 'Candidate metadata only; no original Swift service or UI acceptance',
        'scriptSHA256': sha(Path(__file__).read_bytes()), 'batches': []}
    def save():
        (OUT / 'SEQUENCE_RESULT.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    save()
    prior = PRIOR
    after_id = 818
    attempted = 0
    try:
        for number in range(18, 26):
            previous_bytes = (prior / 'DISCOVERY.json').read_bytes()
            previous = json.loads(previous_bytes)
            cumulative = {k: len(v) + previous['priorCandidateReceipt']['candidateCounts'][k]
                for k, v in previous['exactCandidates'].items()}
            if all(cumulative[k] >= 2 for k in ('100', '500', '2000')):
                report['stopReason'] = 'two_complete_natural_candidates_per_scale'; break
            destination = EVIDENCE / ('perf-natural-target-batch%02d-recovered-v40' % number)
            assert not destination.exists()
            source = base.replace("OUT = ROOT/'docs/hq-integration/wave2-20261127/reader/perf-natural-target-batch08-recovered-v40'",
                "OUT = ROOT/" + repr(str(destination.relative_to(ROOT))))
            source = source.replace("'sourceLinesPerBook':50000", "'sourceLinesPerBook':10000")
            source = source.replace("SOURCE = '019bda89d5d107aabd09dcb6ffbb1edf367c4fe8'", "SOURCE = '35ce9feeb6b43f87230943502c5413a98a1b74d4'")
            assert old_selection in source
            source = source.replace(old_selection, SELECTION.format(after_id=after_id))
            source, n = re.subn(r"previous_batch=ROOT/'[^']+'", "previous_batch=ROOT/" + repr(str((prior / 'DISCOVERY.json').relative_to(ROOT))), source)
            assert n == 1
            source, n = re.subn(r"assert digest\(previous_bytes\)=='[a-f0-9]{64}'", "assert digest(previous_bytes)==" + repr(sha(previous_bytes)), source)
            assert n == 1
            ast.parse(source)
            destination.mkdir()
            script = destination / ('discover-natural-inspector-batch%02d.py' % number)
            script.write_text(source)
            step = {'number': number, 'directory': str(destination), 'scriptSHA256': sha(source.encode()),
                'previousReceiptSHA256': sha(previous_bytes), 'afterBookID': after_id, 'startedAtUnix': time.time()}
            report['batches'].append(step); save()
            with (destination / 'stdout.log').open('xb') as output:
                result = subprocess.run(['python3', str(script)], stdout=output, stderr=subprocess.STDOUT, timeout=330)
            run = {'startedAtUnix': step['startedAtUnix'], 'finishedAtUnix': time.time(), 'exit': result.returncode,
                'scope': 'bounded read-only SQL, not Swift or native UI'}
            (destination / 'RUN_RESULT.json').write_text(json.dumps(run, indent=2) + '\n')
            assert result.returncode == 0
            data = (destination / 'DISCOVERY.json').read_bytes(); actual = json.loads(data)
            assert actual['scriptSHA256'] == step['scriptSHA256']
            ids = [book['bookID'] for book in actual['books']]
            assert ids == sorted(set(ids)) and all(i > after_id for i in ids)
            attempted += len(ids); assert attempted <= 320
            step.update(run=run, resultSHA256=sha(data), attemptedBooks=len(ids),
                completeUnits=actual['completeCandidateUnits'], seconds=actual['seconds'],
                exactCandidateCounts={k: len(v) for k, v in actual['exactCandidates'].items()})
            print(json.dumps(step), flush=True); save()
            prior = destination
            if len(actual['selectedBooks']) < 40 and len(ids) == len(actual['selectedBooks']):
                report['stopReason'] = 'eligible_selected_population_exhausted'; break
            if not ids:
                report['stopReason'] = 'no_complete_or_attempted_book_before_cap'; break
            after_id = max(ids)
        else:
            report['stopReason'] = 'authorized_eight_batch_cap'
        report['status'] = 'BOUNDED_READ_ONLY_SEQUENCE_COMPLETE_NOT_SWIFT_OR_UI'
        report['attemptedBooks'] = attempted
        report['lastReceipt'] = str(prior / 'DISCOVERY.json')
    except Exception as error:
        report['status'] = 'FAILED_NO_ACCEPTANCE'
        report['error'] = repr(error)
        raise
    finally:
        report['finishedAtUnix'] = time.time(); save()

if __name__ == '__main__':
    main()
