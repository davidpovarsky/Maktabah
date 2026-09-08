import Foundation

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String { if case .failed(let message) = self { return message }; return "failure" }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.failed(message) }
}

func fixture(_ name: String) throws -> Data {
    let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    return try Data(contentsOf: tests.deletingLastPathComponent()
        .appendingPathComponent("SefariaMobileReference/Fixtures/\(name)"))
}

extension Notification.Name {
    static let libraryFolderChanged = Notification.Name("libraryFolderChanged")
}
