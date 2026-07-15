use crate::hebrew_text_utils::{replace_finals_with_base, strip_diacritics_with_map};
use std::collections::HashSet;

pub fn build_snippet(
    raw: &str,
    anchor_terms: &[String],
    highlight_terms: &[String],
    context: usize,
) -> String {
    if raw.is_empty() {
        return String::new();
    }
    let (plain, map) = strip_diacritics_with_map(raw);
    let eff = if plain.len() != raw.len() {
        context.max(360)
    } else {
        context
    };
    let search = replace_finals_with_base(&plain).to_lowercase();
    let anchors: Vec<String> = anchor_terms
        .iter()
        .map(|s| replace_finals_with_base(s).to_lowercase())
        .filter(|s| !s.is_empty())
        .collect();
    let mut positions = Vec::<(usize, String)>::new();
    for term in &anchors {
        let mut start = 0;
        let mut n = 0;
        while n < 5 {
            let Some(rel) = search[start..].find(term) else {
                break;
            };
            let p = start + rel;
            positions.push((p, term.clone()));
            start = next_char_boundary(&search, p);
            n += 1;
            if start >= search.len() {
                break;
            }
        }
    }
    let mut best = (
        0usize,
        anchors.first().map(String::len).unwrap_or(0),
        0usize,
    );
    for (p, t) in &positions {
        let lo = p.saturating_sub(eff);
        let hi = (p + t.len() + eff).min(search.len());
        let mut seen = HashSet::new();
        for (q, u) in &positions {
            if *q >= lo && *q <= hi {
                seen.insert(u);
            }
        }
        let score = seen.len() * 100 + t.len();
        if score > best.2 {
            best = (*p, t.len(), score)
        }
    }
    let ps = floor_char_boundary(&plain, best.0.saturating_sub(eff));
    let pe = ceil_char_boundary(&plain, (best.0 + best.1 + eff).min(plain.len()));
    let os = original_offset(&plain, &map, ps, raw.len());
    let oe = original_offset(&plain, &map, pe, raw.len());
    let base = &raw[os..oe];
    let highlighted = highlight_whole_words(base, highlight_terms);
    format!(
        "{}{}{}",
        if os > 0 { "..." } else { "" },
        highlighted,
        if oe < raw.len() { "..." } else { "" }
    )
}

fn highlight_whole_words(text: &str, terms: &[String]) -> String {
    let (plain, map) = strip_diacritics_with_map(text);
    let lower = replace_finals_with_base(&plain).to_lowercase();
    let mut ranges = Vec::<(usize, usize)>::new();
    for term in terms {
        let t = replace_finals_with_base(
            &term
                .chars()
                .filter(|c| !crate::hebrew_text_utils::is_nikud_or_teamim(*c))
                .collect::<String>(),
        )
        .to_lowercase();
        if t.chars().count() < 2 {
            continue;
        }
        let mut start = 0;
        while start < lower.len() {
            let Some(rel) = lower[start..].find(&t) else {
                break;
            };
            let a = start + rel;
            let b = a + t.len();
            let before = lower[..a].chars().next_back();
            let after = lower[b..].chars().next();
            let boundary = |c: Option<char>| c.map(|x| !x.is_alphanumeric()).unwrap_or(true);
            if boundary(before) && boundary(after) {
                ranges.push((
                    original_offset(&plain, &map, a, text.len()),
                    original_offset(&plain, &map, b, text.len()),
                ));
            }
            start = next_char_boundary(&lower, a);
        }
    }
    ranges.sort_unstable();
    let mut merged = Vec::<(usize, usize)>::new();
    for r in ranges {
        if let Some(last) = merged.last_mut() {
            if r.0 <= last.1 {
                last.1 = last.1.max(r.1);
                continue;
            }
        }
        merged.push(r)
    }
    let mut out = text.to_owned();
    for (a, b) in merged.into_iter().rev() {
        if a <= b && b <= out.len() {
            out.insert_str(b, "</b>");
            out.insert_str(a, "<b>");
        }
    }
    out
}

fn next_char_boundary(text: &str, byte_index: usize) -> usize {
    byte_index
        + text[byte_index..]
            .chars()
            .next()
            .map(char::len_utf8)
            .unwrap_or(0)
}

fn floor_char_boundary(text: &str, mut byte_index: usize) -> usize {
    while byte_index > 0 && !text.is_char_boundary(byte_index) {
        byte_index -= 1;
    }
    byte_index
}

fn ceil_char_boundary(text: &str, mut byte_index: usize) -> usize {
    while byte_index < text.len() && !text.is_char_boundary(byte_index) {
        byte_index += 1;
    }
    byte_index
}

fn original_offset(
    plain: &str,
    map: &[usize],
    plain_byte_index: usize,
    original_len: usize,
) -> usize {
    let char_index = plain[..plain_byte_index].chars().count();
    map.get(char_index).copied().unwrap_or(original_len)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn highlights_pointed_hebrew_without_splitting_utf8() {
        let term = "שלום".to_owned();
        let snippet = build_snippet(
            "<p>שָׁלוֹם בַּיִת מיוחד</p>",
            std::slice::from_ref(&term),
            std::slice::from_ref(&term),
            20,
        );
        assert!(snippet.contains("<b>שָׁלוֹם</b>"), "{snippet}");
    }
}
