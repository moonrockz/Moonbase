///|
fn is_space(unit : UInt16) -> Bool {
  unit == 32 || (unit >= 9 && unit <= 13)
}

///|
fn normalize(source : String) -> String {
  let out = StringBuilder()
  let mut start = 0
  let mut pending_space = false
  for i = 0; i <= source.length(); i = i + 1 {
    if i == source.length() || is_space(source.code_unit_at(i)) {
      if i > start {
        if pending_space {
          out.write_string(" ")
        }
        out.write_string(source[start:i].to_owned())
        pending_space = true
      }
      start = i + 1
    }
  }
  out.to_string()
}

///|
fn starts_word(text : String, word : String) -> Bool {
  starts_word_at(text, 0, word)
}

///|
fn starts_word_at(text : String, at : Int32, word : String) -> Bool {
  let end = at + word.length()
  text.length() >= end &&
  text[at:end].to_owned().to_lower() == word &&
  (text.length() == end || text.code_unit_at(end) == 32)
}

///|
fn clause_keyword(text : String) -> String? {
  for word in ["where", "while", "when", "if", "then", "the"] {
    if starts_word(text, word) {
      return Some(word)
    }
  }
  None
}

///|
// A comma is structural only when a reserved clause keyword follows it.
// Ordinary commas in natural-language clauses remain part of that clause.
fn take_clause(
  text : String,
  unwanted : Bool,
) -> (String, String) raise ParseError {
  for i in 0..<text.length() {
    if text.code_unit_at(i) == 44 {
      let rest = text[i + 1:].trim_start().to_owned()
      if clause_keyword(rest) is Some(_) {
        return (text[:i].trim_end().to_owned(), rest)
      }
    }
    if unwanted && text.code_unit_at(i) == 32 {
      if starts_word_at(text, i + 1, "then") {
        return (text[:i].trim_end().to_owned(), text[i + 1:].to_owned())
      }
    }
  }
  if unwanted {
    raise MissingThen
  }
  raise MissingSeparator
}

///|
/// Parse one sentence. Keywords are case-insensitive; clauses use comma
/// separators. IF requires THEN, with an optional comma before THEN.
/// Order: optional WHERE, zero or more WHILE, optional WHEN or IF, THE ... SHALL.
pub fn Requirement::Requirement(
  source : String,
) -> Requirement raise ParseError {
  let text = normalize(source)
  guard !text.is_empty() else { raise EmptyRequirement }
  let mut rest = text
  let mut feature = None
  let states = []
  let mut trigger = None
  while !starts_word(rest, "the") {
    guard clause_keyword(rest) is Some(keyword) else { raise ExpectedSystem }
    match keyword {
      "where" => {
        guard feature is None && states.is_empty() && trigger is None else {
          raise InvalidClauseOrder
        }
      }
      "while" | "when" | "if" => {
        guard trigger is None else { raise InvalidClauseOrder }
      }
      _ => raise InvalidClauseOrder
    }
    let payload = rest[keyword.length():].trim_start().to_owned()
    let (clause, next) = take_clause(payload, keyword == "if")
    guard !clause.is_empty() else { raise EmptyClause(keyword~) }
    match keyword {
      "where" => feature = Some(clause)
      "while" => states.push(clause)
      "when" => trigger = Some(Event(clause))
      "if" => trigger = Some(Unwanted(clause))
      _ => ()
    }
    rest = if keyword == "if" {
      guard starts_word(next, "then") else { raise MissingThen }
      let after_then = next[4:].trim_start().to_owned()
      guard starts_word(after_then, "the") else { raise ExpectedSystem }
      after_then
    } else {
      next
    }
  }
  let body = rest[3:].trim_start().to_owned()
  let mut shall_at = None
  for i = 0; i < body.length(); i = i + 1 {
    if (i == 0 || body.code_unit_at(i - 1) == 32) &&
      starts_word_at(body, i, "shall") {
      shall_at = Some(i)
      break
    }
  }
  guard shall_at is Some(at) else { raise MissingShall }
  let system = body[:at].trim_end().to_owned()
  guard !system.is_empty() else { raise ExpectedSystem }
  let response = body[at + 5:].trim_start().to_owned()
  guard !response.is_empty() && response != "." else { raise MissingResponse }
  {
    feature,
    preconditions: ReadOnlyArray::from_array(states[:]),
    trigger,
    system,
    response,
  }
}

///|
pub fn parse(source : String) -> Requirement raise ParseError {
  Requirement::Requirement(source)
}
