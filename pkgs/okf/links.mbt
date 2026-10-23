///|
/// The kind of a link destination.
pub(all) enum LinkKind {
  /// A URI with a scheme, such as `https:` or `mailto:`.
  External
  /// A fragment in the same document, such as `#schema`.
  Anchor
  /// A path from the bundle root, such as `/tables/customers.md`.
  BundleRooted
  /// A path relative to a base directory.
  Relative
} derive(Eq, Debug)

///|
/// One body link.
pub(all) struct Link {
  text : String
  destination : String
  /// The file line, counted from 1. A link that a profile adds has line 0.
  line : Int32
  kind : LinkKind
} derive(Eq, Debug)

///|
fn has_scheme(dest : String) -> Bool {
  let n = dest.length()
  if n == 0 {
    return false
  }
  let first = dest[0]
  guard (first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z') else {
    return false
  }
  for i in 1..<n {
    let c = dest[i]
    if c == ':' {
      return i > 1
    }
    let ok = (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '+' ||
      c == '-' ||
      c == '.'
    if !ok {
      return false
    }
  }
  false
}

///|
/// Classifies a link destination.
pub fn classify_destination(dest : String) -> LinkKind {
  if dest.has_prefix("#") {
    Anchor
  } else if dest.has_prefix("/") {
    BundleRooted
  } else if has_scheme(dest) {
    External
  } else {
    Relative
  }
}

///|
/// A link with a destination that this library computed, such as a profile link.
pub fn Link::Link(
  text : String,
  destination : String,
  line~ : Int32 = 0,
) -> Link {
  { text, destination, line, kind: classify_destination(destination), }
}

///|
/// The destination without its fragment.
pub fn Link::path_part(self : Link) -> String {
  match self.destination.find("#") {
    Some(i) => self.destination[:i].to_owned()
    None => self.destination
  }
}

///|
/// The fragment after `#`, if any.
pub fn Link::fragment(self : Link) -> String? {
  match self.destination.find("#") {
    Some(i) => Some(self.destination[i + 1:].to_owned())
    None => None
  }
}

///|
fn plain_text(inline : @cmark.Inline) -> String {
  inline
  .to_plain_text(break_on_soft=false)
  .fold(init="", (acc, line) => acc + line.fold(init="", (a, s) => a + s))
}

///|
/// The destination of a cmark link, resolving reference links through `defs`.
/// A footnote reference gives `None`.
fn link_destination(
  link : @cmark.InlineLink,
  defs : Map[String, @cmark.LabelDef],
) -> String? {
  match link.reference {
    Inline(def) =>
      match def.v.dest {
        Some(dest) => Some(dest.v)
        None => Some("")
      }
    Ref(_, _, _) =>
      match link.reference_definition(defs) {
        Some(LinkDef(def)) =>
          match def.v.dest {
            Some(dest) => Some(dest.v)
            None => Some("")
          }
        _ => None
      }
  }
}

///|
/// The footnote label of a cmark link, when it is a footnote reference.
fn footnote_label(
  link : @cmark.InlineLink,
  defs : Map[String, @cmark.LabelDef],
) -> String? {
  match link.reference {
    Ref(_, label, _) =>
      match link.reference_definition(defs) {
        Some(FootnoteDef(_)) => {
          let key = label.key
          Some(if key.has_prefix("^") { key[1:].to_owned() } else { key })
        }
        _ => None
      }
    _ => None
  }
}

///|
fn line_of_loc(loc : @cmark_base.TextLoc) -> Int32 {
  loc.first_line.0
}

///|
/// The body links of a document: inline, reference and autolinks, with file
/// lines. Images, footnote references and text inside code are left out.
pub fn Document::links(self : Document) -> Array[Link] {
  guard self.markdown is Some(md) else { return [] }
  let defs = md.to_cmark().defs
  let links = []
  @mdc.walk(md.root(), node => {
    match node {
      Inline(view) =>
        match view.kind() {
          Link =>
            match view.to_cmark() {
              Link(node) =>
                match link_destination(node.v, defs) {
                  Some(dest) =>
                    links.push({
                      text: plain_text(node.v.text),
                      destination: dest,
                      line: self.file_line(line_of_loc(view.location())),
                      kind: classify_destination(dest),
                    })
                  None => ()
                }
              _ => ()
            }
          Autolink =>
            match view.to_cmark() {
              Autolink(node) => {
                let dest = if node.v.is_email {
                  "mailto:" + node.v.link.v
                } else {
                  node.v.link.v
                }
                links.push({
                  text: node.v.link.v,
                  destination: dest,
                  line: self.file_line(line_of_loc(view.location())),
                  kind: classify_destination(dest),
                })
              }
              _ => ()
            }
          Image => return SkipChildren
          _ => ()
        }
      _ => ()
    }
    Continue
  })
  links
}

///|
/// A footnote reference in a body, such as `[^ga4-schema]`.
pub(all) struct Citation {
  label : String
  line : Int32
} derive(Eq, Debug)

///|
/// The footnote references of a body, in order.
pub fn Document::citations(self : Document) -> Array[Citation] {
  guard self.markdown is Some(md) else { return [] }
  let defs = md.to_cmark().defs
  let out = []
  @mdc.walk(md.root(), node => {
    match node {
      Inline(view) if view.kind() is Link =>
        match view.to_cmark() {
          Link(node) =>
            match footnote_label(node.v, defs) {
              Some(label) =>
                out.push({
                  label,
                  line: self.file_line(line_of_loc(view.location())),
                })
              None => ()
            }
          _ => ()
        }
      _ => ()
    }
    Continue
  })
  out
}

///|
/// A citation with the `sources` entry whose `id` equals its label.
pub fn Document::cited_sources(self : Document) -> Array[(Citation, Source?)] {
  let sources = self.metadata().sources()
  self
  .citations()
  .map(c => (c, sources.iter().find_first(s => s.id == Some(c.label))))
}

///|
/// Where a link points, before existence checks.
pub(all) enum Resolution {
  /// A URI with a scheme.
  ExternalUri(String)
  /// A fragment of the same document.
  SameDocument(String)
  /// A file path in the store. `escapes` is true when it leaves the bundle.
  StoreTarget(path~ : StorePath, fragment~ : String?, escapes~ : Bool)
  /// The destination is empty or leaves the store root.
  Unresolvable(String)
} derive(Eq, Debug)

///|
/// Resolves a link of `doc` in `bundle` with the link base of `options`.
pub fn resolve_link(
  bundle : Bundle,
  doc : Document,
  link : Link,
  options~ : Options = bundle.options(),
) -> Resolution {
  match link.kind {
    External => ExternalUri(link.destination)
    Anchor => SameDocument(link.fragment().unwrap_or(""))
    BundleRooted | Relative => {
      let path = link.path_part()
      if path.length() == 0 {
        return Unresolvable(link.destination)
      }
      let base : Array[String] = if link.kind is BundleRooted ||
        options.link_base is BundleRoot {
        []
      } else {
        doc.path().directory()
      }
      resolve_path(bundle, base, path, link.fragment(), link.destination)
    }
  }
}

///|
/// Resolves `path` against `base` (bundle segments) inside `bundle`.
fn resolve_path(
  bundle : Bundle,
  base : Array[String],
  path : String,
  fragment : String?,
  original : String,
) -> Resolution {
  let in_bundle = base.copy()
  let mut above = 0
  for part in path.replace_all(old="\\", new="/").split("/") {
    match part.to_owned() {
      "" | "." => ()
      ".." =>
        if in_bundle.is_empty() {
          above += 1
        } else {
          in_bundle.pop() |> ignore
        }
      p => if above > 0 { in_bundle.push(p) } else { in_bundle.push(p) }
    }
  }
  if above == 0 {
    if in_bundle.is_empty() {
      return Unresolvable(original)
    }
    return StoreTarget(
      path=bundle.store_path_of(BundlePath::of_segments(in_bundle)),
      fragment~,
      escapes=false,
    )
  }
  // The path climbs above the bundle root: resolve it from the store root.
  let root = bundle.root().iter().collect()
  let joined = root.copy()
  for p in base {
    joined.push(p)
  }
  let raw = joined.join("/") + "/" + path
  let normalized = normalize_path(raw)
  if normalized.above > 0 || normalized.segments.is_empty() {
    return Unresolvable(original)
  }
  StoreTarget(
    path=StorePath::of_segments(normalized.segments.iter().collect()),
    fragment~,
    escapes=true,
  )
}

///|
/// Resolves a path-valued field (such as `sources[].resource`) of `doc`.
pub fn resolve_field_path(
  bundle : Bundle,
  doc : Document,
  value : String,
  options~ : Options = bundle.options(),
) -> Resolution {
  resolve_link(bundle, doc, Link("", value), options~)
}

///|
/// Tests whether a store path exists. The default resolver knows the loaded
/// documents and assets; a caller can supply one that knows other files.
pub(open) trait LinkResolver {
  fn exists(Self, StorePath) -> Bool
}

///|
/// A resolver that knows every file of a document set.
pub(all) struct DocumentSetResolver {
  set : DocumentSet
}

///|
pub impl LinkResolver for DocumentSetResolver with fn exists(self, path) {
  self.set.contains(path)
}

///|
/// A resolver that knows a fixed list of extra paths.
pub(all) struct PathListResolver {
  paths : Array[StorePath]
}

///|
pub impl LinkResolver for PathListResolver with fn exists(self, path) {
  self.paths.contains(path)
}

///|
/// A resolver that knows the documents and assets of loaded knowledge.
pub(all) struct KnowledgeResolver {
  knowledge : Knowledge
}

///|
pub impl LinkResolver for KnowledgeResolver with fn exists(self, path) {
  match self.knowledge.bundle_at(path) {
    Some(bundle) =>
      match bundle.bundle_path_of(path) {
        Some(rel) =>
          bundle.document(rel) is Some(_) || bundle.assets().contains(rel)
        None => false
      }
    None => false
  }
}

///|
pub extend LinkKind with Eq::{not_equal, equal}

///|
pub extend LinkKind with @debug.Debug::{to_repr}

///|
pub extend Link with Eq::{not_equal, equal}

///|
pub extend Link with @debug.Debug::{to_repr}

///|
pub extend Citation with Eq::{not_equal, equal}

///|
pub extend Citation with @debug.Debug::{to_repr}

///|
pub extend Resolution with Eq::{not_equal, equal}

///|
pub extend Resolution with @debug.Debug::{to_repr}

///|
pub extend DocumentSetResolver with LinkResolver::{exists}

///|
pub extend PathListResolver with LinkResolver::{exists}

///|
pub extend KnowledgeResolver with LinkResolver::{exists}
