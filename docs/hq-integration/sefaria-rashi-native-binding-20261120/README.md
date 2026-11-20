# English Rashi Native row binding

The source-reviewed test opened Rashi chapter 2 and immediately asserted that visible label 1 was unique. The original row is a SwiftUI Group plus recursive ForEach, with no parent accessibility container; English chapter 1 and chapter 2 verse 1 can both be visible. This is an impossible intermediate test assumption, not a demonstrated product failure.

Only that English Rashi call now allows the existing at-most-two list swipes to resolve the duplicate label. Every successful return still requires exactly one original visible/hittable row, and the final Rashi on Genesis 2 canonical Reader, actual text, and capture checks are unchanged. Hebrew and every other row call retain the previous immediate duplicate assertion. No first-match or coordinate fallback was added.

SOURCE_PRESERVATION.json records the three exact replacements and their byte-exact inverse. The original 12 case declarations, deadline, swipe budget, and all other source bytes are preserved. No Apple compilation or Native execution has been performed for this source change.
