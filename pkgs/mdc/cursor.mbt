///|
/// A path of child indices, relative to the cursor's starting node.
/// Paths describe MDC traversal children, including layout nodes.
struct NodePath {
  indices : ReadOnlyArray[Int32]
} derive(Eq, Debug)

///|
pub extend NodePath with Eq::{equal, not_equal}

///|
pub extend NodePath with @debug.Debug::{to_repr}

///|
pub fn NodePath::indices(self : NodePath) -> ReadOnlyArray[Int32] {
  self.indices
}

///|
pub fn NodePath::to_string(self : NodePath) -> String {
  "$" + self.indices.map(index => "[\{index}]").join("")
}

///|
pub impl Show for NodePath with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub extend NodePath with Show::{output}

///|
priv enum CursorContext {
  Root
  Child(parent~ : Cursor, siblings~ : ReadOnlyArray[Node], index~ : Int32)
}

///|
/// An immutable navigation position. Moves return new positions, or `None`
/// at a boundary. Keeping a position saves it; no copy or restore is needed.
/// Parent navigation never goes above the node supplied to the constructor.
struct Cursor {
  node : Node
  context : CursorContext
  depth : Int32
}

///|
pub impl @debug.Debug for Cursor with fn to_repr(self) {
  @debug.Repr((self.path(), self.depth))
}

///|
pub extend Cursor with @debug.Debug::{to_repr}

///|
pub fn Cursor::Cursor(root : Node) -> Cursor {
  { node: root, context: Root, depth: 0, }
}

///|
pub fn Document::cursor(self : Document) -> Cursor {
  Cursor::Cursor(self.root())
}

///|
pub fn Node::cursor(self : Node) -> Cursor {
  Cursor::Cursor(self)
}

///|
pub fn Cursor::node(self : Cursor) -> Node {
  self.node
}

///|
pub fn Cursor::depth(self : Cursor) -> Int32 {
  self.depth
}

///|
/// Construct the path on demand, without copying ancestors during navigation.
pub fn Cursor::path(self : Cursor) -> NodePath {
  let indices = []
  let mut current = self
  while current.context is Child(parent~, index~, ..) {
    indices.push(index)
    current = parent
  }
  { indices: ReadOnlyArray::from_iter(indices.rev_iter()), }
}

///|
pub fn Cursor::parent(self : Cursor) -> Cursor? {
  match self.context {
    Root => None
    Child(parent~, ..) => Some(parent)
  }
}

///|
fn Cursor::child_at(
  self : Cursor,
  siblings : ReadOnlyArray[Node],
  index : Int32,
) -> Cursor {
  {
    node: siblings[index],
    context: Child(parent=self, siblings~, index~),
    depth: self.depth + 1,
  }
}

///|
pub fn Cursor::first_child(self : Cursor) -> Cursor? {
  let children = self.node.children()
  if children.is_empty() {
    None
  } else {
    Some(self.child_at(children, 0))
  }
}

///|
pub fn Cursor::last_child(self : Cursor) -> Cursor? {
  let children = self.node.children()
  if children.is_empty() {
    None
  } else {
    Some(self.child_at(children, children.length() - 1))
  }
}

///|
pub fn Cursor::next_sibling(self : Cursor) -> Cursor? {
  match self.context {
    Child(parent~, siblings~, index~) if index + 1 < siblings.length() =>
      Some(parent.child_at(siblings, index + 1))
    Root | Child(_) => None
  }
}

///|
pub fn Cursor::previous_sibling(self : Cursor) -> Cursor? {
  match self.context {
    Child(parent~, siblings~, index~) if index > 0 =>
      Some(parent.child_at(siblings, index - 1))
    Root | Child(_) => None
  }
}

///|
pub fn Cursor::children(self : Cursor) -> ReadOnlyArray[Cursor] {
  let siblings = self.node.children()
  siblings.mapi((index, _) => self.child_at(siblings, index))
}

///|
/// Resolve a path relative to this node. A path from another tree may not exist.
pub fn Node::at(self : Node, path : NodePath) -> Node? {
  let mut current = self
  for index in path.indices {
    guard current.children().get(index) is Some(child) else { return None }
    current = child
  }
  Some(current)
}
