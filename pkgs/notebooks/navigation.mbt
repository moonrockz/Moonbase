///|
/// Common classifications retain each format's concrete node values.
pub(all) enum CellKind {
  Code
  Markdown
  Raw
  Unknown(String)
} derive(Eq, Debug)

///|
pub extend CellKind with Eq::{equal, not_equal}

///|
pub extend CellKind with @debug.Debug::{to_repr}

///|
pub(all) enum NodeKind {
  Notebook
  Cell(CellKind)
  Output(String)
  Attachment(String)
  Directive(String)
} derive(Eq, Debug)

///|
pub extend NodeKind with Eq::{equal, not_equal}

///|
pub extend NodeKind with @debug.Debug::{to_repr}

///|
/// Implement for a stable immutable notebook tree with ordered children.
/// The concrete Self type retains all format-specific payloads.
pub(open) trait Node {
  fn children(Self) -> ReadOnlyArray[Self]
  fn kind(Self) -> NodeKind
  fn source(Self) -> String? = _
}

///|
impl Node with fn source(_self) {
  None
}

///|
struct NodePath {
  indices : ReadOnlyArray[Int32]
} derive(Eq, Debug)

///|
pub extend NodePath with Eq::{equal, not_equal}

///|
pub extend NodePath with @debug.Debug::{to_repr}

///|
/// Paths are relative to a root. Out-of-range paths resolve to None.
pub fn NodePath::NodePath(indices : ReadOnlyArray[Int32]) -> NodePath {
  { indices, }
}

///|
pub fn NodePath::indices(self : NodePath) -> ReadOnlyArray[Int32] {
  self.indices
}

///|
pub fn NodePath::to_string(self : NodePath) -> String {
  "$" + self.indices.map(index => "[\{index}]").join("")
}

///|
pub fn[N : Node] at(root : N, path : NodePath) -> N? {
  let mut current = root
  for index in path.indices {
    guard current.children().get(index) is Some(child) else { return None }
    current = child
  }
  Some(current)
}

///|
priv enum CursorContext[N] {
  Root
  Child(parent~ : Cursor[N], siblings~ : ReadOnlyArray[N], index~ : Int32)
}

///|
/// Moves return new positions. Retaining a cursor saves its entire context.
struct Cursor[N] {
  node : N
  context : CursorContext[N]
  depth : Int32
}

///|
pub fn[N] Cursor::Cursor(root : N) -> Cursor[N] {
  { node: root, context: Root, depth: 0, }
}

///|
pub fn[N] Cursor::node(self : Cursor[N]) -> N {
  self.node
}

///|
pub fn[N] Cursor::depth(self : Cursor[N]) -> Int32 {
  self.depth
}

///|
pub fn[N] Cursor::path(self : Cursor[N]) -> NodePath {
  let indices = []
  let mut current = self
  while current.context is Child(parent~, index~, ..) {
    indices.push(index)
    current = parent
  }
  { indices: ReadOnlyArray::from_iter(indices.rev_iter()), }
}

///|
pub fn[N] Cursor::parent(self : Cursor[N]) -> Cursor[N]? {
  match self.context {
    Root => None
    Child(parent~, ..) => Some(parent)
  }
}

///|
fn[N] Cursor::child_at(
  self : Cursor[N],
  siblings : ReadOnlyArray[N],
  index : Int32,
) -> Cursor[N] {
  {
    node: siblings[index],
    context: Child(parent=self, siblings~, index~),
    depth: self.depth + 1,
  }
}

///|
pub fn[N : Node] Cursor::first_child(self : Cursor[N]) -> Cursor[N]? {
  let children = self.node.children()
  if children.is_empty() {
    None
  } else {
    Some(self.child_at(children, 0))
  }
}

///|
pub fn[N : Node] Cursor::last_child(self : Cursor[N]) -> Cursor[N]? {
  let children = self.node.children()
  if children.is_empty() {
    None
  } else {
    Some(self.child_at(children, children.length() - 1))
  }
}

///|
pub fn[N] Cursor::next_sibling(self : Cursor[N]) -> Cursor[N]? {
  match self.context {
    Child(parent~, siblings~, index~) if index + 1 < siblings.length() =>
      Some(parent.child_at(siblings, index + 1))
    _ => None
  }
}

///|
pub fn[N] Cursor::previous_sibling(self : Cursor[N]) -> Cursor[N]? {
  match self.context {
    Child(parent~, siblings~, index~) if index > 0 =>
      Some(parent.child_at(siblings, index - 1))
    _ => None
  }
}

///|
pub fn[N : Node] Cursor::children(self : Cursor[N]) -> ReadOnlyArray[Cursor[N]] {
  let children = self.node.children()
  children.mapi((i, _) => self.child_at(children, i))
}

///|
pub(all) enum Control {
  Continue
  SkipChildren
  Stop
} derive(Eq, Debug)

///|
pub extend Control with Eq::{equal, not_equal}

///|
pub extend Control with @debug.Debug::{to_repr}

///|
priv enum WalkFrame[N] {
  Enter(Cursor[N])
  Leave(Cursor[N])
}

///|
/// Depth-first traversal. Skipped nodes receive leave; Stop ends immediately.
pub fn[N : Node] Cursor::walk(
  self : Cursor[N],
  enter : (Cursor[N]) -> Control,
  leave~ : (Cursor[N]) -> Unit = _ => (),
) -> Unit {
  let pending = [WalkFrame::Enter(self)]
  while pending.pop() is Some(frame) {
    match frame {
      Leave(cursor) => leave(cursor)
      Enter(cursor) =>
        match enter(cursor) {
          Stop => return
          SkipChildren => leave(cursor)
          Continue => {
            pending.push(Leave(cursor))
            let children = cursor.children()
            for i = children.length() - 1; i >= 0; i = i - 1 {
              pending.push(Enter(children[i]))
            }
          }
        }
    }
  }
}

///|
pub fn[N : Node] walk_cursor(
  root : N,
  enter : (Cursor[N]) -> Control,
  leave~ : (Cursor[N]) -> Unit = _ => (),
) -> Unit {
  Cursor::Cursor(root).walk(enter, leave~)
}

///|
pub fn[N : Node] walk(
  root : N,
  enter : (N) -> Control,
  leave~ : (N) -> Unit = _ => (),
) -> Unit {
  walk_cursor(root, cursor => enter(cursor.node()), leave=cursor => {
    leave(cursor.node())
  })
}

///|
/// Fold in pre-order with the original cursor context.
pub fn[N : Node, A] Cursor::fold(
  self : Cursor[N],
  init : A,
  f : (A, Cursor[N]) -> A,
) -> A {
  let mut acc = init
  self.walk(cursor => {
    acc = f(acc, cursor)
    Continue
  })
  acc
}

///|
pub fn[N : Node, A] fold(root : N, init : A, f : (A, Cursor[N]) -> A) -> A {
  Cursor::Cursor(root).fold(init, f)
}
