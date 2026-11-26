import Foundation
struct SefariaTextsV3DTO: Codable, Sendable {
    let versions: [SefariaVersion]
    let ref: String
    let heRef: String?
    let sectionRef: String
    let next: String?
    let prev: String?
    let indexTitle: String
}

