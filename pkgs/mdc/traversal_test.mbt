///|
fn kind(node : @mdc.Node) -> String {
  match node {
    Document(_) => "document"
    Frontmatter(_) => "frontmatter"
    Block(view) =>
      match view.kind() {
        Blocks => "blocks"
        Heading(_) => "heading"
        Paragraph => "paragraph"
        BlockQuote => "quote"
        BlankLine => "blank"
        _ => "block"
      }
    Inline(view) =>
      match view.kind() {
        Text(text~) => text
        _ => "inline"
      }
  }
}

///|
struct RecordingVisitor {
  events : Array[String]
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_document(self, _) {
  self.events.push("document")
  Continue
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_frontmatter(self, _) {
  self.events.push("frontmatter")
  Continue
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_block(self, block) {
  self.events.push(kind(Block(block)))
  Continue
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_inline(self, inline) {
  self.events.push(kind(Inline(inline)))
  Continue
}

///|
impl @mdc.Visitor for RecordingVisitor with fn leave(self, node) {
  self.events.push("/\{kind(node)}")
}

///|
test "visitor and walk share ordered enter and leave events" {
  let doc = @mdc.parse("---\ntitle: Goal\n---\n# Goal\n")
  let visitor = RecordingVisitor::{ events: [], }
  doc.accept(visitor)
  assert_eq(visitor.events, [
    "document", "frontmatter", "/frontmatter", "blocks", "heading", "Goal", "/Goal",
    "/heading", "blank", "/blank", "/blocks", "/document",
  ])
  let events = []
  @mdc.walk(
    Document(doc),
    node => {
      events.push(kind(node))
      Continue
    },
    leave=node => events.push("/\{kind(node)}"),
  )
  assert_eq(events, visitor.events)
}

///|
test "skip prunes only children and balances leave callbacks" {
  let doc = @mdc.parse("> hidden\n\nafter\n")
  let events = []
  @mdc.walk(
    Document(doc),
    node => {
      events.push(kind(node))
      if node is Block(view) && view.kind() is BlockQuote {
        SkipChildren
      } else {
        Continue
      }
    },
    leave=node => events.push("/\{kind(node)}"),
  )
  assert_true(events.contains("after"))
  assert_false(events.contains("hidden"))
  assert_true(events.contains("/quote"))
  assert_eq(events.length() % 2, 0)
}

///|
test "stop prevents subsequent nodes and pending leaves" {
  let doc = @mdc.parse("---\ntitle: Goal\n---\n# Goal\n")
  let events = []
  @mdc.walk(
    Document(doc),
    node => {
      events.push(kind(node))
      if node is Frontmatter(_) {
        Stop
      } else {
        Continue
      }
    },
    leave=node => events.push("/\{kind(node)}"),
  )
  assert_eq(events, ["document", "frontmatter"])
}

///|
test "fold threads updates through skip and stop" {
  let doc = @mdc.parse("> hidden\n\n# Goal\n\nafter\n")
  let nodes = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      acc.push(kind(node))
      match node {
        Block(view) =>
          match view.kind() {
            BlockQuote => SkipChildren(acc)
            Heading(_) => Stop(acc)
            _ => Continue(acc)
          }
        _ => Continue(acc)
      }
    }),
  )
  assert_true(nodes.contains("quote"))
  assert_eq(nodes.last(), Some("heading"))
  assert_false(nodes.contains("hidden"))
  assert_false(nodes.contains("Goal"))
  assert_false(nodes.contains("after"))
}

///|
test "traversal reaches nested Markdown and extension children once" {
  let doc = @mdc.parse(
    "- > **strong** and *em* [link](https://example.com) ![alt](image.png) ~~strike~~\n\n| head |\n| --- |\n| cell |\n\n[^note]: footnote\n\nref[^note]\n",
    strict=false,
  )
  let texts = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      if node is Inline(view) && view.kind() is Text(text~) {
        acc.push(text)
      }
      Continue(acc)
    }),
  )
  for
    text in [
      "strong", "em", "link", "alt", "strike", "head", "cell", "footnote",
    ] {
    assert_eq(texts.filter(t => t == text).length(), 1)
  }
}
