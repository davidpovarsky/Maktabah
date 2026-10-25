//
//  TalmudHebrewAddressFormatter.swift
//  Maktabah
//
//  Downstream-owned formatter for traditional Hebrew Talmud daf/amud notation.
//

import Foundation

enum TalmudHebrewAddressFormatter: Sendable {
    /// Formats a zero-based Sefaria Talmud offset (0 = 2a) into a traditional Hebrew string (e.g. "י״ב ע״א").
    static func format(offset: Int) -> String {
        let dafNumber = (offset / 2) + 2
        let isAmudA = offset.isMultiple(of: 2)
        let amudStr = isAmudA ? "ע״א" : "ע״ב"
        let dafHebrew = hebrewDafNumeral(from: dafNumber)
        return "\(dafHebrew) \(amudStr)"
    }

    /// Formats an address string such as "12a", "12b", "15b", "16a" into traditional Hebrew notation.
    /// If unparseable as a Talmud address, falls back gracefully to the input string.
    static func format(address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastChar = trimmed.last, lastChar == "a" || lastChar == "b" || lastChar == "A" || lastChar == "B" else {
            return address
        }
        let numberPart = String(trimmed.dropLast())
        guard let dafNumber = Int(numberPart), dafNumber >= 2 else {
            return address
        }
        let isAmudA = (lastChar == "a" || lastChar == "A")
        let amudStr = isAmudA ? "ע״א" : "ע״ב"
        let dafHebrew = hebrewDafNumeral(from: dafNumber)
        return "\(dafHebrew) \(amudStr)"
    }

    /// Converts a number to traditional Hebrew numeral with proper gersh/gershayim and special 15/16 handling.
    static func hebrewDafNumeral(from number: Int) -> String {
        guard number > 0 else { return "\(number)" }

        let hundreds = ["", "ק", "ר", "ש", "ת", "תק", "תר", "תש", "תת", "תתק"]
        let tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]
        let units = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]

        var n = number
        var rawLetters = ""

        if n >= 100 {
            rawLetters += hundreds[min(n / 100, 9)]
            n %= 100
        }

        if n == 15 {
            rawLetters += "טו"
        } else if n == 16 {
            rawLetters += "טז"
        } else {
            rawLetters += tens[n / 10]
            rawLetters += units[n % 10]
        }

        // Apply traditional punctuation: gersh (׳) for single letter, gershayim (״) before last letter.
        let count = rawLetters.count
        if count == 0 {
            return "\(number)"
        } else if count == 1 {
            return rawLetters + "׳"
        } else {
            let lastIndex = rawLetters.index(before: rawLetters.endIndex)
            var result = rawLetters
            result.insert(contentsOf: "״", at: lastIndex)
            return result
        }
    }
}
