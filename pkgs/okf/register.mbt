///|
/// How a register finds the ID of a record.
pub(all) enum IdRule {
  /// The leading digits of the file name, padded with zeros to `width`.
  LeadingDigits(width~ : Int32)
  /// The value of a frontmatter key.
  FieldValue(String)
} derive(Eq, Debug)

///|
/// One record of a register: a typed view of one concept.
pub(all) struct Record {
  register : String
  bundle : String
  id : String?
  state : String?
  document : Document
}

///|
pub fn Record::key(self : Record) -> DocKey {
  { bundle: self.bundle, path: self.document.path(), }
}

///|
/// A field of the record's frontmatter.
pub fn Record::metadata(self : Record) -> Metadata {
  self.document.metadata()
}

///|
/// A condition that a transition requires, such as a `reason` value.
pub(all) struct Obligation {
  name : String
  met : (Record) -> Bool
}

///|
/// An obligation that holds when the record has a non-empty value for `key`.
pub fn Obligation::requires_key(key : String) -> Obligation {
  { name: key, met: r => r.metadata().text(key) is Some(_), }
}

///|
/// An allowed change of state. An empty `from` allows any current state.
pub(all) struct Transition {
  from : ReadOnlyArray[String]
  to : String
  obligations : ReadOnlyArray[Obligation]
}

///|
pub fn Transition::Transition(
  to : String,
  from~ : ArrayView[String] = [],
  obligations~ : ArrayView[Obligation] = [],
) -> Transition {
  {
    from: ReadOnlyArray::from_array(from.to_owned()),
    to,
    obligations: ReadOnlyArray::from_array(obligations.to_owned()),
  }
}

///|
/// A typed view of the concepts of one type, defined by a profile.
pub(all) struct Register {
  name : String
  concept_type : String
  id_rule : IdRule
  state_key : String?
  states : ReadOnlyArray[String]
  transitions : ReadOnlyArray[Transition]
  supersedes_key : String?
  superseded_by_key : String?
  superseded_states : ReadOnlyArray[String]
  bundle_flag : String?
  fields : ReadOnlyArray[KeyDefinition]
}

///|
pub fn Register::Register(
  name : String,
  concept_type : String,
  id_rule~ : IdRule = LeadingDigits(width=4),
  state_key? : String,
  states~ : ArrayView[String] = [],
  transitions~ : ArrayView[Transition] = [],
  supersedes_key? : String,
  superseded_by_key? : String,
  superseded_states~ : ArrayView[String] = [],
  bundle_flag? : String,
  fields~ : ArrayView[KeyDefinition] = [],
) -> Register {
  {
    name,
    concept_type,
    id_rule,
    state_key,
    states: ReadOnlyArray::from_array(states.to_owned()),
    transitions: ReadOnlyArray::from_array(transitions.to_owned()),
    supersedes_key,
    superseded_by_key,
    superseded_states: ReadOnlyArray::from_array(superseded_states.to_owned()),
    bundle_flag,
    fields: ReadOnlyArray::from_array(fields.to_owned()),
  }
}

///|
/// Normalizes an ID: digits only, padded with zeros to `width`.
pub fn normalize_id(text : String, width : Int32) -> String? {
  let text = text.trim(chars=" \t").to_owned()
  if text.length() == 0 {
    return None
  }
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
  }
  let trimmed = {
    let mut i = 0
    while i < text.length() - 1 && text[i] == '0' {
      i += 1
    }
    text[i:].to_owned()
  }
  Some(
    if trimmed.length() < width {
      "0".repeat(width - trimmed.length()) + trimmed
    } else {
      trimmed
    },
  )
}

///|
fn leading_digits(name : String) -> String? {
  let mut i = 0
  while i < name.length() && name[i] >= '0' && name[i] <= '9' {
    i += 1
  }
  if i == 0 {
    None
  } else {
    Some(name[:i].to_owned())
  }
}

///|
/// True when the register applies to `bundle`: no bundle flag, or the root
/// index sets the flag to true.
pub fn Register::applies_to(self : Register, bundle : Bundle) -> Bool {
  match self.bundle_flag {
    None => true
    Some(flag) => bundle.config().bool(flag) == Some(true)
  }
}

