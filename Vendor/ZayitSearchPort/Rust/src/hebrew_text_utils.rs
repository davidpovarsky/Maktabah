/// Port of Zayit's HebrewTextUtils behaviour.
pub fn replace_finals_with_base(text: &str) -> String {
    text.chars()
        .map(|c| match c {
            'ך' => 'כ',
            'ם' => 'מ',
            'ן' => 'נ',
            'ף' => 'פ',
            'ץ' => 'צ',
            _ => c,
        })
        .collect()
}

pub fn is_nikud_or_teamim(c: char) -> bool {
    let n = c as u32;
    (0x0591..=0x05AF).contains(&n)
        || (0x05B0..=0x05BD).contains(&n)
        || matches!(n, 0x05C1 | 0x05C2 | 0x05C7)
}

pub fn strip_diacritics(text: &str) -> String {
    text.chars().filter(|c| !is_nikud_or_teamim(*c)).collect()
}

/// Returns plain text and a map from plain character index to original byte index.
pub fn strip_diacritics_with_map(text: &str) -> (String, Vec<usize>) {
    let mut plain = String::with_capacity(text.len());
    let mut map = Vec::new();
    for (byte_idx, c) in text.char_indices() {
        if !is_nikud_or_teamim(c) {
            plain.push(c);
            map.push(byte_idx);
        }
    }
    (plain, map)
}

pub fn normalize_hebrew(input: &str) -> String {
    if input.trim().is_empty() {
        return String::new();
    }
    let mut out = String::with_capacity(input.len());
    let mut previous_was_space = false;
    for c in input.trim().chars() {
        if is_nikud_or_teamim(c) {
            continue;
        }
        let c = match c {
            '\u{05BE}' => ' ',
            '\u{05F3}' | '\u{05F4}' => continue,
            'ך' => 'כ',
            'ם' => 'מ',
            'ן' => 'נ',
            'ף' => 'פ',
            'ץ' => 'צ',
            other => other,
        };
        if c.is_whitespace() {
            if !previous_was_space && !out.is_empty() {
                out.push(' ');
            }
            previous_was_space = true;
        } else {
            out.push(c);
            previous_was_space = false;
        }
    }
    out.trim().to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn normalizes_hebrew() {
        assert_eq!(normalize_hebrew("  מֶלֶךְ־יִשְׂרָאֵל  "), "מלכ ישראל");
        assert_eq!(normalize_hebrew("רש״י"), "רשי");
    }
}
