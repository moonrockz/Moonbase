///|
/// Generate valid documents by construction, including nested Markdown,
/// Unicode metadata, optional headers/BOMs and all supported newline forms.
priv struct DocumentCase {
  choices : ReadOnlyArray[UInt32]
  style : UInt32
  bom : Bool
  with_header : Bool
} derive(Debug)

///|
impl @quickcheck.Arbitrary for DocumentCase with fn arbitrary(size, state) {
  let (choices, style, bom, with_header) : (
    ReadOnlyArray[UInt32],
    UInt32,
    Bool,
    Bool,
  ) = @quickcheck.Arbitrary::arbitrary(size, state)
  { choices, style, bom, with_header, }
}

///|
// Shrink the generation choices, then render them again. Every candidate stays
// a valid document, so failures cannot shrink into unrelated syntax errors.
impl @shrink.Shrink for DocumentCase with fn shrink(self) {
  @shrink.Shrink::shrink((self.choices, self.style, self.bom, self.with_header)).map(parts => {
      let (choices, style, bom, with_header) = parts
      { choices, style, bom, with_header, }
    },
  )
}

///|
fn DocumentCase::newline(self : DocumentCase) -> String {
  match self.style % 3 {
    0 => "\n"
    1 => "\r\n"
    _ => "\r"
  }
}

///|
fn DocumentCase::title(self : DocumentCase) -> String {
  let titles = ["Goal", "🌙 Moon", "Café", "目標"]
  titles[(self.style % 4).reinterpret_as_int()] +
  self.choices.length().to_string()
}

///|
fn DocumentCase::payload(self : DocumentCase) -> String {
  let title = self.title()
  "title: '\{title}'\nactive: true\ncount: \{self.choices.length()}\nsteps:\n  - title: '\{title}'\n".replace(
    old="\n",
    new=self.newline(),
  )
}

///|
fn DocumentCase::body(self : DocumentCase) -> String {
  let body = StringBuilder()
  for i, choice in self.choices {
    let fragment = match choice % 9 {
      0 => "# Heading \{i}\n\n"
      1 => "paragraph \{i} with **strong** and [link](https://example.com).\n\n"
      2 => "> quoted \{i} with *emphasis*\n>\n> - nested \{i}\n\n"
      3 => "- item \{i}\n  - child \{i}\n\n"
      4 => "```mbt\nvalue \{i}\n```\n\n"
      5 => "| header |\n| --- |\n| cell \{i} |\n\n"
      6 => "[^note\{i}]: footnote \{i}\n\nref[^note\{i}]\n\n"
      7 => "text `code \{i}` ~~strike \{i}~~ $x\{i}$\n\n"
      _ => "<div>\nhtml \{i}\n</div>\n\n"
    }
    body.write_string(fragment)
  }
  body.to_string().replace(old="\n", new=self.newline())
}

///|
fn DocumentCase::prefix(self : DocumentCase) -> String {
  let bom = if self.bom { "\u{FEFF}" } else { "" }
  if self.with_header {
    let nl = self.newline()
    "\{bom}---\{nl}\{self.payload()}---\{nl}"
  } else {
    bom
  }
}

///|
fn DocumentCase::source(self : DocumentCase) -> String {
  self.prefix() + self.body()
}

///|
fn DocumentCase::document(self : DocumentCase) -> @mdc.Document raise {
  @mdc.Document::Document(self.source(), strict=false, file="generated.mdc")
}
