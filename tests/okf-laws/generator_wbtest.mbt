///|
/// Generation choices for a small bundle. Every value it renders is valid by
/// construction, and shrinking the choices keeps it valid.
priv struct BundleCase {
  choices : ReadOnlyArray[UInt32]
  crlf : Bool
} derive(Debug)

///|
impl @quickcheck.Arbitrary for BundleCase with fn arbitrary(size, state) {
  let (choices, crlf) : (ReadOnlyArray[UInt32], Bool) = @quickcheck.Arbitrary::arbitrary(
    size, state,
  )
  { choices, crlf, }
}

///|
impl @shrink.Shrink for BundleCase with fn shrink(self) {
  @shrink.Shrink::shrink((self.choices, self.crlf)).map(p => {
    choices: p.0,
    crlf: p.1,
  })
}

///|
fn BundleCase::pick(self : BundleCase, i : Int32, n : Int32) -> Int32 {
  if self.choices.is_empty() {
    0
  } else {
    (self.choices[i % self.choices.length()] % n.reinterpret_as_uint()).reinterpret_as_int()
  }
}

///|
let names : Array[String] = [
  "orders", "customers", "revenue", "churn", "margin", "café", "目標",
]

///|
let dirs : Array[String] = ["", "tables/", "metrics/", "metrics/daily/"]

///|
let scalars : Array[String] = [
  "2026-09-01T00:00:00Z", "007", "true", "3.10", "plain text", "ünïcödé 🌙",
  "2026-01-31",
]

///|
/// The concept paths of the case, without duplicates, sorted.
fn BundleCase::paths(self : BundleCase) -> Array[String] {
  let n = 1 + self.pick(0, 5)
  let out = []
  for i in 0..<n {
    let p = dirs[self.pick(i * 3 + 1, dirs.length())] +
      names[self.pick(i * 3 + 2, names.length())] +
      ".md"
    if !out.contains(p) {
      out.push(p)
    }
  }
  out.sort_by(@okf.lexical_compare)
  out
}

///|
fn BundleCase::newline(self : BundleCase) -> String {
  if self.crlf {
    "\r\n"
  } else {
    "\n"
  }
}

///|
/// The extension keys and their scalar values of the concept at index `i`.
fn BundleCase::extras(self : BundleCase, i : Int32) -> Array[(String, String)] {
  let n = self.pick(i + 7, 4)
  let out = []
  for j in 0..<n {
    let key = "x_" + j.to_string() + "_" + self.pick(i + j + 11, 9).to_string()
    out.push((key, scalars[self.pick(i * 5 + j, scalars.length())]))
  }
  out
}

///|
/// The text of the concept at index `i`: frontmatter with `type`, `title`,
/// `description` and extension keys, and a body that links to other concepts.
fn BundleCase::concept_text(self : BundleCase, i : Int32) -> String {
  let nl = self.newline()
  let paths = self.paths()
  let lines = ["---", "type: Metric", "title: T\{i}", "description: D\{i}"]
  for kv in self.extras(i) {
    lines.push(kv.0 + ": " + kv.1)
  }
  lines.push("---")
  lines.push("# T\{i}")
  lines.push("")
  let links = self.pick(i + 13, 3)
  for j in 0..<links {
    let target = paths[self.pick(i + j * 7 + 17, paths.length())]
    lines.push("See [L\{j}](/\{target}).")
  }
  lines.join(nl) + nl
}

///|
fn BundleCase::set(self : BundleCase) -> @okf.DocumentSet {
  let files = [("index.md", "---\nokf_version: \"0.2\"\n---\n")]
  for i, p in self.paths() {
    files.push((p, self.concept_text(i)))
  }
  @okf.DocumentSet::of_texts(files) catch {
    _ => panic()
  }
}

///|
fn BundleCase::bundle(self : BundleCase) -> @okf.Bundle {
  @okf.load_bundle(self.set())
}
