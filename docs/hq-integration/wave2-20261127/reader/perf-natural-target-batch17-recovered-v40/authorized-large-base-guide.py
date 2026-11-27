#!/usr/bin/env python3
"""Bounded read-only candidates, not Swift adapter or original UI acceptance."""
import collections, datetime, hashlib, json, pathlib, sqlite3, subprocess, time

ROOT = pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave2-reader-20261127')
DB = pathlib.Path('/mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/corpus-v40-recovery-20261127/seforim.db')
IDENTITY = pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave2-search-20261127/docs/hq-integration/wave2-20261127/search/corpus-restore/RESTORE_RESULT.json')
IDENTITY_SHA = '768d333cceb7e9d5e05bcb299f1ee579c8acd5174c5aec54c3afe76e0c074afb'
OUT = ROOT/'docs/hq-integration/wave2-20261127/reader/perf-natural-target-review-recovered-v40'
SOURCE = 'a1e12fd377c0909df535c96d1a61f54bef5001a7'
EXPECTED_SHA = '8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01'
BOOKS = [103,28,3152]
DEPENDENT = ['COMMENTARY','SUPER_COMMENTARY','TARGUM','MIDRASH','PARSHANUT','DIBUR_HAMATCHIL','ELUCIDATION','EXPLICATION','FOOTNOTES']
REFERENCE = ['REFERENCE','QUOTATION','MESORAT_HASHAS','EIN_MISHPAT','MISHNAH_IN_TALMUD','RELATED','OTHER','SIFREI_MITZVOT','ESSAY','ALLUSION','LITURGY','LAW','SUMMARY']
literal = lambda names: ','.join("'"+x+"'" for x in names)

SQL = f"""
WITH win(id) AS (SELECT id FROM line WHERE bookId=?),
matched(linkId,matchedSide,anchorLineId) AS (
 SELECT id,0,sourceLineId FROM link WHERE sourceBookId=? AND sourceLineId IN (SELECT id FROM win)
 UNION SELECT link.id,0,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId
       WHERE c.side=0 AND link.sourceBookId=? AND c.lineId IN (SELECT id FROM win)
 UNION SELECT id,1,targetLineId FROM link WHERE targetBookId=? AND targetLineId IN (SELECT id FROM win)
 UNION SELECT link.id,1,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId
       WHERE c.side=1 AND link.targetBookId=? AND c.lineId IN (SELECT id FROM win)
), resolved AS (
 SELECT DISTINCT link.id AS linkId,matched.anchorLineId,
   CASE matched.matchedSide WHEN 0 THEN link.targetLineId ELSE link.sourceLineId END AS linkedLineId,
   CASE matched.matchedSide WHEN 0 THEN link.targetBookId ELSE link.sourceBookId END AS linkedBookId
 FROM matched JOIN link ON link.id=matched.linkId
 LEFT JOIN connection_type ON connection_type.id=link.connectionTypeId
 WHERE (matched.matchedSide=0 AND NOT EXISTS (
   SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0))
 OR (matched.matchedSide=1 AND connection_type.name IN ({literal(DEPENDENT+REFERENCE)})
   AND NOT EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=1)
   AND (link.sourceBookId!=link.targetBookId OR (
     connection_type.name IN ({literal(REFERENCE)}) AND (
       EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0)
       OR (matched.anchorLineId!=link.sourceLineId AND NOT EXISTS (
         SELECT 1 FROM link_coverage c WHERE c.linkId=link.id AND c.side=0 AND c.lineId=matched.anchorLineId))
     )
   )))
)
SELECT resolved.linkId,resolved.linkedBookId,resolved.linkedLineId,resolved.anchorLineId
FROM resolved JOIN line linked_line ON linked_line.id=resolved.linkedLineId
JOIN book linked_book ON linked_book.id=resolved.linkedBookId
"""

