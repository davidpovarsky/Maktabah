use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParsedQuery {
    pub exact_phrases: Vec<String>,
    pub free_text: String,
}

fn is_quote(c: char) -> bool {
    c == '"' || c == '״'
}
fn is_hebrew_letter(c: char) -> bool {
    ('א'..='ת').contains(&c)
}

pub fn parse(raw: &str) -> ParsedQuery {
    if !raw.chars().any(is_quote) {
        return ParsedQuery {
            exact_phrases: vec![],
            free_text: collapse_ws(raw),
        };
    }
    let chars: Vec<char> = raw.chars().collect();
    let mut exact = Vec::new();
    let mut free = String::new();
    let mut phrase = String::new();
    let mut in_quote = false;
    for (i, c) in chars.iter().copied().enumerate() {
        let acronym = i > 0
            && i + 1 < chars.len()
            && is_hebrew_letter(chars[i - 1])
            && is_hebrew_letter(chars[i + 1]);
        if is_quote(c) && !acronym {
            if in_quote {
                let p = collapse_ws(&phrase);
                if !p.is_empty() {
                    exact.push(p);
                }
                phrase.clear();
                in_quote = false;
            } else {
                in_quote = true;
            }
        } else if in_quote {
            phrase.push(c);
        } else {
            free.push(c);
        }
    }
    if in_quote {
        let p = collapse_ws(&phrase);
        if !p.is_empty() {
            exact.push(p);
        }
    }
    ParsedQuery {
        exact_phrases: exact,
        free_text: collapse_ws(&free),
    }
}

fn collapse_ws(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn keeps_acronyms() {
        assert_eq!(
            parse("רש״י"),
            ParsedQuery {
                exact_phrases: vec![],
                free_text: "רש״י".into()
            }
        );
    }
    #[test]
    fn parses_exact() {
        assert_eq!(
            parse("אחד \"שלום בית\" שני").exact_phrases,
            vec!["שלום בית"]
        );
    }
}
