///|
/// The notebook tree contains cells, their outputs, and named attachments.
/// Metadata and MIME values are accessed through their immutable objects.
pub(all) enum Node {
  Notebook(Notebook)
  Cell(Cell)
  Output(Output)
  Attachment(name~ : String, data~ : MimeBundle)
} derive(Eq, Debug)

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub fn Notebook::root(self : Notebook) -> Node {
  Notebook(self)
}

///|
/// Cells and outputs retain document order. Attachments use filename order.
pub fn Node::children(self : Node) -> ReadOnlyArray[Node] {
  match self {
    Notebook(book) => book.cells.map(cell => Node::Cell(cell))
    Cell(cell) =>
      match cell.content {
        Code(outputs~, ..) => outputs.map(output => Node::Output(output))
        Markdown(attachments=Some(attachments), ..)
        | Raw(attachments=Some(attachments), ..) =>
          attachments.entries.map(entry => {
            Attachment(name=entry.0, data=entry.1)
          })
        _ => []
      }
    Output(_) | Attachment(_) => []
  }
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
pub fn Node::at(self : Node, path : NodePath) -> Node? {
  let mut current = self
  for index in path.indices {
    guard current.children().get(index) is Some(child) else { return None }
    current = child
  }
  Some(current)
}

///|
priv enum CursorContext {
  Root
  Child(parent~ : Cursor, siblings~ : ReadOnlyArray[Node], index~ : Int32)
}

///|
/// Moves return new positions. Retaining a cursor saves its entire context.
struct Cursor {
  node : Node
  context : CursorContext
  depth : Int32
}

///|
pub fn Cursor::Cursor(root : Node) -> Cursor {
  { node: root, context: Root, depth: 0, }
}

///|
pub fn Notebook::cursor(self : Notebook) -> Cursor {
  Cursor(self.root())
}

///|
pub fn Node::cursor(self : Node) -> Cursor {
  Cursor(self)
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
    _ => None
  }
}

///|
pub fn Cursor::previous_sibling(self : Cursor) -> Cursor? {
  match self.context {
    Child(parent~, siblings~, index~) if index > 0 =>
      Some(parent.child_at(siblings, index - 1))
    _ => None
  }
}

///|
pub fn Cursor::children(self : Cursor) -> ReadOnlyArray[Cursor] {
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
priv enum WalkFrame {
  Enter(Cursor)
  Leave(Cursor)
}

///|
/// Depth-first traversal. Skipped nodes receive leave; Stop ends immediately.
pub fn Cursor::walk(
  self : Cursor,
  enter : (Cursor) -> Control,
  leave~ : (Cursor) -> Unit = _ => (),
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
pub fn walk_cursor(
  root : Node,
  enter : (Cursor) -> Control,
  leave~ : (Cursor) -> Unit = _ => (),
) -> Unit {
  root.cursor().walk(enter, leave~)
}

///|
pub fn walk(
  root : Node,
  enter : (Node) -> Control,
  leave~ : (Node) -> Unit = _ => (),
) -> Unit {
  walk_cursor(root, cursor => enter(cursor.node()), leave=cursor => {
    leave(cursor.node())
  })
}

///|
pub fn[A] Notebook::fold(self : Notebook, init : A, f : (A, Cursor) -> A) -> A {
  let mut acc = init
  self
  .cursor()
  .walk(cursor => {
    acc = f(acc, cursor)
    Continue
  })
  acc
}
