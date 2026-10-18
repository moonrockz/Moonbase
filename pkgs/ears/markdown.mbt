///|
// Flatten inline presentation only. Destinations, raw HTML and image alt text
// cannot introduce requirement words. Code spans in a sentence remain text.
fn paragraph_text(node : @mdc.Node) -> String {
  let out = StringBuilder()
  @mdc.walk(node, node => {
    if node is Inline(view) {
      match view.kind() {
        Text(text~) => out.write_string(text)
        CodeSpan(code~) => out.write_string(code)
        Break => out.write_string(" ")
        Autolink =>
          if view.to_cmark() is Autolink({ v, .. }) {
            out.write_string(v.link.v)
          }
        ExtMathSpan(tex~) => out.write_string(tex)
        Image | RawHtml => return SkipChildren
        _ => ()
      }
    }
    Continue
  })
  out.to_string()
}

///|
fn is_candidate(text : String) -> Bool {
  for keyword in ["where", "while", "when", "if"] {
    if starts_word(text, keyword) {
      return true
    }
  }
  starts_word(text, "the") &&
  text
  .split(" ")
  .any(word => {
    let word = word.to_owned().to_lower()
    word == "shall" || word == "should" || word == "must"
  })
}

///|
/// Extract one sentence per paragraph, including paragraphs in lists and
/// blockquotes. Wrapped lines and inline formatting form a single sentence.
/// Skip headings, code, HTML, tables, footnotes and frontmatter. Non-EARS prose
/// is ignored; malformed candidates become diagnostics. No reparsing occurs.
pub fn from_mdc(document : @mdc.Document) -> Specification {
  let requirements = []
  let diagnostics = []
  @mdc.walk_cursor(document.root(), cursor => {
    if cursor.node() is Block(view) {
      match view.kind() {
        Paragraph => {
          let text = normalize(paragraph_text(cursor.node()))
          if is_candidate(text) {
            let loc = view.location()
            let span = if loc.is_none() {
              None
            } else {
              Some(SourceSpan::{
                start: document.body_offset() + loc.first_ccode,
                end: document.body_offset() + loc.last_ccode + 1,
                line: document.body_line() + loc.first_line.0 - 1,
                column: loc.first_ccode -
                loc.first_line.1 +
                1 +
                (if document.body_line() == 1 && loc.first_line.0 == 1 {
                  document.body_offset()
                } else {
                  0
                }),
              })
            }
            collect_candidate(
              text,
              Markdown(path=cursor.path(), span~),
              requirements,
              diagnostics,
            )
          }
          return SkipChildren
        }
        Heading(_) | CodeBlock | HtmlBlock | ExtTable | ExtFootnoteDefinition =>
          return SkipChildren
        _ => ()
      }
    }
    Continue
  })
  {
    requirements: ReadOnlyArray::from_array(requirements[:]),
    diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
    document: Some(document),
  }
}

///|
/// Parse Markdown with optional YAML frontmatter, then extract EARS sentences.
/// Invalid frontmatter raises MDC's ParseError. EARS errors are diagnostics.
pub fn parse_markdown(
  source : String,
  strict~ : Bool = true,
  file~ : String = "",
) -> Specification raise @mdc.ParseError {
  from_mdc(@mdc.Document::Document(source, strict~, file~))
}
