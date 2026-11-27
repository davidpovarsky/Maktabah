from pathlib import Path
import hashlib,json,difflib,zipfile
R=Path(__file__).parent
P='Source/Features/Annotations/iOS/iOSAnnotationViewController.swift'
old=(R.parent/'annotations-expansion-followup/candidate'/P).read_text()
assert hashlib.sha256(old.encode()).hexdigest()=='e38eafa86b8aebdf34166da0d9fe3b182ac44fdcdf5c2549fea8f0d9026a14cd'
before='func nativeRoutingReveal(_ row: NativeRoutingRow, validate: @MainActor () throws -> Void) throws'
after='func nativeRoutingReveal(_ row: NativeRoutingRow, validate: @escaping @MainActor () throws -> Void) throws'
assert old.count(before)==1
new=old.replace(before,after)
assert new.replace(after,before)==old
for name,text in [('baseline',old),('candidate',new)]:
 p=R/name/P;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
def method(s,signature):
 a=s.index(signature);b=s.index('{',a)+1;depth=1
 while depth:depth+=(s[b]=='{')-(s[b]=='}');b+=1
 return s[a:b]
C=R/'controls';C.mkdir(exist_ok=True)
prior=R.parent/'annotations-selection-analysis/controls'
capsule=(prior/'ActualAnnotationControllerCapsule.swift').read_text()
original=(R.parent/'annotations-selection-analysis/candidate'/P).read_text()
for name,source in [('OriginalCaller',old),('CandidateCaller',new)]:
 result=capsule
 for signature in ['    private func setOriginalGroupExpanded(','    func nativeRoutingReveal(']:
  pre=method(original,signature);post=method(source,signature)
  assert result.count(pre)==1;result=result.replace(pre,post)
 result=result.replace('            dataSource.sections[value.0] = .init(items: [.group(group),.annotation(item)])', '''            dataSource.sections[value.0] = .init(items: [.group(group),.annotation(item)])
            let groupCell = UICollectionViewCell(collectionView.window); groupCell.parent = viewIfLoaded
            groupCell.contentConfiguration = ListContentConfiguration(isExpanded: false)
            collectionView.cells[IndexPath(indexes:[position,0])] = groupCell''',1)
 (C/(name+'.swift')).write_text(result)
boundary=(prior/'ExplicitAnnotationBoundary.swift').read_text()
pre='    static func animate(withDuration: Double, delay: Double, options: AnimationOptions, animations: () -> Void) { animations() }'
post='''    static var holdAnimation = false
    static var heldAnimation: (@MainActor () -> Void)?
    static func animate(withDuration: Double, delay: Double, options: AnimationOptions, animations: @escaping @MainActor () -> Void) {
        if holdAnimation { heldAnimation = animations } else { animations() }
    }'''
assert boundary.count(pre)==1;boundary=boundary.replace(pre,post)
pre='@MainActor class UICollectionViewCell: UIView { var isSelected = false; var contentConfiguration: Any? }'
post='''@MainActor class UICollectionViewCell: UIView {
    var isSelected = false
    private(set) var configurationWrites = 0
    var contentConfiguration: Any? { didSet { configurationWrites += 1 } }
}'''
assert boundary.count(pre)==1;boundary=boundary.replace(pre,post)
(C/'ExplicitAnnotationBoundary.swift').write_text(boundary)
owner=(prior/'AnnotationOwnerControls.swift').read_text()
fixture=owner[:owner.index('@main struct AnnotationOwnerControls')]
(C/'ActualBindingFixture.swift').write_text(fixture)
for name in ['ActualOriginalRootPublication.swift','ActualWindowObservation.swift']:
 (C/name).write_bytes((prior/name).read_bytes())
for name in ['MaktabahNativeAnnotationListPublication.swift','MaktabahNativeAnnotationSelectionBinding.swift']:
 p='Source/ChavrusaText/UIRoutingHost/Integration/'+name
 b=(R.parent/'annotations-selection-analysis/candidate'/p).read_bytes()
 dest=R/'unchanged'/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
proof={'base':'56a6ff0c4d9437924479444660b51ce62e59db7e','path':P,'before':before,'after':after,'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(new.encode()).hexdigest(),'exact_inverse':new.replace(after,before)==old,
 'caller_capsule':'Complete original nativeRoutingReveal plus expansion helper, in the previously verified finite original controller extension; surrounding UIKit/domain declarations explicit. Existing weak-self/weak-Pending binding callback compiled unchanged.',
 'fixture_changes':'Original group cell installed in explicit DataSource fixture; UIKit animation declaration now correctly escaping and can retain a callback; config writes counted in fixture only.'}
(R/'SOURCE_INVERSE.json').write_text(json.dumps(proof,indent=2,sort_keys=True)+'\n')
(R/'SOURCE.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),'a/'+P,'b/'+P)))
print(json.dumps(proof))
