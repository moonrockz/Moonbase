///|
priv enum PositionEvent {
  At(path~ : String, node~ : String)
  After(path~ : String, node~ : String)
} derive(Eq, Debug)

///|
// Independent recursive specification of paths and callback order.
fn position_model(
  root : @mdc.Node,
  policy : Array[UInt32],
) -> Array[PositionEvent] {
  let events = []
  let mut index = 0
  fn visit(node : @mdc.Node, path : String) -> Bool {
    events.push(At(path~, node=label(node)))
    let action = decide(policy, index)
    index += 1
    match action {
      Stop => return false
      SkipChildren => ()
      Continue =>
        for child_index, child in node.children() {
          if !visit(child, path + "[\{child_index}]") {
            return false
          }
        }
    }
    events.push(After(path~, node=label(node)))
    true
  }
  ignore(visit(root, "$"))
  events
}

///|
struct PositionVisitor {
  events : Array[PositionEvent]
  policy : Array[UInt32]
  mut index : Int32
}

///|
fn PositionVisitor::enter(
  self : PositionVisitor,
  cursor : @mdc.Cursor,
) -> @mdc.Control {
  self.events.push(
    At(path=cursor.path().to_string(), node=label(cursor.node())),
  )
  let action = decide(self.policy, self.index)
  self.index += 1
  action
}

///|
impl @mdc.CursorVisitor for PositionVisitor with fn visit_document(self, cursor) {
  self.enter(cursor)
}

///|
impl @mdc.CursorVisitor for PositionVisitor with fn visit_frontmatter(
  self,
  cursor,
) {
  self.enter(cursor)
}

///|
impl @mdc.CursorVisitor for PositionVisitor with fn visit_block(self, cursor) {
  self.enter(cursor)
}

///|
impl @mdc.CursorVisitor for PositionVisitor with fn visit_inline(self, cursor) {
  self.enter(cursor)
}

///|
impl @mdc.CursorVisitor for PositionVisitor with fn leave(self, cursor) {
  self.events.push(
    After(path=cursor.path().to_string(), node=label(cursor.node())),
  )
}

