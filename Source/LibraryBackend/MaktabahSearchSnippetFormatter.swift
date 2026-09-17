import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum MaktabahSearchSnippetFormatter {
    public static func formatSnippet(_ html: String) -> (attributedString: NSAttributedString, highlightTerms: [String]) {
        var highlightTerms: [String] = []
        let mutable = NSMutableAttributedString(string: "")
        
        let pattern = "<(/?[a-zA-Z0-9]+)(?:\\s+[^>]*)?/?>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (NSAttributedString(string: html), [])
        }
        
        let nsString = html as NSString
        var currentIndex = 0
        var isBold = false
        var isItalic = false
        
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            let tagRange = match.range
            if tagRange.location > currentIndex {
                let textChunk = nsString.substring(with: NSRange(location: currentIndex, length: tagRange.location - currentIndex))
                let decoded = decodeEntities(textChunk)
                if !decoded.isEmpty {
                    let attrs = attributes(isBold: isBold, isItalic: isItalic)
                    mutable.append(NSAttributedString(string: decoded, attributes: attrs))
                    if isBold || isItalic {
                        highlightTerms.append(contentsOf: extractWords(from: decoded))
                    }
                }
            }
            
            let tagMatch = nsString.substring(with: tagRange)
            let isClosing = tagMatch.hasPrefix("</")
            let rawTagName = nsString.substring(with: match.range(at: 1)).lowercased()
            let tagName = rawTagName.hasPrefix("/") ? String(rawTagName.dropFirst()) : rawTagName
            
            switch tagName {
            case "b", "strong":
                isBold = !isClosing
            case "em", "i":
                isItalic = !isClosing
            case "br", "p":
                if !isClosing || tagName == "p" {
                    mutable.append(NSAttributedString(string: "\n"))
                }
            default:
                break
            }
            
            currentIndex = tagRange.location + tagRange.length
        }
        
        if currentIndex < nsString.length {
            let textChunk = nsString.substring(with: NSRange(location: currentIndex, length: nsString.length - currentIndex))
            let decoded = decodeEntities(textChunk)
            if !decoded.isEmpty {
                let attrs = attributes(isBold: isBold, isItalic: isItalic)
                mutable.append(NSAttributedString(string: decoded, attributes: attrs))
                if isBold || isItalic {
                    highlightTerms.append(contentsOf: extractWords(from: decoded))
                }
            }
        }
        
        var seen = Set<String>()
        let uniqueTerms = highlightTerms.filter { seen.insert($0).inserted }
        
        return (mutable, uniqueTerms)
    }
    
    public static func attributes(isBold: Bool, isItalic: Bool) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [:]
        if isBold {
            attrs[NSAttributedString.Key("NSBold")] = true
        }
        if isItalic {
            attrs[NSAttributedString.Key("NSItalic")] = true
        }
        #if canImport(UIKit)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if isBold { traits.insert(.traitBold) }
        if isItalic { traits.insert(.traitItalic) }
        if !traits.isEmpty {
            let base = UIFont.systemFont(ofSize: 15)
            if let descriptor = base.fontDescriptor.withSymbolicTraits(traits) {
                attrs[.font] = UIFont(descriptor: descriptor, size: 15)
            } else if isBold {
                attrs[.font] = UIFont.boldSystemFont(ofSize: 15)
            }
        }
        #elseif canImport(AppKit)
        if isBold {
            attrs[.font] = NSFont.boldSystemFont(ofSize: 15)
        }
        #endif
        return attrs
    }
    
    public static func decodeEntities(_ text: String) -> String {
        var res = text
        let entities: [(String, String)] = [
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&nbsp;", " "),
            ("&amp;", "&")
        ]
        for (ent, val) in entities {
            res = res.replacingOccurrences(of: ent, with: val)
        }
        if let decRegex = try? NSRegularExpression(pattern: "&#([0-9]+);") {
            let ns = res as NSString
            let matches = decRegex.matches(in: res, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let codeStr = ns.substring(with: m.range(at: 1))
                if let code = UInt32(codeStr), let scalar = UnicodeScalar(code) {
                    let charStr = String(Character(scalar))
                    res = (res as NSString).replacingCharacters(in: m.range, with: charStr)
                }
            }
        }
        if let hexRegex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);") {
            let ns = res as NSString
            let matches = hexRegex.matches(in: res, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let codeStr = ns.substring(with: m.range(at: 1))
                if let code = UInt32(codeStr, radix: 16), let scalar = UnicodeScalar(code) {
                    let charStr = String(Character(scalar))
                    res = (res as NSString).replacingCharacters(in: m.range, with: charStr)
                }
            }
        }
        return res
    }
    
    public static func extractWords(from text: String) -> [String] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return words
    }
}
