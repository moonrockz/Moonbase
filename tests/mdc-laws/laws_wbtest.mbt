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
fn label(node : @mdc.Node) -> String {
  match node {
    Document(_) => "document"
    Frontmatter(_) => "frontmatter"
    Block(view) => @debug.to_string((view.kind(), view.location()))
    Inline(view) => @debug.to_string((view.kind(), view.location()))
  }
}

///|
priv enum Event {
  Enter(String)
  Leave(String)
} derive(Eq, Debug)

///|
fn decide(policy : Array[UInt32], index : Int32) -> @mdc.Control {
  if policy.is_empty() {
    return Continue
  }
  match policy[index % policy.length()] % 3 {
    0 => Continue
    1 => SkipChildren
    _ => Stop
  }
}

///|
// A small recursive specification, independent of the production stack walker.
fn model(root : @mdc.Node, policy : Array[UInt32]) -> Array[Event] {
  let events = []
  let mut index = 0
  fn visit(node : @mdc.Node) -> Bool {
    events.push(Enter(label(node)))
    let action = decide(policy, index)
    index += 1
    match action {
      Stop => return false
      SkipChildren => ()
      Continue =>
        for child in node.children() {
          if !visit(child) {
            return false
          }
        }
    }
    events.push(Leave(label(node)))
    true
  }
  ignore(visit(root))
  events
}

///|
struct RecordingVisitor {
  events : Array[Event]
  policy : Array[UInt32]
  mut index : Int32
}

