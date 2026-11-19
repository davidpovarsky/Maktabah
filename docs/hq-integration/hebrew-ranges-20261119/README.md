# Hebrew source highlight ranges — 2026-11-19

The original matcher mapped normalized Unicode-scalar positions back to UTF-16 source positions, but looked up matches using grapheme-cluster distances. Multi-scalar graphemes (combining accents, joined emoji, flags and variation selectors) could move or truncate a later Hebrew highlight.

The fix maps every retained normalized UTF-16 code unit to its original UTF-16 position, then uses Foundation's NSRange for the matched normalized range. Existing Hebrew-diacritic removal, punctuation, comparison behavior, ordering and deduplication stay in the original implementation. The plain-text normalizer and both search engines are unchanged.

The same independent literal-source range fixture was run against the complete String extension:

| Source | Cases passed | Failed | Native UI passes |
| --- | --- | --- | --- |
| b3871b1ff65baa92c56ca3bd960a53be8c18221e | 6 | 9 | 0 |
| Corrected source, SHA-256 e62731fccc95328cb6284809e6e4b464ab83e064ed2117d7da1bf8c0ff9a826a | 15 | 0 | 0 |

Fixture SHA-256: 9b6aa93c3fa5db6264691c7b48e5de91a2ad84ab3c5c79851b011914fa72d45a.
Real Swift 6.3.3 / Windows Foundation, not an emulated matcher. BEFORE_RESULT.json and AFTER_RESULT.json preserve exact cases, expected and actual ranges, commands and source hashes.

The same driver is wired into the existing macOS SDK verification job so Apple Foundation is independently checked. Actual UIKit/TextKit rendering remains in the Native Search/Reader suite. This correction must not be credited to the older b387 Native70 run.
