///|
fn document_text(doc : @mdc.Document) -> String {
  doc.fold(
    "",
    @mdc.Folder::Folder((text, node) => {
      match node {
        Inline(view) =>
          match view.kind() {
            Text(text=part) => Continue(text + part)
            _ => Continue(text)
          }
        _ => Continue(text)
      }
    }),
  )
}

///|
test "document construction derives its state and exports independent cmark trees" {
  let source = "---\ntitle: Goal\n---\n# Goal\n\nA **goal**.\n\n[ref]: https://example.com \"title\"\n"
  let doc = @mdc.Document::Document(source)
  let original = @debug.to_string(doc.to_cmark())
  let exported = doc.to_cmark()
  exported.defs.clear()
  guard exported.block is Blocks({ v, .. }) else { fail("no blocks") }
  v[0] = @cmark.Block::empty()
  assert_eq(@debug.to_string(doc.to_cmark()), original)
  assert_eq(document_text(doc), "GoalA goal.")
  assert_true(doc.body().has_prefix("# Goal"))
  assert_eq(doc.body_line(), 4)
  assert_eq(doc.body_offset(), 20)
}

///|
struct ExportMutator {
  mut blocks : Int32
  mut inlines : Int32
}

///|
impl @mdc.Visitor for ExportMutator with fn visit_block(self, view) {
  if view.to_cmark() is Blocks({ v, .. }) && !v.is_empty() {
    v[0] = @cmark.Block::empty()
    self.blocks += 1
  }
  Continue
}

///|
impl @mdc.Visitor for ExportMutator with fn visit_inline(self, view) {
  if view.to_cmark() is Inlines({ v, .. }) && !v.is_empty() {
    v[0] = @cmark.Inline::empty()
    self.inlines += 1
  }
  Continue
}

///|
test "visitor exports cannot mutate current or future traversals" {
  let doc = @mdc.parse("# A **goal**\n\nKeep *this*.\n")
  let original = document_text(doc)
  let visitor = ExportMutator::{ blocks: 0, inlines: 0, }
  doc.accept(visitor)
  assert_true(visitor.blocks > 0)
  assert_true(visitor.inlines > 0)
  let mut observed = ""
  @mdc.walk(doc.root(), node => {
    match node {
      Block(view) =>
        if view.to_cmark() is Blocks({ v, .. }) && !v.is_empty() {
          v[0] = @cmark.Block::empty()
        }
      Inline(view) => {
        if view.to_cmark() is Inlines({ v, .. }) && !v.is_empty() {
          v[0] = @cmark.Inline::empty()
        }
        if view.kind() is Text(text~) {
          observed += text
        }
      }
      _ => ()
    }
    Continue
  })
  assert_eq(observed, original)
  assert_eq(document_text(doc), original)
}

///|
test "exported reference labels, titles and footnotes are independent" {
  let doc = @mdc.parse(
    "[link][ref]\n\n[ref]: https://example.com \"title\"\n\n[^note]: footnote\n\nref[^note]\n",
    strict=false,
  )
  let original = @debug.to_string(doc.to_cmark())
  let exported = doc.to_cmark()
  let mut changed = 0
  for _, definition in exported.defs {
    match definition {
      LinkDef({ v, .. }) => {
        if v.title is Some(title) && !title.is_empty() {
          title[0] = @cmark.Tight::empty()
          changed += 1
        }
        if v.label is Some(label) && !label.text.is_empty() {
          label.text[0] = @cmark.Tight::empty()
          changed += 1
        }
      }
      FootnoteDef({ v, .. }) => {
        if !v.label.text.is_empty() {
          v.label.text[0] = @cmark.Tight::empty()
          changed += 1
        }
        if v.block is Blocks({ v, .. }) && !v.is_empty() {
          v[0] = @cmark.Block::empty()
          changed += 1
        }
      }
    }
  }
  assert_true(changed >= 3)
  assert_eq(@debug.to_string(doc.to_cmark()), original)
}

///|
test "code lines and table cells exported from views cannot change the document" {
  let doc = @mdc.parse(
    "```mbt\noriginal\n```\n\n| head |\n| --- |\n| cell |\n",
    strict=false,
  )
  let original = @debug.to_string(doc.to_cmark())
  let count = doc.fold(
    0,
    @mdc.Folder::Folder((count, node) => {
      match node {
        Block(view) =>
          match view.to_cmark() {
            CodeBlock({ v, .. }) => {
              v.code[0] = @cmark.Node::new("changed")
              Continue(count + 1)
            }
            ExtTable({ v, .. }) => {
              guard v.rows[0].0.v is (Header(cells) | Data(cells)) else {
                Continue(count)
              }
              cells[0] = (@cmark.Inline::empty(), cells[0].1)
              Continue(count + 1)
            }
            _ => Continue(count)
          }
        _ => Continue(count)
      }
    }),
  )
  assert_eq(count, 2)
  assert_eq(@debug.to_string(doc.to_cmark()), original)
}
