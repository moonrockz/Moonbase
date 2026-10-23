///|
/// The content of one file in a document set.
pub(all) enum FileContent {
  Text(String)
  Bytes(Bytes)
} derive(Eq, Debug)

///|
/// One file of a document set: its store path and its content.
pub(all) struct FileEntry {
  path : StorePath
  content : FileContent
} derive(Eq, Debug)

///|
/// An immutable set of files in memory, sorted by path. It is the input of the
/// pure core: stores read into a document set, and the core loads bundles from it.
struct DocumentSet {
  entries : ReadOnlyArray[FileEntry]
  by_path : Map[StorePath, Int32]
}

///|
/// Builds a document set. A later entry for the same path replaces an earlier one.
pub fn DocumentSet::DocumentSet(entries : ArrayView[FileEntry]) -> DocumentSet {
  let latest : Map[StorePath, FileEntry] = Map([])
  for entry in entries {
    latest[entry.path] = entry
  }
  let sorted = latest.values().collect()
  sorted.sort_by((a, b) => a.path.compare(b.path))
  let by_path : Map[StorePath, Int32] = Map([])
  for i, entry in sorted {
    by_path[entry.path] = i
  }
  { entries: ReadOnlyArray::from_array(sorted), by_path, }
}

///|
/// Builds a document set from `(path, text)` pairs.
pub fn DocumentSet::of_texts(
  files : ArrayView[(String, String)],
) -> DocumentSet raise PathError {
  let entries = []
  for file in files {
    entries.push({ path: StorePath(file.0), content: Text(file.1), })
  }
  DocumentSet(entries)
}

///|
/// All files, sorted by path.
pub fn DocumentSet::entries(self : DocumentSet) -> ReadOnlyArray[FileEntry] {
  self.entries
}

///|
pub fn DocumentSet::get(self : DocumentSet, path : StorePath) -> FileEntry? {
  match self.by_path.get(path) {
    Some(i) => Some(self.entries[i])
    None => None
  }
}

///|
pub fn DocumentSet::contains(self : DocumentSet, path : StorePath) -> Bool {
  self.by_path.contains(path)
}

///|
/// True when a file exists under the directory `dir`, given as segments.
pub fn DocumentSet::has_directory(
  self : DocumentSet,
  dir : Array[String],
) -> Bool {
  if dir.is_empty() {
    return !self.entries.is_empty()
  }
  self.entries.any(e => e.path.is_under(dir))
}

///|
/// A new document set with `entry` added or replaced.
pub fn DocumentSet::with_entry(
  self : DocumentSet,
  entry : FileEntry,
) -> DocumentSet {
  let entries = self.entries.iter().filter(e => e.path != entry.path).collect()
  entries.push(entry)
  DocumentSet(entries)
}

///|
/// A new document set without the file at `path`.
pub fn DocumentSet::without(
  self : DocumentSet,
  path : StorePath,
) -> DocumentSet {
  DocumentSet(self.entries.iter().filter(e => e.path != path).collect())
}

///|
/// The number of files.
pub fn DocumentSet::length(self : DocumentSet) -> Int32 {
  self.entries.length()
}

///|
/// The text of a file, decoding bytes as UTF-8 when needed.
pub fn FileContent::text(self : FileContent) -> String {
  match self {
    Text(text) => text
    Bytes(bytes) => decode_utf8(bytes)
  }
}

///|
/// Decodes UTF-8, replacing invalid sequences with U+FFFD.
fn decode_utf8(bytes : Bytes) -> String {
  let out = StringBuilder()
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let b0 = bytes[i].to_int()
    let (code, size) = if b0 < 0x80 {
      (b0, 1)
    } else if b0 >= 0xC2 && b0 < 0xE0 && i + 1 < n {
      (((b0 & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F), 2)
    } else if b0 >= 0xE0 && b0 < 0xF0 && i + 2 < n {
      (
        ((b0 & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F),
        3,
      )
    } else if b0 >= 0xF0 && b0 < 0xF5 && i + 3 < n {
      (
        ((b0 & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F),
        4,
      )
    } else {
      (0xFFFD, 1)
    }
    out.write_char(Int32::unsafe_to_char(code))
    i += size
  }
  out.to_string()
}

///|
/// Encodes text as UTF-8.
pub fn encode_utf8(text : String) -> Bytes {
  let out = Buffer()
  for ch in text {
    out.write_char_utf8(ch)
  }
  out.to_bytes()
}

///|
pub extend FileContent with Eq::{not_equal, equal}

///|
pub extend FileContent with @debug.Debug::{to_repr}

///|
pub extend FileEntry with Eq::{not_equal, equal}

///|
pub extend FileEntry with @debug.Debug::{to_repr}
