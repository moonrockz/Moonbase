///|
/// What a typed reference points to.
pub(all) enum RefTarget {
  ToDocument(DocKey)
  ToRecord(register~ : String, record~ : DocKey)
  ToFile(StorePath)
  ToUri(String)
  /// A free-text scope, such as `all queries in project X`.
  FreeText(String)
  /// The value does not have the form that the field requires.
  Malformed(String)
  /// The value has the right form, but names nothing that exists.
  Unresolved(String)
} derive(Eq, Debug)

///|
/// One typed reference of a document.
pub(all) struct TypedReference {
  key : String
  value : String
  line : Int32?
  target : RefTarget
} derive(Eq, Debug)

///|
pub fn TypedReference::is_resolved(self : TypedReference) -> Bool {
  match self.target {
    ToDocument(_) | ToRecord(..) | ToFile(_) | ToUri(_) | FreeText(_) => true
    Malformed(_) | Unresolved(_) => false
  }
}

///|
/// A `bundle-label:/path.md` reference.
pub(all) struct DocRef {
  bundle : String?
  path : String
} derive(Eq, Debug)

///|
/// Parses `bundle-label:/path.md` or `/path.md`.
pub fn DocRef::parse(text : String) -> DocRef? {
  let text = text.trim(chars=" \t").to_owned()
  if text.has_prefix("/") {
    return Some({ bundle: None, path: text, })
  }
  match text.find(":/") {
    Some(i) if i > 0 && !text[:i].contains(" ") && !text.has_prefix("http") =>
      Some({ bundle: Some(text[:i].to_owned()), path: text[i + 1:].to_owned(), })
    _ => None
  }
}

///|
fn path_target(
  knowledge : Knowledge,
  bundle : Bundle,
  doc : Document,
  value : String,
  resolver : &LinkResolver?,
) -> RefTarget {
  if value.contains(" ") && !value.has_prefix("/") && !has_scheme(value) {
    return FreeText(value)
  }
  match resolve_field_path(bundle, doc, value) {
    ExternalUri(uri) => ToUri(uri)
    SameDocument(_) => ToDocument(DocKey::of(bundle, doc))
    Unresolvable(v) => Unresolved(v)
    StoreTarget(path~, ..) =>
      match knowledge.document_at(path) {
        Some((b, d)) => ToDocument(DocKey::of(b, d))
        None => {
          let known = match resolver {
            Some(r) => r.exists(path)
            None => false
          }
          if known {
            ToFile(path)
          } else {
            Unresolved(value)
          }
        }
      }
  }
}

///|
/// The typed references of a document: each `sources[].resource`, and each
/// value of the reference fields of `profiles`.
pub fn typed_references(
  knowledge : Knowledge,
  bundle : Bundle,
  doc : Document,
  profiles~ : ArrayView[&Profile] = [],
  resolver? : &LinkResolver,
) -> Array[TypedReference] {
  let meta = doc.metadata()
  let out = []
  for source in meta.sources() {
    out.push({
      key: "sources",
      value: source.resource,
      line: meta.line_of("sources"),
      target: path_target(knowledge, bundle, doc, source.resource, resolver),
    })
  }
  for profile in profiles {
    for field in profile.reference_fields() {
      for value in meta.texts(field.key) {
        let target = match field.kind {
          PathRef => path_target(knowledge, bundle, doc, value, resolver)
          DocumentRef =>
            match DocRef::parse(value) {
              None => Malformed(value)
              Some(r) => {
                let target_bundle = match r.bundle {
                  None => Some(bundle)
                  Some(label) => knowledge.bundle(label).to_option()
                }
                match target_bundle {
                  None => Unresolved(value)
                  Some(b) =>
                    try BundlePath(r.path) catch {
                      _ => Malformed(value)
                    } noraise {
                      path =>
                        match b.document(path) {
                          Some(d) => ToDocument(DocKey::of(b, d))
                          None => Unresolved(value)
                        }
                    }
                }
              }
            }
          RecordRef(register~) => {
            let found = profiles
              .iter()
              .flat_map(p => p.registers().iter())
              .find_first(r => r.name == register)
            match found {
              None => Unresolved(value)
              Some(reg) =>
                match reg.find(reg.records(bundle), value) {
                  Found(record) => ToRecord(register~, record=record.key())
                  _ => Unresolved(value)
                }
            }
          }
        }
        out.push({
          key: field.key,
          value,
          line: meta.line_of(field.key),
          target,
        })
      }
    }
  }
  out
}

///|
/// The parts of a commit-pinned GitHub URL.
pub(all) struct GitHubSource {
  org : String
  repo : String
  commit : String
  path : String
} derive(Eq, Debug)

///|
fn is_hex(text : String) -> Bool {
  text.length() > 0 &&
  text
  .iter()
  .all(c => {
    (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
  })
}

///|
/// Splits `https://github.com/<org>/<repo>/blob/<commit>/<path>` (or `tree`).
/// The commit must be 7 to 40 hexadecimal characters.
pub fn GitHubSource::parse(url : String) -> GitHubSource? {
  let prefix = "https://github.com/"
  guard url.has_prefix(prefix) else { return None }
  let rest = url[prefix.length():].to_owned()
  let rest = match rest.find("#") {
    Some(i) => rest[:i].to_owned()
    None => rest
  }
  let parts = rest.split("/").map(s => s.to_owned()).collect()
  guard parts.length() >= 5 && (parts[2] == "blob" || parts[2] == "tree") else {
    return None
  }
  let commit = parts[3]
  guard commit.length() >= 7 && commit.length() <= 40 && is_hex(commit) else {
    return None
  }
  Some({
    org: parts[0],
    repo: parts[1],
    commit,
    path: parts[4:].to_owned().join("/"),
  })
}

///|
pub extend RefTarget with Eq::{not_equal, equal}

///|
pub extend RefTarget with @debug.Debug::{to_repr}

///|
pub extend TypedReference with Eq::{not_equal, equal}

///|
pub extend TypedReference with @debug.Debug::{to_repr}

///|
pub extend DocRef with Eq::{not_equal, equal}

///|
pub extend DocRef with @debug.Debug::{to_repr}

///|
pub extend GitHubSource with Eq::{not_equal, equal}

///|
pub extend GitHubSource with @debug.Debug::{to_repr}
