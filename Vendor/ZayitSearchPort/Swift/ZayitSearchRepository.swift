import Foundation

actor ZayitSearchRepository {
    private let engine=ZayitSearchEngineBridge()
    private(set) var configured=false
    func configure(paths:ZayitSearchDataPaths)throws{try engine.open(paths:paths);configured=true}
    func search(query:String,near:UInt32,offset:Int,limit:Int,filters:ZayitSearchFilters)throws->ZayitSearchPage{
        try engine.search(.init(query:query,near:near,limit:limit,offset:offset,filters:filters))
    }
}
