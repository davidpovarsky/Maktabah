use crate::{
    hebrew_text_utils::normalize_hebrew,
    magic_dictionary_index::{Expansion, MagicDictionaryIndex},
    search_query_parser,
};
use anyhow::Result;
use std::collections::HashMap;

pub const MAX_SYNONYM_TERMS_PER_TOKEN: usize = 32;
pub const MAX_SYNONYM_BOOST_TERMS: usize = 256;

#[derive(Debug, Clone)]
pub struct QueryPlan {
    pub normalized_free_text: String,
    pub exact_phrases: Vec<String>,
    pub tokens: Vec<String>,
    pub alternatives: HashMap<String, Vec<String>>,
    pub near: u32,
}

pub fn build_query_plan(raw: &str, near: u32, dict: &MagicDictionaryIndex) -> Result<QueryPlan> {
    let parsed = search_query_parser::parse(raw);
    let norm = normalize_hebrew(&parsed.free_text);
    let has_hashem = raw.contains("ה׳") || raw.contains("ה'");
    let tokens = norm
        .split_whitespace()
        .filter(|t| {
            if *t == "ה" && has_hashem {
                return true;
            }
            t.chars().any(|c| c.is_ascii_digit()) || t.chars().count() >= 2
        })
        .map(str::to_owned)
        .collect::<Vec<_>>();
    let mut alternatives = HashMap::new();
    for token in &tokens {
        let exp = dict.expansion_for(token)?;
        alternatives.insert(token.clone(), limited_terms(token, exp.as_ref()));
    }
    Ok(QueryPlan {
        normalized_free_text: norm,
        exact_phrases: parsed
            .exact_phrases
            .into_iter()
            .map(|p| normalize_hebrew(&p))
            .filter(|p| !p.is_empty())
            .collect(),
        tokens,
        alternatives,
        near,
    })
}

fn limited_terms(token: &str, exp: Option<&Expansion>) -> Vec<String> {
    let mut out = Vec::new();
    push(&mut out, token.to_owned());
    if let Some(e) = exp {
        for s in &e.base {
            push(&mut out, s.clone())
        }
        for s in e.surface.iter().chain(e.variants.iter()) {
            push(&mut out, s.clone())
        }
    }
    out.truncate(MAX_SYNONYM_TERMS_PER_TOKEN);
    out
}
fn push(v: &mut Vec<String>, s: String) {
    if !s.is_empty() && !v.contains(&s) {
        v.push(s)
    }
}

pub fn ngrams4(token: &str) -> Vec<String> {
    let c: Vec<char> = token.chars().collect();
    if c.len() < 4 {
        return vec![];
    }
    (0..=c.len() - 4)
        .map(|i| c[i..i + 4].iter().collect())
        .collect()
}
