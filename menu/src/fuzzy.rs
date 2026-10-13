//! Filtro fuzzy: subsequência com fold de acentos/caixa (pt-BR).
//!
//! O tofi filtra sem normalizar acento e com require-match (UX-WRITING §8);
//! aqui o fold deixa "aparencia" casar "Aparência" — rótulo exibido intacto.
//! Zero deps, sem alocação no hot path além do fold do texto (cacheado).

/// Char foldado (base ASCII minúsculo) + posição no texto original.
pub struct Folded {
    /// chars base (1:1 com orig — sem expansões; ver `fold_char`).
    pub base: Vec<char>,
    /// chars originais na ordem original (para spans de highlight).
    pub orig: Vec<char>,
}

/// Mapeia um char para a base ASCII minúscula (pt-BR + alfabetos comuns).
fn fold_char(c: char) -> char {
    match c {
        'Á' | 'À' | 'Â' | 'Ä' | 'Ã' | 'Å' | 'Ā' | 'Ă' | 'Ą' | 'á' | 'à' | 'â' | 'ä' | 'ã' | 'å'
        | 'ā' | 'ă' | 'ą' => 'a',
        'É' | 'È' | 'Ê' | 'Ë' | 'Ē' | 'Ĕ' | 'Ė' | 'Ę' | 'Ě' | 'é' | 'è' | 'ê' | 'ë' | 'ē' | 'ĕ'
        | 'ė' | 'ę' | 'ě' => 'e',
        'Í' | 'Ì' | 'Î' | 'Ï' | 'Ī' | 'Ĭ' | 'Į' | 'í' | 'ì' | 'î' | 'ï' | 'ī' | 'ĭ' | 'į' => 'i',
        'Ó' | 'Ò' | 'Ô' | 'Ö' | 'Õ' | 'Ō' | 'Ŏ' | 'Ő' | 'ó' | 'ò' | 'ô' | 'ö' | 'õ' | 'ō' | 'ŏ'
        | 'ő' => 'o',
        'Ú' | 'Ù' | 'Û' | 'Ü' | 'Ū' | 'Ŭ' | 'Ů' | 'Ű' | 'ú' | 'ù' | 'û' | 'ü' | 'ū' | 'ŭ' | 'ů'
        | 'ű' => 'u',
        'Ý' | 'Ÿ' | 'ý' | 'ÿ' => 'y',
        'Ç' | 'Ć' | 'Ĉ' | 'Ċ' | 'Č' | 'ç' | 'ć' | 'ĉ' | 'ċ' | 'č' => 'c',
        'Ñ' | 'Ń' | 'Ņ' | 'Ň' | 'ñ' | 'ń' | 'ņ' | 'ň' | 'ŉ' => 'n',
        'Ś' | 'Ŝ' | 'Ş' | 'Š' | 'ś' | 'ŝ' | 'ş' | 'š' => 's',
        'Ź' | 'Ż' | 'Ž' | 'ź' | 'ż' | 'ž' => 'z',
        'Ľ' | 'Ĺ' | 'Ļ' | 'Ł' | 'ľ' | 'ĺ' | 'ļ' | 'ł' => 'l',
        'Ř' | 'Ŕ' | 'Ŗ' | 'ř' | 'ŕ' | 'ŗ' => 'r',
        'Ť' | 'Ţ' | 'ť' | 'ţ' => 't',
        'Ď' | 'ď' | 'đ' => 'd',
        'Ğ' | 'Ģ' | 'ğ' | 'ģ' => 'g',
        'Ĥ' | 'Ħ' | 'ĥ' | 'ħ' => 'h',
        'Ĵ' | 'ĵ' => 'j',
        'Ķ' | 'ķ' => 'k',
        'Œ' | 'œ' => 'o',
        'Þ' | 'þ' => 't',
        'Ð' | 'ð' => 'd',
        _ => c.to_ascii_lowercase(),
    }
}

/// Só chars ASCII são chave de busca; fold de `query` e `título` iguais.
pub fn fold_chars(s: &str) -> Folded {
    let orig: Vec<char> = s.chars().collect();
    let base = orig.iter().map(|&c| fold_char(c)).collect();
    Folded { base, orig }
}

/// Score de subsequência de `query` em `text` (ambos foldados pelo caller
/// em forma de chars). `None` = não casa. Bônus: início (+30), início de
/// palavra (+12), contiguidade (+3); pena -1 por gap.
pub fn score(q: &[char], t: &[char]) -> Option<i32> {
    if q.is_empty() {
        return Some(0);
    }
    if q.len() > t.len() {
        return None;
    }
    let mut score = 0i32;
    let mut qi = 0usize;
    let mut run = 0u32;
    for (i, &c) in t.iter().enumerate() {
        if qi < q.len() && c == q[qi] {
            if i == 0 {
                score += 30;
            } else if t[i - 1] == ' ' || t[i - 1] == '-' || t[i - 1] == '/' {
                score += 12;
            }
            if run > 0 {
                score += 3;
            }
            run += 1;
            qi += 1;
        } else {
            run = 0;
            score -= 1;
        }
    }
    (qi == q.len()).then_some(score)
}

/// Testa match e devolve as posições (no texto original) que casaram.
/// Para highlight: `marks[i] == true` no índice de `orig`.
pub fn matched_positions(q: &[char], folded: &Folded) -> Option<Vec<bool>> {
    if q.len() > folded.base.len() {
        return None;
    }
    let mut marks = vec![false; folded.orig.len()];
    let mut qi = 0usize;
    for (i, &c) in folded.base.iter().enumerate() {
        if qi < q.len() && c == q[qi] {
            marks[i] = true;
            qi += 1;
        }
    }
    (qi == q.len()).then_some(marks)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn match_q(query: &str, text: &str) -> Option<i32> {
        let q = fold_chars(query);
        let t = fold_chars(text);
        score(&q.base, &t.base)
    }

    #[test]
    fn acento_e_caixa() {
        assert!(match_q("aparencia", "Aparência").is_some());
        assert!(match_q("ESCOLHER", "Escolher").is_some());
        assert!(match_q("cor", "Área de transferência").is_none());
    }

    #[test]
    fn subsequencia() {
        assert!(match_q("transf", "Área de transferência").is_some());
        assert!(match_q("blqtela", "Bloquear tela").is_some());
        assert!(match_q("xyzq", "Bloquear tela").is_none());
        assert!(match_q("zz", "A").is_none());
    }

    #[test]
    fn vazio_casa_tudo() {
        assert_eq!(match_q("", "Qualquer"), Some(0));
    }

    #[test]
    fn score_ordena_preferencias() {
        let q = fold_chars("tela");
        let t1 = fold_chars("Bloquear tela");
        let t2 = fold_chars("Tela");
        let s1 = score(&q.base, &t1.base).unwrap();
        let s2 = score(&q.base, &t2.base).unwrap();
        // "Tela" começa no início → melhor que "Bloquear tela".
        assert!(s2 > s1);
    }

    #[test]
    fn highlight_marca_casamentos() {
        let q = fold_chars("tem");
        let t = fold_chars("Temperatura da luz");
        let marks = matched_positions(&q.base, &t).unwrap();
        let hit: Vec<char> = t
            .orig
            .iter()
            .zip(&marks)
            .filter(|&(_, &m)| m)
            .map(|(&c, _)| c)
            .collect();
        assert_eq!(hit.iter().collect::<String>().to_lowercase(), "tem");
    }
}