///|
fn RecordingVisitor::enter(
  self : RecordingVisitor,
  node : @mdc.Node,
) -> @mdc.Control {
  self.events.push(Enter(label(node)))
  let action = decide(self.policy, self.index)
  self.index += 1
  action
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_document(self, doc) {
  self.enter(@mdc.Node::Document(doc))
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_frontmatter(self, header) {
  self.enter(@mdc.Node::Frontmatter(header))
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_block(self, view) {
  self.enter(@mdc.Node::Block(view))
}

///|
impl @mdc.Visitor for RecordingVisitor with fn visit_inline(self, view) {
  self.enter(@mdc.Node::Inline(view))
}

///|
impl @mdc.Visitor for RecordingVisitor with fn leave(self, node) {
  self.events.push(Leave(label(node)))
}

///|
test "law: parsing preserves the body and its original source origin" {
  @expect.for_all(
    (input : DocumentCase) => {
      let doc = input.document()
      @expect.expect_all(s => {
        s.expect(doc.body(), label="body").to_equal(input.body())
        s
        .expect(doc.body_offset(), label="offset")
        .to_equal(input.prefix().length())
        s
        .expect(doc.body_line(), label="line")
        .to_equal(if input.with_header { 8 } else { 1 })
        s
        .expect(
          input.source()[doc.body_offset():].to_owned(),
          label="source suffix",
        )
        .to_equal(doc.body())
        s
        .expect(doc.frontmatter() is Some(_), label="header presence")
        .to_equal(input.with_header)
      })
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1001,
  )
}

///|
test "law: frontmatter exports and reconstruction preserve the same metadata" {
  @expect.for_all(
    (input : DocumentCase) => {
      let header = @mdc.Frontmatter::Frontmatter(input.payload())
      let expected : Json = {
        "title": Json(input.title()),
        "active": true,
        "count": Json(input.choices.length()),
        "steps": [{ "title": Json(input.title()) }],
      }
      guard header.value() is Map(fields) else { fail("not a mapping") }
      guard fields.get("steps") is Some(Array(steps)) else { fail("no steps") }
      guard steps[0] is Map(step) else { fail("no step") }
      step.clear()
      steps.clear()
      fields.clear()
      @expect.expect_all(s => {
        s.expect(header.raw()).to_equal(input.payload())
        s.expect(header.value().to_json()).to_equal(expected)
        s
        .expect(@mdc.Frontmatter::Frontmatter(header.raw()).value().to_json())
        .to_equal(expected)
      })
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1002,
  )
}

///|
test "law: cmark and view exports preserve observations and cannot change a document" {
  @expect.for_all(
    (input : DocumentCase) => {
      let doc = input.document()
      let original = @debug.to_string(doc.to_cmark())
      let exported = doc.to_cmark()
      let folder : @cmark.Folder[String] = @cmark.Folder::new(inline=(
        _,
        acc,
        inline,
      ) => {
        match inline {
          Text({ v, .. }) => Fold(acc + v)
          _ => Default
        }
      })
      let exported_text = folder.fold_doc("", exported)
      exported.defs.clear()
      if exported.block is Blocks({ v, .. }) && !v.is_empty() {
        v[0] = @cmark.Block::empty()
      }
      let observed = doc.fold(
        "",
        @mdc.Folder::Folder((text, node) => {
          match node {
            Block(view) =>
              if view.to_cmark() is Blocks({ v, .. }) && !v.is_empty() {
                v[0] = @cmark.Block::empty()
              }
            Inline(view) =>
              if view.to_cmark() is Inlines({ v, .. }) && !v.is_empty() {
                v[0] = @cmark.Inline::empty()
              }
            _ => ()
          }
          Continue(text + text_of(node))
        }),
      )
      @expect.expect_all(s => {
        s.expect(observed, label="traversal text").to_equal(exported_text)
        s
        .expect(
          @debug.to_string(doc.to_cmark()),
          label="document after export mutation",
        )
        .to_equal(original)
      })
    },
    count=150,
    max_size=16,
    max_shrinks=200,
    seed=1003,
  )
}

///|
test "law: walk, visitor and fold obey the recursive model for every control" {
  @expect.for_all(
    (input : (DocumentCase, Array[UInt32])) => {
      let (generated, random_policy) = input
      let doc = generated.document()
      // Explicit policies cover full descent, root pruning and immediate stop
      // even if a random policy stops before it reaches an interesting subtree.
      let policies : Array[Array[UInt32]] = [[], [1], [2], random_policy]
      for policy in policies {
        let expected = model(doc.root(), policy)
        let walked = []
        let mut index = 0
        @mdc.walk(
          doc.root(),
          node => {
            walked.push(Enter(label(node)))
            let action = decide(policy, index)
            index += 1
            action
          },
          leave=node => walked.push(Leave(label(node))),
        )
        let visitor = RecordingVisitor::{ events: [], policy, index: 0, }
        doc.accept(visitor)
        let mut fold_index = 0
        let folded = doc.fold(
          [],
          @mdc.Folder::Folder((events, node) => {
            events.push(label(node))
            let action = decide(policy, fold_index)
            fold_index += 1
            match action {
              Continue => Continue(events)
              SkipChildren => SkipChildren(events)
              Stop => Stop(events)
            }
          }),
        )
        let entered = expected.filter_map(event => {
          match event {
            Enter(value) => Some(value)
            Leave(_) => None
          }
        })
        @expect.expect_all(s => {
          s.expect(walked, label="walk events").to_equal(expected)
          s.expect(visitor.events, label="visitor events").to_equal(expected)
          s
          .expect(folded, label="fold updates, including stop")
          .to_equal(entered)
        })
      }
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1004,
  )
}

///|
test "law: a fold that preserves its accumulator is an identity" {
  @expect.for_all(
    (input : (DocumentCase, Int32)) => {
      let (generated, initial) = input
      let doc = generated.document()
      let result = doc.fold(
        initial,
        @mdc.Folder::Folder((value, _) => Continue(value)),
      )
      @expect.expect(result).to_equal(initial)
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1005,
  )
}

///|
test "law: frontmatter changes do not change Markdown traversal" {
  @expect.for_all(
    (input : DocumentCase) => {
      let with_header = DocumentCase::{ ..input, with_header: true, }.document()
      let without_header = DocumentCase::{ ..input, with_header: false, }.document()
      fn markdown_events(doc : @mdc.Document) -> Array[String] {
        doc.fold(
          [],
          @mdc.Folder::Folder((events, node) => {
            match node {
              Document(_) | Frontmatter(_) => ()
              Block(_) | Inline(_) => events.push(label(node))
            }
            Continue(events)
          }),
        )
      }
      @expect.expect(markdown_events(with_header)).to_equal(
        markdown_events(without_header),
      )
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1006,
  )
}
