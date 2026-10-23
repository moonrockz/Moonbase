///|
/// A ranked search request.
pub(all) struct SearchRequest {
  query : String
  filters : Array[Filter]
  limit : Int32
} derive(Eq, Debug)

///|
pub fn SearchRequest::SearchRequest(
  query : String,
  filters~ : ArrayView[Filter] = [],
  limit~ : Int32 = 20,
) -> SearchRequest {
  { query, filters: filters.to_owned(), limit, }
}

///|
/// One ranked search result.
pub(all) struct SearchHit {
  key : DocKey
  score : Double
  snippet : String
} derive(Eq, Debug)

///|
/// Splits text into lower-case terms of letters and digits.
pub fn tokenize(text : String) -> Array[String] {
  let out = []
  let current = StringBuilder()
  let flush = () => {
    let term = current.to_string()
    if term.length() > 0 {
      out.push(term)
    }
    current.reset()
  }
  for c in text.to_lower() {
    if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c.to_int() > 127 {
      current.write_char(c)
    } else {
      flush()
    }
  }
  flush()
  out
}

///|
priv struct Field {
  weight : Double
  terms : Map[String, Int32]
  length : Int32
}

///|
fn field_of(text : String, weight : Double) -> Field {
  let terms : Map[String, Int32] = Map([])
  let tokens = tokenize(text)
  for t in tokens {
    terms[t] = terms.get(t).unwrap_or(0) + 1
  }
  { weight, terms, length: tokens.length(), }
}

///|
/// The field weights of the in-memory search: title, description, tags, body.
let field_weights : Array[Double] = [8.0, 4.0, 4.0, 1.0]

///|
fn fields_of(doc : Document) -> Array[Field] {
  let meta = doc.metadata()
  [
    field_of(doc.display_title(), field_weights[0]),
    field_of(meta.description().unwrap_or(""), field_weights[1]),
    field_of(meta.tags().join(" "), field_weights[2]),
    field_of(doc.body(), field_weights[3]),
  ]
}

///|
/// Ranks the concepts of `knowledge` for `request` with BM25 over title,
/// description, tags and body. Every query term must occur in the concept.
/// Equal scores sort by bundle label and path, so results are deterministic.
pub fn search_knowledge(
  knowledge : Knowledge,
  request : SearchRequest,
) -> Array[SearchHit] {
  let terms = tokenize(request.query)
  if terms.is_empty() || request.limit <= 0 {
    return []
  }
  let candidates = knowledge.filter(request.filters)
  let docs = candidates.map(pair => (pair, fields_of(pair.1)))
  let n = docs.length().to_double()
  let k1 = 1.2
  let b = 0.75
  let avg = Array::makei(4, i => {
    let total = docs.fold(init=0, (acc, d) => acc + d.1[i].length)
    if docs.is_empty() {
      1.0
    } else {
      let mean = total.to_double() / n
      if mean < 1.0 {
        1.0
      } else {
        mean
      }
    }
  })
  let df : Map[String, Int32] = Map([])
  for d in docs {
    for t in terms {
      if d.1.any(f => f.terms.contains(t)) {
        df[t] = df.get(t).unwrap_or(0) + 1
      }
    }
  }
  let hits = []
  for d in docs {
    let ((bundle, doc), fields) = d
    guard terms.iter().all(t => fields.any(f => f.terms.contains(t))) else {
      continue
    }
    let mut score = 0.0
    for t in terms {
      let dft = df.get(t).unwrap_or(0).to_double()
      let idf = @math.ln(1.0 + (n - dft + 0.5) / (dft + 0.5))
      for i, f in fields {
        let tf = f.terms.get(t).unwrap_or(0).to_double()
        if tf > 0.0 {
          let norm = tf *
            (k1 + 1.0) /
            (tf + k1 * (1.0 - b + b * f.length.to_double() / avg[i]))
          score += f.weight * idf * norm
        }
      }
    }
    hits.push({
      key: DocKey::of(bundle, doc),
      score,
      snippet: snippet_of(doc, terms),
    })
  }
  hits.sort_by((x, y) => {
    if x.score != y.score {
      y.score.compare(x.score)
    } else {
      x.key.compare(y.key)
    }
  })
  if hits.length() > request.limit {
    hits[:request.limit].to_owned()
  } else {
    hits
  }
}

///|
/// The first body line that contains a query term, with each term in `[` `]`.
/// Without a body match, the description or the title.
fn snippet_of(doc : Document, terms : Array[String]) -> String {
  for line in split_lines(doc.body()) {
    let words = tokenize(line.text)
    if terms.any(t => words.contains(t)) {
      return mark_terms(line.text.trim(chars=" \t").to_owned(), terms)
    }
  }
  mark_terms(doc.metadata().description().unwrap_or(doc.display_title()), terms)
}

///|
fn mark_terms(text : String, terms : Array[String]) -> String {
  let out = StringBuilder()
  let word = StringBuilder()
  let flush = () => {
    let w = word.to_string()
    if w.length() > 0 {
      if terms.contains(w.to_lower()) {
        out.write_string("[\{w}]")
      } else {
        out.write_string(w)
      }
    }
    word.reset()
  }
  for c in text {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c.to_int() > 127 {
      word.write_char(c)
    } else {
      flush()
      out.write_char(c)
    }
  }
  flush()
  out.to_string()
}

///|
pub extend SearchRequest with Eq::{not_equal, equal}

///|
pub extend SearchRequest with @debug.Debug::{to_repr}

///|
pub extend SearchHit with Eq::{not_equal, equal}

///|
pub extend SearchHit with @debug.Debug::{to_repr}
