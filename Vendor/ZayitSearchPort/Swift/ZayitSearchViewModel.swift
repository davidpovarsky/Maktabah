import Foundation

@MainActor final class ZayitSearchViewModel:ObservableObject{
    @Published var query=""; @Published var near:UInt32=5; @Published var hits:[ZayitSearchHit]=[]; @Published var isLoading=false; @Published var errorMessage:String?; @Published var configured=false
    private let repository:ZayitSearchRepository; private var generation=0
    init(repository:ZayitSearchRepository){self.repository=repository}
    func configure(paths:ZayitSearchDataPaths){Task{do{try await repository.configure(paths:paths);configured=true}catch{errorMessage=error.localizedDescription}}}
    func reset(){ configured=false; hits=[]; errorMessage=nil }
    func runSearch(){generation+=1;let g=generation;let q=query.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty else{hits=[];return};isLoading=true;Task{do{let page=try await repository.search(query:q,near:near,offset:0,limit:50,filters:.init());guard g==generation else{return};hits=page.hits;errorMessage=nil}catch{guard g==generation else{return};errorMessage=error.localizedDescription}isLoading=false}}
}