def groups(sql, book):
    entries = {r[0]:(r[1],r[2],r[3]) for r in sql.execute('SELECT te.id,te.parentId,COALESCE(te.level,0),COALESCE(tt.text,\'\') FROM tocEntry te LEFT JOIN tocText tt ON tt.id=te.textId WHERE te.bookId=?',(book,))}
    children = collections.defaultdict(list)
    for entry,(parent,_,_) in entries.items():
        if parent is not None: children[parent].append(entry)
    leaves, line_ids = {}, {}
    for line_id,index,entry in sql.execute('SELECT l.id,l.lineIndex,lt.tocEntryId FROM line l LEFT JOIN line_toc lt ON lt.lineId=l.id WHERE l.bookId=? ORDER BY l.lineIndex,lt.tocEntryId',(book,)):
        line_ids[index] = line_id
        if entry in entries and (index not in leaves or entries[leaves[index]][1] < entries[entry][1]): leaves[index]=entry
    assert 0 < len(line_ids) <= 50000
    root_counts = collections.Counter(leaf for leaf in leaves.values() if entries[leaf][0] is None and children[leaf])
    root_titles = {key for key,count in root_counts.items() if count <= 3}
    def root(entry):
        seen=set()
        while entry in entries and entries[entry][0] is not None:
            assert entry not in seen, 'Cycle'; seen.add(entry); entry=entries[entry][0]
        return entry
    def chapter(leaf):
        current=best=leaf; seen=set()
        while current in entries:
            assert current not in seen, 'Cycle'; seen.add(current)
            parent=entries[current][0]
            if parent not in entries: return best
            if entries[parent][0] is not None: best=parent
            current=parent
        return best
    by_unit,held={},collections.defaultdict(list)
    for index,leaf in sorted(leaves.items()):
        if leaf in root_titles: held[leaf].append(index); continue
        entry=chapter(leaf)
        if entry not in by_unit: by_unit[entry]=held.pop(root(entry),[])
        by_unit[entry].append(index)
    for entry,lines in sorted(held.items()): by_unit.setdefault(entry,lines)
    mapped=set(x for xs in by_unit.values() for x in xs)
    units=[]
    for entry,lines in by_unit.items():
        lines=sorted(lines)
        units.append({'unitID':'toc:'+str(entry),'rawUnitTitle':entries[entry][2],'sourceLineIndices':lines})
    for index in sorted(set(line_ids)-mapped): units.append({'unitID':'line:'+str(index),'rawUnitTitle':None,'sourceLineIndices':[index]})
    units.sort(key=lambda x:x['sourceLineIndices'][0])
    assert set(x for u in units for x in u['sourceLineIndices']) == set(line_ids)
    assert sum(len(u['sourceLineIndices']) for u in units) == len(line_ids)
    owner={line_ids[index]:i for i,u in enumerate(units) for index in u['sourceLineIndices']}
    return units,owner

