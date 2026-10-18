///|
enum CaseState {
  AwaitingSource
  Source(String)
  Parsed(String, @mdc.Document)
  Rejected(@mdc.ParseError)
}

///|
struct MdcWorld {
  mut state : CaseState
}

///|
fn MdcWorld::MdcWorld() -> MdcWorld {
  { state: AwaitingSource, }
}

///|
fn MdcWorld::parsed(self : MdcWorld) -> (String, @mdc.Document) raise {
  match self.state {
    Parsed(source, doc) => (source, doc)
    _ => fail("this step requires a successfully parsed document")
  }
}

///|
fn text_of(node : @mdc.Node) -> String {
  match node {
    Inline(view) =>
      match view.kind() {
        Text(text~) => text
        _ => ""
      }
    _ => ""
  }
}

///|
fn folded_text(doc : @mdc.Document) -> String {
  doc.fold(
    "",
    @mdc.Folder::Folder((text, node) => Continue(text + text_of(node))),
  )
}

///|
struct TextVisitor {
  text : StringBuilder
}

///|
impl @mdc.Visitor for TextVisitor with fn visit_inline(self, view) {
  if view.kind() is Text(text~) {
    self.text.write_string(text)
  }
  Continue
}

///|
impl @moonspec.World for MdcWorld with fn configure(self, setup) {
  setup.given1("the MDC source:", (doc : @moonspec.DocString) => {
    self.state = Source(doc.content)
  })
  setup.when0("the source is parsed", () => {
    guard self.state is Source(source) else { fail("no source supplied") }
    self.state = Parsed(source, @mdc.Document::Document(source)) catch {
      error => Rejected(error)
    }
  })
  setup.then1("the metadata is:", (expected : @moonspec.DocString) => {
    let (_, doc) = self.parsed()
    guard doc.frontmatter() is Some(header) else { fail("no frontmatter") }
    @expect.expect(header.value().to_json()).to_equal(
      @json.parse(expected.content),
    )
  })
  setup.then1("the Markdown body is:", (expected : @moonspec.DocString) => {
    let (source, doc) = self.parsed()
    @expect.expect_all(s => {
      s.expect(doc.body(), label="Markdown body").to_equal(expected.content)
      s
      .expect(source[doc.body_offset():].to_owned(), label="source suffix")
      .to_equal(doc.body())
    })
  })
  setup.then1("the heading levels are {string}", (expected : String) => {
    let (_, doc) = self.parsed()
    let levels = doc.fold(
      [],
      @mdc.Folder::Folder((levels, node) => {
        if node is Block(view) && view.kind() is Heading(level~) {
          levels.push(level.to_string())
        }
        Continue(levels)
      }),
    )
    @expect.expect(levels.join(",")).to_equal(expected)
  })
  setup.then1("the body starts on line {int}", (expected : Int32) => {
    let (_, doc) = self.parsed()
    @expect.expect(doc.body_line()).to_equal(expected)
  })
  setup.then0("there is no frontmatter", () => {
    let (_, doc) = self.parsed()
    @expect.expect(doc.frontmatter()).to_be_none()
  })
  setup.then0("the body is the complete source", () => {
    let (source, doc) = self.parsed()
    @expect.expect_all(s => {
      s.expect(doc.body()).to_equal(source)
      s.expect(doc.body_offset()).to_equal(0)
      s.expect(doc.body_line()).to_equal(1)
    })
  })
  setup.then0("the header is reported as unterminated", () => {
    @expect.expect(self.state is Rejected(@mdc.UnterminatedFrontmatter)).to_be_true()
  })
  setup.then2(
    "invalid frontmatter is reported at line {int} and column {int}",
    (expected_line : Int32, expected_column : Int32) => {
      guard self.state
        is Rejected(@mdc.InvalidFrontmatter(line~, column~, message~)) else {
        fail("expected an invalid-frontmatter error")
      }
      @expect.expect_all(s => {
        s.expect(line).to_equal(expected_line)
        s.expect(column).to_equal(expected_column)
        s.expect(message).not().to_be_empty()
      })
    },
  )
  setup.when0("the exported metadata and Markdown are changed", () => {
    let (_, doc) = self.parsed()
    guard doc.frontmatter() is Some(header) else { fail("no frontmatter") }
    guard header.value() is Map(fields) else { fail("not a mapping") }
    fields.clear()
    let exported = doc.to_cmark()
    exported.defs.clear()
    guard exported.block is Blocks({ v, .. }) else { fail("no block sequence") }
    v[0] = @cmark.Block::empty()
  })
  setup.then1("the document still contains {string}", (expected : String) => {
    let (_, doc) = self.parsed()
    @expect.expect_all(s => {
      s.expect(folded_text(doc)).to_equal(expected)
      s.expect(doc.to_cmark().defs.length()).to_equal(1)
    })
  })
  setup.then0("visitor, walk and fold observe the same text", () => {
    let (_, doc) = self.parsed()
    let visitor = TextVisitor::{ text: StringBuilder(), }
    doc.accept(visitor)
    let walked = StringBuilder()
    @mdc.walk(doc.root(), node => {
      walked.write_string(text_of(node))
      Continue
    })
    @expect.expect_all(s => {
      s
      .expect(visitor.text.to_string(), label="visitor")
      .to_equal("GoalA nested goal.")
      s
      .expect(walked.to_string(), label="walk")
      .to_equal(visitor.text.to_string())
      s
      .expect(folded_text(doc), label="fold")
      .to_equal(visitor.text.to_string())
    })
  })
  setup.then0("pruning block quotes hides their contents", () => {
    let (_, doc) = self.parsed()
    let text = doc.fold(
      "",
      @mdc.Folder::Folder((text, node) => {
        match node {
          Block(view) if view.kind() is BlockQuote => SkipChildren(text)
          _ => Continue(text + text_of(node))
        }
      }),
    )
    @expect.expect(text).to_equal("Goal")
  })
}

///|
async test "MDC acceptance scenarios" {
  @moonspec.run_or_fail(
    () => MdcWorld::MdcWorld(),
    @moonspec.RunOptions::RunOptions([
      @moonspec.FeatureSource::File("mdc-acceptance/features/mdc.feature"),
    ]),
  )
}
