///|
// A reusable, generic decorator. Its trait implementations retain the wrapped
// domain type without requiring a generic trait or shared mutable state.
priv struct Tracked[A] {
  value : A
  count : Int32
}

///|
impl[A : @mdc.Fold] @mdc.Fold for Tracked[A] with fn enter(self, node) {
  match @mdc.Fold::enter(self.value, node) {
    Continue(value) => Continue({ value, count: self.count + 1, })
    SkipChildren(value) => SkipChildren({ value, count: self.count + 1, })
    Stop(value) => Stop({ value, count: self.count + 1, })
  }
}

///|
impl[A : @mdc.CursorFold] @mdc.CursorFold for Tracked[A] with fn enter(
  self,
  cursor,
) {
  match @mdc.CursorFold::enter(self.value, cursor) {
    Continue(value) => Continue({ value, count: self.count + 1, })
    SkipChildren(value) => SkipChildren({ value, count: self.count + 1, })
    Stop(value) => Stop({ value, count: self.count + 1, })
  }
}

///|
impl[A : @mdc.Reducer] @mdc.Reducer for Tracked[A] with fn reduce(
  node,
  children,
) {
  {
    value: @mdc.Reducer::reduce(node, children.map(child => child.value)),
    count: 1 + children.fold(init=0, (sum, child) => sum + child.count),
  }
}

///|
impl[A : @mdc.CursorReducer] @mdc.CursorReducer for Tracked[A] with fn reduce(
  cursor,
  children,
) {
  {
    value: @mdc.CursorReducer::reduce(
      cursor,
      children.map(child => child.value),
    ),
    count: 1 + children.fold(init=0, (sum, child) => sum + child.count),
  }
}

///|
priv struct PolicyState {
  policy : ReadOnlyArray[UInt32]
  log : String
  index : Int32
}

///|
fn PolicyState::advance(
  self : PolicyState,
  item : String,
) -> @mdc.FoldAction[PolicyState] {
  let next = { ..self, log: self.log + item + "\n", index: self.index + 1, }
  let action = if self.policy.is_empty() {
    0U
  } else {
    self.policy[self.index % self.policy.length()] % 3U
  }
  match action {
    0 => Continue(next)
    1 => SkipChildren(next)
    _ => Stop(next)
  }
}

///|
impl @mdc.Fold for PolicyState with fn enter(self, node) {
  self.advance(label(node))
}

///|
impl @mdc.CursorFold for PolicyState with fn enter(self, cursor) {
  self.advance(cursor.path().to_string() + ":" + label(cursor.node()))
}

///|
priv struct Rendered {
  text : String
}

///|
impl @mdc.Reducer for Rendered with fn reduce(node, children) {
  {
    text: label(node) + "(" + children.map(child => child.text).join(",") + ")",
  }
}

///|
impl @mdc.CursorReducer for Rendered with fn reduce(cursor, children) {
  {
    text: cursor.path().to_string() +
    ":" +
    label(cursor.node()) +
    "(" +
    children.map(child => child.text).join(",") +
    ")",
  }
}