def main():
    before=DB.stat(); assert before.st_size==4355063808 and DB.resolve()==DB
    identity_bytes=IDENTITY.read_bytes(); previous=json.loads(identity_bytes)
    # Reuse the completed recovery's full-file audit, explicitly bound to this
    # newly recovered inode. Do not repeat the hash or claim old-inode/UI proof.
    assert hashlib.sha256(identity_bytes).hexdigest() == IDENTITY_SHA
    assert previous['status'] == 'OFFICIAL_V40_CORPUS_RECONSTRUCTED_FULL_SHA_AND_READONLY_COUNTS_VERIFIED'
    source = previous['sourceDatabase']; identity = source['identity']
    assert source['path'] == str(DB) and source['sha256'] == EXPECTED_SHA and source['bytes'] == before.st_size
    assert (before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns) == (identity['device'],identity['inode'],identity['bytes'],identity['mtimeNs'],identity['ctimeNs'])
    assert before.st_mode & 0o777 == 0o444
    sql_receipt = previous['sqlReceipt']; sql_bytes = pathlib.Path(sql_receipt['path']).read_bytes()
    assert len(sql_bytes) == sql_receipt['bytes'] and hashlib.sha256(sql_bytes).hexdigest() == sql_receipt['sha256']
    assert previous['counts'] == {'book':8259,'line':7925185,'link':7001824} and previous['quickCheck'] == ['ok']
    hashes={}
    for path in ['Source/Otzaria/Reading/OtzariaReadingUnitService.swift','Source/Otzaria/Reading/OtzariaLineSourcesService.swift','Source/Otzaria/Reading/OtzariaInspectorRelationshipsProvider.swift','Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift']:
        data=subprocess.check_output(['git','-c','gc.auto=0','-C',str(ROOT),'show',SOURCE+':'+path])
        hashes[path]=hashlib.sha256(data).hexdigest()
    started=time.monotonic(); reports=[]
    sql=sqlite3.connect(DB.as_uri()+'?mode=ro&immutable=1',uri=True)
    sql.execute('PRAGMA query_only=ON'); assert sql.execute('PRAGMA query_only').fetchone()==(1,)
    tables={r[0] for r in sql.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    assert {'link_coverage','link_suppressed_side','line_toc','tocEntry','tocText'} <= tables
    for book in BOOKS:
        book_start=time.monotonic(); deadline=book_start+60
        sql.set_progress_handler(lambda: int(time.monotonic()>deadline),10000)
        title=sql.execute('SELECT title FROM book WHERE id=?',(book,)).fetchone()[0]
        units,owner=groups(sql,book); memberships=[set() for _ in units]; rows=0
        for link,linked_book,linked_line,anchor in sql.execute(SQL,[book]*5):
            rows+=1; assert rows<=500000, 'Bound original metadata discovery rows'
            assert anchor in owner
            memberships[owner[anchor]].add((link,linked_book,linked_line))
        for unit,membership in zip(units,memberships):
            indices=unit['sourceLineIndices']; unit.update({'bookID':book,'bookTitle':title,'mode':'chapter','unitStartLineIndex':indices[0],
                'unitEndLineIndex':indices[-1],'unitRowCount':len(indices),'candidateRawRelationshipCount':len(membership),
                'sourceIndicesSHA256':hashlib.sha256(json.dumps(indices,separators=(',',':')).encode()).hexdigest(),
                'rawMembershipSHA256':hashlib.sha256(json.dumps(sorted(membership),separators=(',',':')).encode()).hexdigest()})
        indices=sorted(owner); source_indices=sorted({x for u in units for x in u['sourceLineIndices']})
        exploration={name:next(u['unitID'] for u in units if source_indices[offset] in u['sourceLineIndices']) for name,offset in [('first',0),('middle',len(source_indices)//2),('last',len(source_indices)-1)]}
        reports.append({'bookID':book,'bookTitle':title,'seconds':time.monotonic()-book_start,'matchedAnchorRows':rows,'units':units,'originalNineTargetPositions':exploration})
    sql.close(); after=DB.stat()
    assert (before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns)
    all_units=[u for b in reports for u in b['units']]
    exact={str(n):[{k:v for k,v in u.items() if k!='sourceLineIndices'} for u in all_units if u['candidateRawRelationshipCount']==n] for n in [100,500,2000]}
    result={'schema':1,'status':'READ_ONLY_NATURAL_COUNT_CANDIDATES_NOT_SWIFT_OR_UI_ACCEPTANCE','nativeUIExecuted':0,'adapterExecuted':False,
        'sourceCommit':SOURCE,'sourceSHA256':hashes,'database':{'path':str(DB),'bytes':before.st_size,'device':before.st_dev,'inode':before.st_ino,'mtimeNs':before.st_mtime_ns,'ctimeNs':before.st_ctime_ns,
            'recoveryFullHashReceipt':str(IDENTITY),'recoveryFullHashReceiptSHA256':hashlib.sha256(identity_bytes).hexdigest(),'recoveryFullHash':EXPECTED_SHA,'freshFullHashPerformed':False,'priorDeletedInodeContinuityClaimed':False,'inAppInstallationClaimed':False,'recoverySQLReceipt':sql_receipt},
        'bookIDsExamined':BOOKS,'seconds':time.monotonic()-started,'querySHA256':hashlib.sha256(SQL.encode()).hexdigest(),
        'dedupKey':['linkId','linkedBookId','linkedLineId'],'scope':'Exact-source-guided SQL candidates; original Swift unit/adapter and full native cache/UI must independently verify each selected target.',
        'counts':reports,'exactCandidates':exact,'scriptSHA256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()}
    OUT.mkdir(parents=True,exist_ok=True)
    destination=OUT/'DISCOVERY.json'; assert not destination.exists()
    destination.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    (OUT/'discovery-query.sql').write_text(SQL)
    (OUT/'discover-natural-inspector-counts.py').write_text(pathlib.Path(__file__).read_text())
    print(json.dumps({'path':str(destination),'seconds':result['seconds'],'units':len(all_units),'exactCandidateCounts':{k:len(v) for k,v in exact.items()},'originalNineCounts':{str(b['bookID']):{k:next(u['candidateRawRelationshipCount'] for u in b['units'] if u['unitID']==v) for k,v in b['originalNineTargetPositions'].items()} for b in reports}},ensure_ascii=False))

if __name__=='__main__': main()