///|
/// The ID of a document under this register.
pub fn Register::record_id(self : Register, doc : Document) -> String? {
  match self.id_rule {
    LeadingDigits(width~) =>
      match leading_digits(doc.path().name()) {
        Some(digits) => normalize_id(digits, width)
        None => None
      }
    FieldValue(key) => doc.metadata().text(key)
  }
}

///|
/// Normalizes an ID that a user or a field gives.
pub fn Register::normalize(self : Register, text : String) -> String {
  match self.id_rule {
    LeadingDigits(width~) => normalize_id(text, width).unwrap_or(text)
    FieldValue(_) => text
  }
}

///|
/// The records of `bundle`: its concepts whose `type` equals the register
/// type, ignoring letter case.
pub fn Register::records(self : Register, bundle : Bundle) -> Array[Record] {
  guard self.applies_to(bundle) else { return [] }
  let wanted = self.concept_type.to_lower()
  bundle
  .concepts()
  .iter()
  .filter(doc => {
    match doc.concept_type() {
      Some(t) => t.to_lower() == wanted
      None => false
    }
  })
  .map(doc => {
    register: self.name,
    bundle: bundle.label(),
    id: self.record_id(doc),
    state: match self.state_key {
      Some(key) => doc.metadata().text(key)
      None => None
    },
    document: doc,
  })
  .collect()
}

///|
/// The records of every bundle where the register applies.
pub fn Register::all_records(
  self : Register,
  knowledge : Knowledge,
) -> Array[Record] {
  let out = []
  for bundle in knowledge.bundles() {
    for record in self.records(bundle) {
      out.push(record)
    }
  }
  out
}

///|
/// Finds records by ID or by file name slug.
pub fn Register::find(
  self : Register,
  records : ArrayView[Record],
  query : String,
) -> Lookup[Record] {
  let id = self.normalize(query)
  let by_id = records.iter().filter(r => r.id == Some(id)).collect()
  if !by_id.is_empty() {
    return lookup_of(by_id)
  }
  let q = query.to_lower()
  lookup_of(
    records
    .iter()
    .filter(r => r.document.path().name().to_lower().contains(q))
    .collect(),
  )
}

///|
/// The IDs that more than one record has, with those records.
pub fn Register::duplicates(
  _self : Register,
  records : ArrayView[Record],
) -> Array[(String, Array[Record])] {
  let groups : Map[String, Array[Record]] = Map([])
  for record in records {
    match record.id {
      Some(id) =>
        match groups.get(id) {
          Some(list) => list.push(record)
          None => groups[id] = [record]
        }
      None => ()
    }
  }
  let out = []
  for id, list in groups {
    if list.length() > 1 {
      out.push((id, list))
    }
  }
  out.sort_by((a, b) => lexical_compare(a.0, b.0))
  out
}

///|
/// The result of a transition request.
pub(all) enum TransitionCheck {
  Allowed
  /// The target state is not a state of the register.
  UnknownState(String)
  /// No transition leads from the current state to the target state.
  NotAllowed(from~ : String?, to~ : String)
  /// The transition exists, but these obligations are not met.
  Refused(Array[String])
} derive(Eq, Debug)

///|
/// Checks whether `record` can move to state `to`.
pub fn Register::check_transition(
  self : Register,
  record : Record,
  to : String,
) -> TransitionCheck {
  if !self.states.is_empty() && !self.states.contains(to) {
    return UnknownState(to)
  }
  let candidates = self.transitions
    .iter()
    .filter(t => {
      t.to == to &&
      (
        t.from.is_empty() ||
        (match record.state {
          Some(s) => t.from.contains(s)
          None => false
        })
      )
    })
    .collect()
  match candidates {
    [] => NotAllowed(from=record.state, to~)
    _ => {
      let mut best : Array[String]? = None
      for t in candidates {
        let unmet = t.obligations
          .iter()
          .filter(o => !(o.met)(record))
          .map(o => o.name)
          .collect()
        if unmet.is_empty() {
          return Allowed
        }
        match best {
          Some(b) if b.length() <= unmet.length() => ()
          _ => best = Some(unmet)
        }
      }
      Refused(best.unwrap_or([]))
    }
  }
}

