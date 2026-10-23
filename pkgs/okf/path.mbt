///|
/// The result of normalizing a path: the segments that remain after `.` and
/// `..` are removed, and how many `..` segments climbed above the start.
pub(all) struct Normalized {
  segments : ReadOnlyArray[String]
  above : Int32
} derive(Eq, Debug)

///|
/// Splits `text` on `/` and `\`, removes empty and `.` segments, and applies
/// `..` segments. A `..` with nothing left to remove counts in `above`.
pub fn normalize_path(text : String) -> Normalized {
  let segments : Array[String] = []
  let mut above = 0
  for part in text.replace_all(old="\\", new="/").split("/") {
    let part = part.to_owned()
    match part {
      "" | "." => ()
      ".." =>
        if segments.is_empty() {
          above += 1
        } else {
          segments.pop() |> ignore
        }
      _ => segments.push(part)
    }
  }
  { segments: ReadOnlyArray::from_array(segments), above, }
}

///|
/// Raised for a path that cannot name a file inside a root.
pub(all) suberror PathError {
  /// The path climbs above its root, for example `../outside.md`.
  EscapesRoot(String)
  /// The path names no file, for example `""` or `/`.
  EmptyPath(String)
} derive(Eq, Debug)

///|
/// A file path relative to the root of a document set or store. It never
/// escapes that root. Its text form uses `/` and has no leading `/`.
struct StorePath {
  segments : ReadOnlyArray[String]
} derive(Eq, Hash, Debug)

///|
/// Validates `text` as a store path. `/` and `\` are both separators.
pub fn StorePath::StorePath(text : String) -> StorePath raise PathError {
  let normalized = normalize_path(text)
  if normalized.above > 0 {
    raise EscapesRoot(text)
  }
  if normalized.segments.length() == 0 {
    raise EmptyPath(text)
  }
  { segments: normalized.segments, }
}

///|
fn StorePath::of_segments(segments : Array[String]) -> StorePath {
  { segments: ReadOnlyArray::from_array(segments), }
}

///|
pub fn StorePath::segments(self : StorePath) -> ReadOnlyArray[String] {
  self.segments
}

///|
/// The last segment, for example `customers.md`.
pub fn StorePath::name(self : StorePath) -> String {
  self.segments[self.segments.length() - 1]
}

///|
/// The directory segments, without the file name.
pub fn StorePath::parent(self : StorePath) -> Array[String] {
  self.segments.exact_view(end=self.segments.length() - 1).to_owned()
}

///|
/// True when `self` is inside the directory `dir` (given as segments).
pub fn StorePath::is_under(self : StorePath, dir : Array[String]) -> Bool {
  if dir.length() >= self.segments.length() {
    return false
  }
  for i, segment in dir {
    if self.segments[i] != segment {
      return false
    }
  }
  true
}

///|
pub impl Show for StorePath with fn output(self, logger) {
  logger.write_string(self.segments.join("/"))
}

///|
pub fn StorePath::to_string(self : StorePath) -> String {
  self.segments.join("/")
}

///|
/// A path relative to a bundle root. Its text form starts with `/`, as OKF
/// bundle-rooted links do, for example `/tables/customers.md`.
struct BundlePath {
  segments : ReadOnlyArray[String]
} derive(Eq, Hash, Debug)

///|
/// Validates `text` as a bundle path. A leading `/` is optional.
pub fn BundlePath::BundlePath(text : String) -> BundlePath raise PathError {
  let normalized = normalize_path(text)
  if normalized.above > 0 {
    raise EscapesRoot(text)
  }
  if normalized.segments.length() == 0 {
    raise EmptyPath(text)
  }
  { segments: normalized.segments, }
}

///|
fn BundlePath::of_segments(segments : Array[String]) -> BundlePath {
  { segments: ReadOnlyArray::from_array(segments), }
}

///|
pub fn BundlePath::segments(self : BundlePath) -> ReadOnlyArray[String] {
  self.segments
}

///|
pub fn BundlePath::name(self : BundlePath) -> String {
  self.segments[self.segments.length() - 1]
}

///|
/// The directory segments, without the file name.
pub fn BundlePath::directory(self : BundlePath) -> Array[String] {
  self.segments.exact_view(end=self.segments.length() - 1).to_owned()
}

