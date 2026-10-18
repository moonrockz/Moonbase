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
priv struct TextSummary {
  text : String
}

///|
impl @mdc.Fold for TextSummary with fn enter(self, node) {
  match node {
    Block(view) if view.kind() is BlockQuote => SkipChildren(self)
    _ => Continue({ text: self.text + text_of(node), })
  }
}

///|
impl @mdc.Reducer for TextSummary with fn reduce(node, children) {
  { text: text_of(node) + children.map(child => child.text).join(""), }
}

///|
priv struct PositionSummary {
  paths : String
}

///|
impl @mdc.CursorFold for PositionSummary with fn enter(self, cursor) {
  Continue({ paths: self.paths + cursor.path().to_string() + "\n", })
}

///|
impl @mdc.CursorReducer for PositionSummary with fn reduce(cursor, children) {
  {
    paths: cursor.path().to_string() +
    "\n" +
    children.map(child => child.paths).join(""),
  }
}

///|
struct CursorTextVisitor {
  positions : Array[String]
  saved : Array[@mdc.Cursor]
}

///|
impl @mdc.CursorVisitor for CursorTextVisitor with fn visit_inline(self, cursor) {
  if cursor.node() is Inline(view) && view.kind() is Text(text~) {
    self.positions.push(cursor.path().to_string() + ":" + text)
    self.saved.push(cursor)
    // Navigation produces a different immutable position.
    ignore(cursor.parent().map(parent => parent.first_child()))
    ignore(cursor.next_sibling())
  }
  Continue
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
  setup.then0("cursors can navigate metadata, parents and siblings", () => {
    let (_, doc) = self.parsed()
    let root = doc.cursor()
    guard root.first_child() is Some(header) else { fail("no header position") }
    guard header.next_sibling() is Some(markdown) else {
      fail("no Markdown sibling")
    }
    guard markdown.previous_sibling() is Some(previous) else {
      fail("no previous sibling")
    }
    guard markdown.parent() is Some(parent) else { fail("no parent") }
    @expect.expect_all(s => {
      s.expect(root.path().to_string(), label="saved root").to_equal("$")
      s.expect(root.parent()).to_be_none()
      s.expect(root.previous_sibling()).to_be_none()
      s.expect(root.next_sibling()).to_be_none()
      s.expect(header.node() is Frontmatter(_)).to_be_true()
      s.expect(header.first_child()).to_be_none()
      s.expect(header.last_child()).to_be_none()
      s.expect(header.path().to_string()).to_equal("$[0]")
      s.expect(markdown.path().to_string()).to_equal("$[1]")
      s.expect(markdown.depth()).to_equal(1)
      s.expect(markdown.next_sibling()).to_be_none()
      s.expect(previous.path()).to_equal(header.path())
      s.expect(parent.path()).to_equal(root.path())
      s
      .expect(doc.root().at(header.path()) is Some(Frontmatter(_)))
      .to_be_true()
    })
  })
  setup.then0("subtree operations retain their original navigation context", () => {
    let (_, doc) = self.parsed()
    guard doc.cursor().last_child() is Some(markdown) else {
      fail("no Markdown")
    }
    let depths = markdown.fold(
      [],
      @mdc.Folder::with_cursor((depths, cursor) => {
        depths.push(cursor.depth())
        Continue(depths)
      }),
    )
    let path = markdown.reduce((cursor, _) => cursor.path().to_string())
    @expect.expect_all(s => {
      s.expect(depths.get(0)).to_equal(Some(1))
      s.expect(path).to_equal("$[1]")
      s
      .expect(markdown.path().to_string(), label="saved position")
      .to_equal("$[1]")
      s
      .expect(markdown.node().cursor().depth(), label="rebased node cursor")
      .to_equal(0)
    })
  })
  setup.then0("cursor visitor, walk and fold observe the same positions", () => {
    let (_, doc) = self.parsed()
    let visitor = CursorTextVisitor::{ positions: [], saved: [], }
    doc.accept_cursor(visitor)
    let walked = []
    @mdc.walk_cursor(doc.root(), cursor => {
      let text = text_of(cursor.node())
      if text != "" {
        walked.push(cursor.path().to_string() + ":" + text)
      }
      Continue
    })
    let folded = doc.fold(
      [],
      @mdc.Folder::with_cursor((positions, cursor) => {
        let text = text_of(cursor.node())
        if text != "" {
          positions.push(cursor.path().to_string() + ":" + text)
        }
        Continue(positions)
      }),
    )
    let saved = visitor.saved.map(cursor => {
      cursor.path().to_string() + ":" + text_of(cursor.node())
    })
    @expect.expect_all(s => {
      s.expect(walked).not().to_be_empty()
      s.expect(visitor.positions, label="visitor").to_equal(walked)
      s.expect(folded, label="folder").to_equal(walked)
      s.expect(saved, label="saved positions after traversal").to_equal(walked)
    })
  })
  setup.then1("bottom-up reduction composes {string} in document order", (
    expected : String,
  ) => {
    let (_, doc) = self.parsed()
    let mut child_counts_match = true
    let mut leaves = 0
    let text = doc.reduce((node, children) => {
      if children.length() != node.children().length() {
        child_counts_match = false
      }
      if children.is_empty() {
        leaves += 1
      }
      text_of(node) + children.join("")
    })
    let count = doc.reduce((_, children) => {
      1 + children.fold(init=0, (sum, count) => sum + count)
    })
    let folded_count = doc.fold(
      0,
      @mdc.Folder::Folder((count, _) => Continue(count + 1)),
    )
    @expect.expect_all(s => {
      s.expect(text).to_equal(expected)
      s.expect(child_counts_match).to_be_true()
      s.expect(leaves).to_be_greater_than(0)
      s.expect(count).to_equal(folded_count)
    })
  })
  setup.then0(
    "consumer traits fold with pruning and reduce complete child results",
    () => {
      let (_, doc) = self.parsed()
      let initial = TextSummary::{ text: "", }
      let folded = doc.fold_with(initial)
      let reduced : TextSummary = doc.reduce_with()
      let adapted = doc.fold(initial, @mdc.Folder::from_trait())
      @expect.expect_all(s => {
        s.expect(folded.text).to_equal("Goal")
        s.expect(adapted.text).to_equal(folded.text)
        s.expect(reduced.text).to_equal("GoalA nested goal.")
        s.expect(initial.text, label="immutable initial state").to_equal("")
      })
    },
  )
  setup.then0("consumer cursor traits preserve saved subtree paths", () => {
    let (_, doc) = self.parsed()
    guard doc.cursor().last_child() is Some(saved) else { fail("no Markdown") }
    let initial = PositionSummary::{ paths: "", }
    let folded = saved.fold_with(initial)
    let reduced : PositionSummary = saved.reduce_with()
    let expected = saved.fold(
      "",
      @mdc.Folder::with_cursor((paths, cursor) => {
        Continue(paths + cursor.path().to_string() + "\n")
      }),
    )
    let document_fold = doc.fold_cursor_with(initial)
    let document_reduce : PositionSummary = doc.reduce_cursor_with()
    @expect.expect_all(s => {
      s.expect(folded.paths).to_equal(expected)
      s.expect(reduced.paths).to_equal(expected)
      s.expect(document_fold.paths).to_equal(document_reduce.paths)
      s.expect(saved.path().to_string()).to_equal("$[1]")
      s.expect(initial.paths).to_equal("")
    })
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
