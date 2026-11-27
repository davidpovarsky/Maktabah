#!/usr/bin/env python3
"""Authorized bounded metadata candidates; not Swift or original UI acceptance."""
import hashlib
import json
import pathlib
import resource
import runpy
import sqlite3
import subprocess
import time

ROOT = pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave2-reader-20261127')
PREVIOUS = ROOT/'docs/hq-integration/wave2-20261127/reader/perf-natural-target-review-recovered-v40'
OUT = ROOT/'docs/hq-integration/wave2-20261127/reader/perf-natural-target-batch10-recovered-v40'
SOURCE = '019bda89d5d107aabd09dcb6ffbb1edf367c4fe8'
GUIDE_SHA = 'ef881c729c815c93a0c65cb960f000ea38b221d1cd51c8202a1f04f467a956af'
CAPS = {'books':40, 'secondsPerBook':20, 'secondsTotal':300, 'rowsPerBook':500000,
        'rowsTotal':3000000, 'unitsTotal':6000, 'sourceLinesPerBook':10000,
        'processVirtualMemoryBytes':512*1024*1024, 'stopAfterCandidatesEach':2}
SELECTION = '''SELECT b.id,b.title,b.totalLines,b.isBaseBook
FROM book b WHERE b.isBaseBook=0 AND b.totalLines BETWEEN 100 AND 10000
AND b.id > 427 AND b.id NOT IN (103,28,3152)
AND EXISTS (SELECT 1 FROM tocEntry t WHERE t.bookId=b.id)
ORDER BY b.id LIMIT 40'''


def digest(value):
    return hashlib.sha256(value).hexdigest()


def encoded(value):
    return json.dumps(value,ensure_ascii=False,separators=(',',':')).encode()


def dump(path,value):
    with path.open('x') as stream:
        json.dump(value,stream,ensure_ascii=False,indent=2)
        stream.write('\n')


def stat_identity(value):
    return (value.st_dev,value.st_ino,value.st_size,value.st_mtime_ns,value.st_ctime_ns)


class BoundReached(Exception):
    pass