///|
test "law: generic trait folds preserve control and agree with closures and the model" {
  @expect.for_all(
    (input : (DocumentCase, Array[UInt32])) => {
      let (generated, random_policy) = input
      let doc = generated.document()
      for policy in [[], [1U], [2U], random_policy] {
        let init = Tracked::{
          value: PolicyState::{
            policy: ReadOnlyArray::from_array(policy[:]),
            log: "",
            index: 0,
          },
          count: 0,
        }
        let folded = @mdc.fold_with(doc.root(), init)
        let adapted = doc.fold(init, @mdc.Folder::from_trait())
        let positioned = @mdc.fold_cursor_with(doc.root(), init)
        let cursor_adapted = doc.fold(init, @mdc.Folder::from_cursor_trait())
        let closure = doc.fold(
          init,
          @mdc.Folder::Folder((acc, node) => @mdc.Fold::enter(acc, node)),
        )
        let expected = model(doc.root(), policy)
          .filter_map(event => {
            match event {
              Enter(node) => Some(node + "\n")
              Leave(_) => None
            }
          })
          .join("")
        let positions = position_model(doc.root(), policy)
          .filter_map(event => {
            match event {
              At(path~, node~) => Some(path + ":" + node + "\n")
              After(_) => None
            }
          })
          .join("")
        @expect.expect_all(s => {
          s.expect(folded.value.log).to_equal(expected)
          s.expect(adapted.value.log).to_equal(expected)
          s.expect(closure.value.log).to_equal(expected)
          s.expect(doc.fold_with(init).value.log).to_equal(expected)
          s.expect(doc.root().fold_with(init).value.log).to_equal(expected)
          s.expect(positioned.value.log).to_equal(positions)
          s.expect(cursor_adapted.value.log).to_equal(positions)
          s.expect(doc.fold_cursor_with(init).value.log).to_equal(positions)
          s
          .expect(doc.root().fold_cursor_with(init).value.log)
          .to_equal(positions)
          s.expect(folded.count).to_equal(folded.value.index)
          s.expect(positioned.count).to_equal(folded.count)
          s.expect(init.count, label="original generic state").to_equal(0)
          s.expect(init.value.log).to_equal("")
        })
      }
    },
    count=200,
    max_size=16,
    max_shrinks=200,
    seed=1012,
  )
}

///|
test "law: generic trait reducers preserve child grouping, order and cursor context" {
  @expect.for_all(
    (input : DocumentCase) => {
      let doc = input.document()
      let result : Tracked[Rendered] = @mdc.reduce_with(doc.root())
      let document_result : Tracked[Rendered] = doc.reduce_with()
      let node_result : Tracked[Rendered] = doc.root().reduce_with()
      let positions = []
      @mdc.walk_cursor(doc.root(), cursor => {
        positions.push(cursor)
        Continue
      })
      let index = (input.style % positions.length().reinterpret_as_uint()).reinterpret_as_int()
      let saved = positions[index]
      let original = saved.path()
      let positioned : Tracked[Rendered] = saved.reduce_with()
      let expected = saved.reduce((cursor, children : ReadOnlyArray[String]) => {
        cursor.path().to_string() +
        ":" +
        label(cursor.node()) +
        "(" +
        children.join(",") +
        ")"
      })
      let subtree_fold = saved.fold_with(Tracked::{
        value: PolicyState::{ policy: [], log: "", index: 0, },
        count: 0,
      })
      let top_level : Tracked[Rendered] = @mdc.reduce_cursor_with(doc.root())
      let from_document : Tracked[Rendered] = doc.reduce_cursor_with()
      let from_node : Tracked[Rendered] = doc.root().reduce_cursor_with()
      @expect.expect_all(s => {
        s.expect(result.value.text).to_equal(reduce_model(doc.root()))
        s.expect(document_result.value.text).to_equal(result.value.text)
        s.expect(node_result.value.text).to_equal(result.value.text)
        s.expect(result.count).to_equal(positions.length())
        s.expect(positioned.value.text).to_equal(expected)
        s.expect(positioned.count).to_equal(subtree_fold.count)
        s
        .expect(subtree_fold.value.log)
        .to_equal(
          saved.fold(
            "",
            @mdc.Folder::with_cursor((log, cursor) => {
              Continue(
                log +
                cursor.path().to_string() +
                ":" +
                label(cursor.node()) +
                "\n",
              )
            }),
          ),
        )
        s.expect(from_document.value.text).to_equal(top_level.value.text)
        s.expect(from_node.value.text).to_equal(top_level.value.text)
        s.expect(saved.path()).to_equal(original)
      })
    },
    count=150,
    max_size=12,
    max_shrinks=200,
    seed=1013,
  )
}