///|
/// A supersession problem.
pub(all) enum SupersessionIssue {
  /// A record in a superseded state names no successor.
  MissingSuccessor(Record)
  /// `superseded_by` names an ID that no record has.
  UnknownSuccessor(Record, String)
  /// `supersedes` names an ID that no record has.
  UnknownPredecessor(Record, String)
  /// Only one of the two records names the other.
  NotMutual(Record, Record)
}

///|
fn Register::ids_at(
  self : Register,
  record : Record,
  key : String?,
) -> Array[String] {
  match key {
    Some(k) => record.metadata().texts(k).map(t => self.normalize(t))
    None => []
  }
}

///|
/// Checks the supersession fields of `records`, which come from one bundle.
pub fn Register::supersession_issues(
  self : Register,
  records : ArrayView[Record],
) -> Array[SupersessionIssue] {
  let by_id : Map[String, Record] = Map([])
  for r in records {
    match r.id {
      Some(id) => if !by_id.contains(id) { by_id[id] = r }
      None => ()
    }
  }
  let out = []
  for r in records {
    let successors = self.ids_at(r, self.superseded_by_key)
    match r.state {
      Some(state) if self.superseded_states.contains(state) &&
        successors.is_empty() => out.push(MissingSuccessor(r))
      _ => ()
    }
    for s in successors {
      match by_id.get(s) {
        None => out.push(UnknownSuccessor(r, s))
        Some(next) =>
          if self.supersedes_key is Some(_) &&
            !self.ids_at(next, self.supersedes_key).contains(r.id.unwrap_or("")) {
            out.push(NotMutual(r, next))
          }
      }
    }
    for p in self.ids_at(r, self.supersedes_key) {
      match by_id.get(p) {
        None => out.push(UnknownPredecessor(r, p))
        Some(prev) =>
          if self.superseded_by_key is Some(_) &&
            !self
            .ids_at(prev, self.superseded_by_key)
            .contains(r.id.unwrap_or("")) {
            out.push(NotMutual(prev, r))
          }
      }
    }
  }
  out
}

///|
/// The chain of successors of `record`, following `superseded_by`. A cycle ends the chain.
pub fn Register::successors(
  self : Register,
  records : ArrayView[Record],
  record : Record,
) -> Array[Record] {
  let out = []
  let seen = [record.id.unwrap_or("")]
  let mut current = record
  while true {
    match self.ids_at(current, self.superseded_by_key) {
      [next_id, ..] => {
        if seen.contains(next_id) {
          break
        }
        match records.iter().find_first(r => r.id == Some(next_id)) {
          Some(next) => {
            out.push(next)
            seen.push(next_id)
            current = next
          }
          None => break
        }
      }
      [] => break
    }
  }
  out
}

///|
/// What a reference field names.
pub(all) enum ReferenceKind {
  /// A document: `bundle-label:/path.md`, or `/path.md` in the same bundle.
  DocumentRef
  /// Records of a register in the same bundle, by ID.
  RecordRef(register~ : String)
  /// A path or URL, resolved like a link.
  PathRef
} derive(Eq, Debug)

///|
/// A frontmatter field whose values name documents or records.
pub(all) struct ReferenceField {
  key : String
  kind : ReferenceKind
} derive(Eq, Debug)

///|
/// A template for new concepts of one type. The body can use `{{title}}`,
/// `{{description}}` and `{{type}}`.
pub(all) struct Template {
  concept_type : String
  body : String
} derive(Eq, Debug)

///|
pub extend IdRule with Eq::{not_equal, equal}

///|
pub extend IdRule with @debug.Debug::{to_repr}

///|
pub extend TransitionCheck with Eq::{not_equal, equal}

///|
pub extend TransitionCheck with @debug.Debug::{to_repr}

///|
pub extend ReferenceKind with Eq::{not_equal, equal}

///|
pub extend ReferenceKind with @debug.Debug::{to_repr}

///|
pub extend ReferenceField with Eq::{not_equal, equal}

///|
pub extend ReferenceField with @debug.Debug::{to_repr}

///|
pub extend Template with Eq::{not_equal, equal}

///|
pub extend Template with @debug.Debug::{to_repr}