def main():
    resource.setrlimit(resource.RLIMIT_AS,(CAPS['processVirtualMemoryBytes'],CAPS['processVirtualMemoryBytes']))
    guide_path=PREVIOUS/'discover-natural-inspector-counts.py'
    assert digest(guide_path.read_bytes())==GUIDE_SHA
    guide=runpy.run_path(str(guide_path))
    db=guide['DB']; before=db.stat(); recovery_bytes=guide['IDENTITY'].read_bytes()
    assert digest(recovery_bytes)==guide['IDENTITY_SHA']
    recovery=json.loads(recovery_bytes); identity=recovery['sourceDatabase']['identity']
    assert recovery['sourceDatabase']['path']==str(db) and recovery['sourceDatabase']['sha256']==guide['EXPECTED_SHA']
    assert stat_identity(before)==tuple(identity[key] for key in ('device','inode','bytes','mtimeNs','ctimeNs'))
    assert before.st_mode & 0o777==0o444
    assert recovery['counts']=={'book':8259,'line':7925185,'link':7001824} and recovery['quickCheck']==['ok']
    prior=json.loads((PREVIOUS/'DISCOVERY.json').read_bytes()); hashes={}
    for name,expected in prior['sourceSHA256'].items():
        data=subprocess.check_output(['git','-c','gc.auto=0','-C',str(ROOT),'show',SOURCE+':'+name])
        hashes[name]=digest(data); assert hashes[name]==expected
    # The unit adapter uses rawSources.map, then caches the whole array. The
    # generic single-line provider's later locator/type/category dedup is not
    # this route. The same original LineSources id/book/line key is used below.
    source_binding={'commit':SOURCE,'sha256':hashes,'priorSourceReceipt':str(PREVIOUS/'DISCOVERY.json'),
                    'priorSourceReceiptSHA256':digest((PREVIOUS/'DISCOVERY.json').read_bytes()),
                    'guideScriptSHA256':GUIDE_SHA,'adapterPath':'getLinksMetadataForReadingUnit -> rawSources.map -> remember(links:)',
                    'dedupKey':['linkId','linkedBookId','linkedLineId'],'genericLineProviderDedupApplied':False}
    OUT.mkdir(parents=True,exist_ok=True)
    assert not (OUT/'DISCOVERY.json').exists()
    (OUT/'selection.sql').write_text(SELECTION+'\n')
    (OUT/'relationships.sql').write_text(guide['SQL'])
    previous_batch=ROOT/'docs/hq-integration/wave2-20261127/reader/perf-natural-target-batch09-recovered-v40/DISCOVERY.json'
    previous_bytes=previous_batch.read_bytes()
    assert digest(previous_bytes)=='d7365647996a591b0c19ecdd75280cf8224d5a6b9d3140abd434d6e466d7714a'
    previous=json.loads(previous_bytes)
    previous_counts={key:len(value)+previous['priorCandidateReceipt']['candidateCounts'][key]
                     for key,value in previous['exactCandidates'].items()}
    started=time.monotonic(); global_deadline=started+CAPS['secondsTotal']; total_rows=0; total_units=0
    reports=[]; candidates={str(n):[] for n in (100,500,2000)}
    stop_reason='selected_book_batch_exhausted'
    connection=sqlite3.connect(db.as_uri()+'?mode=ro&immutable=1',uri=True)
    connection.execute('PRAGMA query_only=ON')
    assert connection.execute('PRAGMA query_only').fetchone()==(1,)
    connection.execute('PRAGMA cache_size=-8192')
    connection.execute('PRAGMA temp_store=MEMORY')
    connection.set_progress_handler(lambda:int(time.monotonic()>=global_deadline),10000)
    selected=[dict(zip(('bookID','bookTitle','declaredTotalLines','isBaseBook'),row)) for row in connection.execute(SELECTION)]
    dump(OUT/'SELECTED_BOOKS.json',{'sql':SELECTION,'books':selected,'source':source_binding,'caps':CAPS})
    for chosen in selected:
        book_start=time.monotonic()
        if book_start>=global_deadline or total_rows>=CAPS['rowsTotal'] or total_units>=CAPS['unitsTotal']:
            stop_reason='global_bound_reached_before_next_book';break
        book=chosen['bookID']; deadline=min(global_deadline,book_start+CAPS['secondsPerBook'])
        connection.set_progress_handler(lambda:int(time.monotonic()>=deadline),10000)
        consumed=0; units=[]; cursor=None; memberships=None; owner=None
        try:
            units,owner=guide['groups'](connection,book)
            if total_units+len(units)>CAPS['unitsTotal']:
                raise BoundReached('Complete book would exceed the total unit cap; no units admitted')
            memberships=[set() for _ in units]
            cursor=connection.execute(guide['SQL'],[book]*5)
            while True:
                if consumed>=CAPS['rowsPerBook'] or total_rows>=CAPS['rowsTotal']:
                    raise BoundReached('Metadata row bound; entire book excluded')
                if time.monotonic()>=deadline:
                    raise BoundReached('Book/global deadline; entire book excluded')
                row=cursor.fetchone()
                if row is None:break
                consumed+=1;total_rows+=1
                link,linked_book,linked_line,anchor=row
                assert anchor in owner
                memberships[owner[anchor]].add((link,linked_book,linked_line))
            completed=[]
            for unit,membership in zip(units,memberships):
                if time.monotonic()>=deadline:raise BoundReached('Finalizing book exceeded deadline; entire book excluded')
                indices=unit['sourceLineIndices']
                actual={**unit,'bookID':book,'bookTitle':chosen['bookTitle'],'mode':'chapter',
                        'unitStartLineIndex':indices[0],'unitEndLineIndex':indices[-1],'unitRowCount':len(indices),
                        'candidateRawRelationshipCount':len(membership),'sourceIndicesSHA256':digest(encoded(indices)),
                        'rawMembershipSHA256':digest(encoded(sorted(membership)))}
                if str(len(membership)) in candidates:
                    actual['candidateRawMembership']=sorted(membership)
                completed.append(actual)
            report={**chosen,'status':'COMPLETE_BOOK_METADATA_CANDIDATES_ONLY','seconds':time.monotonic()-book_start,
                    'resolvedAnchorRows':consumed,'units':completed}
            total_units+=len(completed)
            for unit in completed:
                count=str(unit['candidateRawRelationshipCount'])
                if count in candidates:candidates[count].append(unit)
        except (BoundReached,sqlite3.OperationalError,MemoryError,AssertionError) as error:
            report={**chosen,'status':'ENTIRE_BOOK_EXCLUDED_NO_PARTIAL_COUNT_CLAIM','seconds':time.monotonic()-book_start,
                    'resolvedAnchorRowsReadBeforeExclusion':consumed,'errorType':type(error).__name__,'error':str(error)}
        finally:
            if cursor is not None:cursor.close()
            memberships=None;owner=None
        reports.append(report)
        dump(OUT/('book-'+str(book)+'.json'),report)
        print(json.dumps({'bookID':book,'status':report['status'],'seconds':report['seconds'],
              'totalRows':total_rows,'completedUnits':total_units,'exactCandidates':{k:len(v) for k,v in candidates.items()}},ensure_ascii=False),flush=True)
        if all(len(value)+previous_counts[key]>=CAPS['stopAfterCandidatesEach'] for key,value in candidates.items()):
            stop_reason='two_complete_natural_candidates_for_each_requested_count';break
    connection.close()
    after=db.stat();assert stat_identity(before)==stat_identity(after)
    elapsed=time.monotonic()-started
    result={'schema':1,'status':'BOUNDED_READ_ONLY_NATURAL_CANDIDATES_NOT_SWIFT_OR_UI_ACCEPTANCE',
            'source':source_binding,'database':{'path':str(db),'bytes':before.st_size,'sha256FromCompletedRecovery':guide['EXPECTED_SHA'],
                'device':before.st_dev,'inode':before.st_ino,'mtimeNs':before.st_mtime_ns,'ctimeNs':before.st_ctime_ns,
                'recoveryReceipt':str(guide['IDENTITY']),'recoveryReceiptSHA256':guide['IDENTITY_SHA'],'freshFullHashPerformed':False,
                'priorDeletedInodeContinuityClaimed':False,'inAppInstallationClaimed':False},
            'priorCandidateReceipt':{'path':str(previous_batch),'sha256':digest(previous_bytes),'candidateCounts':previous_counts},
            'caps':CAPS,'seconds':elapsed,'stopReason':stop_reason,'selectedBooks':selected,'books':reports,
            'resolvedAnchorRowsRead':total_rows,'completeCandidateUnits':total_units,'exactCandidates':candidates,
            'maxResidentBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,
            'querySHA256':digest(guide['SQL'].encode()),'selectionSHA256':digest(SELECTION.encode()),
            'scriptSHA256':digest(pathlib.Path(__file__).read_bytes()),'nativeUIExecuted':0,'adapterExecuted':False,
            'scope':'Complete natural source-guided SQL candidates only. Original Swift unit membership, unit adapter/cache, and genuine native UI must independently verify final selected targets.'}
    dump(OUT/'DISCOVERY.json',result)
    print(json.dumps({'path':str(OUT/'DISCOVERY.json'),'seconds':elapsed,'stopReason':stop_reason,
                     'completeUnits':total_units,'exactCandidateCounts':{k:len(v) for k,v in candidates.items()},
                     'actualMaxResidentBytes':result['maxResidentBytes']},ensure_ascii=False),flush=True)


if __name__=='__main__':main()