///|
/// The number of directories above the file, 0 for a file at the bundle root.
pub fn BundlePath::depth(self : BundlePath) -> Int32 {
  self.segments.length() - 1
}

///|
/// True when the path ends with `suffix`, compared segment by segment.
pub fn BundlePath::ends_with(self : BundlePath, suffix : String) -> Bool {
  let wanted = normalize_path(suffix).segments
  let n = wanted.length()
  let m = self.segments.length()
  if n == 0 || n > m {
    return false
  }
  for i in 0..<n {
    if self.segments[m - n + i] != wanted[i] {
      return false
    }
  }
  true
}

///|
pub impl Show for BundlePath with fn output(self, logger) {
  logger.write_string("/" + self.segments.join("/"))
}

///|
pub fn BundlePath::to_string(self : BundlePath) -> String {
  "/" + self.segments.join("/")
}

///|
/// The OKF Concept ID: the bundle path without its leading `/` and without the
/// `.md` extension, for example `tables/customers`.
struct ConceptId {
  text : String
} derive(Eq, Hash, Debug)

///|
/// Validates `text` as a Concept ID. A trailing `.md` and a leading `/` are
/// removed, so `/tables/customers.md` and `tables/customers` are equal.
pub fn ConceptId::ConceptId(text : String) -> ConceptId raise PathError {
  let path = BundlePath(text)
  ConceptId::of_path(path)
}

///|
/// The Concept ID of the file at `path`.
pub fn ConceptId::of_path(path : BundlePath) -> ConceptId {
  let text = path.segments.join("/")
  let text = if text.has_suffix(".md") {
    text[:text.length() - 3].to_owned()
  } else {
    text
  }
  { text, }
}

///|
/// The bundle path of the Markdown file for this Concept ID.
pub fn ConceptId::to_path(self : ConceptId) -> BundlePath {
  BundlePath::of_segments(
    (self.text + ".md").split("/").map(s => s.to_owned()).collect(),
  )
}

///|
pub impl Show for ConceptId with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub fn ConceptId::to_string(self : ConceptId) -> String {
  self.text
}

///|
/// True when `name` ends with `.md`, ignoring letter case.
pub fn is_markdown_name(name : String) -> Bool {
  name.to_lower().has_suffix(".md")
}

///|
pub extend Normalized with Eq::{not_equal, equal}

///|
pub extend Normalized with @debug.Debug::{to_repr}

///|
pub extend PathError with Eq::{not_equal, equal}

///|
pub extend PathError with @debug.Debug::{to_repr}

///|
pub extend StorePath with Eq::{not_equal, equal}

///|

///|
pub extend StorePath with Hash::{hash, hash_combine}

///|
pub extend StorePath with @debug.Debug::{to_repr}

///|
pub extend StorePath with Show::{output}

///|
pub extend BundlePath with Eq::{not_equal, equal}

///|

///|
pub extend BundlePath with Hash::{hash, hash_combine}

///|
pub extend BundlePath with @debug.Debug::{to_repr}

///|
pub extend BundlePath with Show::{output}

///|
pub extend ConceptId with Eq::{not_equal, equal}

///|

///|
pub extend ConceptId with Hash::{hash, hash_combine}

///|
pub extend ConceptId with @debug.Debug::{to_repr}

///|
pub extend ConceptId with Show::{output}

///|
/// Compares two strings code unit by code unit, so that `a` < `ab` < `b`.
pub fn lexical_compare(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let x = a[i]
    let y = b[i]
    if x != y {
      return if x < y { -1 } else { 1 }
    }
  }
  a.length().compare(b.length())
}

///|
fn compare_segments(
  a : ReadOnlyArray[String],
  b : ReadOnlyArray[String],
) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = lexical_compare(a[i], b[i])
    if c != 0 {
      return c
    }
  }
  a.length().compare(b.length())
}

///|
pub impl Compare for StorePath with fn compare(self, other) {
  compare_segments(self.segments, other.segments)
}

///|
pub impl Compare for BundlePath with fn compare(self, other) {
  compare_segments(self.segments, other.segments)
}

///|
pub impl Compare for ConceptId with fn compare(self, other) {
  lexical_compare(self.text, other.text)
}

///|
pub extend StorePath with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend BundlePath with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ConceptId with Compare::{op_lt, op_le, op_ge, compare, op_gt}
