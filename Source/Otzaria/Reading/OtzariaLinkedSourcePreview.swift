import Foundation

extension OtzariaLinkedSource {
    var previewText: String {
        let plain = text
        guard plain.count > 220 else { return plain }
        return "\(plain.prefix(220))…"
    }

    var hasLongText: Bool {
        text.count > 220
    }
}