///|
test "law: cursor navigation round trips and saved positions resolve from the root" {
  @expect.for_all(
    (input : DocumentCase) => {
      let doc = input.document()
      let saved = []
      @mdc.walk_cursor(doc.root(), cursor => {
        saved.push(cursor)
        Continue
      })
      for cursor in saved {
        let path = cursor.path()
        let node = cursor.node()
        guard doc.root().at(path) is Some(resolved) else {
          fail("path did not resolve")
        }
        @expect.expect_all(s => {
          s.expect(label(resolved), label="resolved node").to_equal(label(node))
          s
          .expect(path.indices().length(), label="path depth")
          .to_equal(cursor.depth())
          s
          .expect(cursor.children().length())
          .to_equal(node.children().length())
        })
        if cursor.first_child() is Some(first) {
          guard first.parent() is Some(parent) else {
            fail("child has no parent")
          }
          @expect.expect_all(s => {
            s.expect(parent.path()).to_equal(path)
            s.expect(first.depth()).to_equal(cursor.depth() + 1)
            s.expect(first.previous_sibling()).to_be_none()
          })
        } else {
          @expect.expect_all(s => {
            s.expect(node.children().length()).to_equal(0)
            s.expect(cursor.last_child()).to_be_none()
          })
        }
        if cursor.last_child() is Some(last) {
          @expect.expect(last.next_sibling()).to_be_none()
        }
        if cursor.next_sibling() is Some(next) {
          guard next.previous_sibling() is Some(back) else {
            fail("no previous sibling")
          }
          @expect.expect(back.path()).to_equal(path)
        }
        if cursor.previous_sibling() is Some(previous) {
          guard previous.next_sibling() is Some(back) else {
            fail("no next sibling")
          }
          @expect.expect(back.path()).to_equal(path)
        }
        if cursor.parent() is Some(parent) {
          @expect.expect(parent.depth()).to_equal(cursor.depth() - 1)
        } else {
          @expect.expect(cursor.depth()).to_equal(0)
        }
        // All navigation above must leave the saved position untouched.
        @expect.expect(cursor.path()).to_equal(path)
      }
      let expected = position_model(doc.root(), []).filter_map(event => {
        match event {
          At(path~, node~) => Some((path, node))
          After(_) => None
        }
      })
      @expect.expect(
        saved.map(cursor => (cursor.path().to_string(), label(cursor.node()))),
      ).to_equal(expected)
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1007,
  )
}

///|
test "law: cursor visitors, folders and walks agree with positioned control semantics" {
  @expect.for_all(
    (input : (DocumentCase, Array[UInt32])) => {
      let (generated, random_policy) = input
      let doc = generated.document()
      let policies : Array[Array[UInt32]] = [[], [1], [2], random_policy]
      for policy in policies {
        let expected = position_model(doc.root(), policy)
        let walked = []
        let mut index = 0
        @mdc.walk_cursor(
          doc.root(),
          cursor => {
            walked.push(
              At(path=cursor.path().to_string(), node=label(cursor.node())),
            )
            let action = decide(policy, index)
            index += 1
            // Explore from a callback without steering the outer traversal.
            ignore(cursor.parent().map(parent => parent.last_child()))
            ignore(cursor.first_child())
            action
          },
          leave=cursor => {
            walked.push(
              After(path=cursor.path().to_string(), node=label(cursor.node())),
            )
          },
        )
        let visitor = PositionVisitor::{ events: [], policy, index: 0, }
        doc.accept_cursor(visitor)
        let mut fold_index = 0
        let folded = doc.fold(
          [],
          @mdc.Folder::with_cursor((events, cursor) => {
            events.push(
              At(path=cursor.path().to_string(), node=label(cursor.node())),
            )
            let action = decide(policy, fold_index)
            fold_index += 1
            match action {
              Continue => Continue(events)
              SkipChildren => SkipChildren(events)
              Stop => Stop(events)
            }
          }),
        )
        @expect.expect_all(s => {
          s.expect(walked, label="cursor walk").to_equal(expected)
          s.expect(visitor.events, label="cursor visitor").to_equal(expected)
          s
          .expect(folded, label="cursor folder")
          .to_equal(expected.filter(event => event is At(_)))
        })
      }
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1008,
  )
}

///|
fn reduce_model(node : @mdc.Node) -> String {
  let children = node.children().map(reduce_model)
  label(node) + "(" + children.join(",") + ")"
}

///|
test "law: reduce matches structural reduction and invokes callbacks in postorder" {
  @expect.for_all(
    (input : DocumentCase) => {
      let doc = input.document()
      let callbacks = []
      let result = doc.reduce((node, children) => {
        callbacks.push(label(node))
        label(node) + "(" + children.join(",") + ")"
      })
      let expected_order = model(doc.root(), []).filter_map(event => {
        match event {
          Event::Leave(node) => Some(node)
          Event::Enter(_) => None
        }
      })
      let cursor_callbacks = []
      let positioned = doc.reduce_cursor((cursor, children) => {
        cursor_callbacks.push(
          After(path=cursor.path().to_string(), node=label(cursor.node())),
        )
        label(cursor.node()) + "(" + children.join(",") + ")"
      })
      @expect.expect_all(s => {
        s
        .expect(result, label="structural result")
        .to_equal(reduce_model(doc.root()))
        s.expect(positioned, label="cursor result").to_equal(result)
        s
        .expect(callbacks, label="node callback order")
        .to_equal(expected_order)
        s
        .expect(cursor_callbacks, label="cursor callback order")
        .to_equal(
          position_model(doc.root(), []).filter(event => event is After(_)),
        )
      })
    },
    count=150,
    max_size=10,
    max_shrinks=200,
    seed=1009,
  )
}

///|
test "law: reduced node count and height equal traversal observations" {
  @expect.for_all(
    (input : DocumentCase) => {
      let doc = input.document()
      let (count, height) = doc.reduce((
        _,
        children : ReadOnlyArray[(Int32, Int32)],
      ) => {
        let count = 1 + children.fold(init=0, (sum, child) => sum + child.0)
        let height = 1 +
          children.fold(init=0, (maximum, child) => {
            if child.1 > maximum {
              child.1
            } else {
              maximum
            }
          })
        (count, height)
      })
      let (entered, deepest) = doc.fold(
        (0, 0),
        @mdc.Folder::with_cursor((acc, cursor) => {
          let depth = cursor.depth() + 1
          Continue((acc.0 + 1, if depth > acc.1 { depth } else { acc.1 }))
        }),
      )
      @expect.expect_all(s => {
        s.expect(count).to_equal(entered)
        s.expect(height).to_equal(deepest)
      })
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1010,
  )
}

///|
test "law: subtree cursor operations preserve ancestors while node operations rebase" {
  @expect.for_all(
    (input : DocumentCase) => {
      let doc = input.document()
      let positions = []
      @mdc.walk_cursor(doc.root(), cursor => {
        positions.push(cursor)
        Continue
      })
      let index = (input.style % positions.length().reinterpret_as_uint()).reinterpret_as_int()
      let saved = positions[index]
      let original_path = saved.path()
      let paths = saved.fold(
        [],
        @mdc.Folder::with_cursor((paths, cursor) => {
          paths.push(cursor.path().to_string())
          Continue(paths)
        }),
      )
      let result = saved.reduce((
        cursor,
        children : ReadOnlyArray[(@mdc.NodePath, Int32)],
      ) => {
        (
          cursor.path(),
          1 + children.fold(init=0, (sum, child) => sum + child.1),
        )
      })
      let rebased = @mdc.reduce_cursor(saved.node(), (
        cursor,
        children : ReadOnlyArray[(String, Int32)],
      ) => {
        (
          cursor.path().to_string(),
          1 + children.fold(init=0, (sum, child) => sum + child.1),
        )
      })
      let visitor = PositionVisitor::{ events: [], policy: [], index: 0, }
      saved.accept(visitor)
      let visited_paths = visitor.events.filter_map(event => {
        match event {
          At(path~, ..) => Some(path)
          After(_) => None
        }
      })
      @expect.expect_all(s => {
        s.expect(paths.get(0)).to_equal(Some(original_path.to_string()))
        s.expect(visited_paths).to_equal(paths)
        s.expect(result.0).to_equal(original_path)
        s.expect(result.1).to_equal(paths.length())
        s.expect(rebased.0).to_equal("$")
        s.expect(rebased.1).to_equal(result.1)
        s.expect(saved.path(), label="saved cursor").to_equal(original_path)
      })
    },
    count=150,
    max_size=16,
    max_shrinks=200,
    seed=1011,
  )
}
