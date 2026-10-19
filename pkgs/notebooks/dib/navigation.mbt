///|
pub using @notebooks {type Cursor, type NodePath, type Control}

///|
pub(all) enum Node {
  Notebook(Notebook)
  Cell(Cell)
  Directive(Directive)
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
pub fn Node::children(self : Node) -> ReadOnlyArray[Node] {
  match self {
    Notebook(book) => book.cells.map(cell => Node::Cell(cell))
    Cell(cell) => cell.directives().map(directive => Node::Directive(directive))
    Directive(_) => []
  }
}

///|
pub fn Node::kind(self : Node) -> @notebooks.NodeKind {
  match self {
    Notebook(_) => @notebooks.NodeKind::Notebook
    Cell(cell) => @notebooks.NodeKind::Cell(cell.kind())
    Directive(directive) => @notebooks.NodeKind::Directive(directive.name)
  }
}

///|
pub fn Node::source(self : Node) -> String? {
  match self {
    Notebook(_) => None
    Cell(cell) => Some(cell.source)
    Directive(directive) => Some(directive.text)
  }
}

///|
pub impl @notebooks.Node for Node with fn children(self) {
  self.children()
}

///|
pub impl @notebooks.Node for Node with fn kind(self) {
  self.kind()
}

///|
pub impl @notebooks.Node for Node with fn source(self) {
  self.source()
}

///|
pub fn Notebook::cursor(self : Notebook) -> Cursor[Node] {
  Cursor::Cursor(self.root())
}

///|
pub fn Node::cursor(self : Node) -> Cursor[Node] {
  Cursor::Cursor(self)
}

///|
pub fn Node::at(self : Node, path : NodePath) -> Node? {
  @notebooks.at(self, path)
}

///|
pub fn walk_cursor(
  root : Node,
  enter : (Cursor[Node]) -> Control,
  leave~ : (Cursor[Node]) -> Unit = _ => (),
) -> Unit {
  @notebooks.walk_cursor(root, enter, leave~)
}

///|
pub fn walk(
  root : Node,
  enter : (Node) -> Control,
  leave~ : (Node) -> Unit = _ => (),
) -> Unit {
  @notebooks.walk(root, enter, leave~)
}

///|
pub fn[A] Notebook::fold(
  self : Notebook,
  init : A,
  f : (A, Cursor[Node]) -> A,
) -> A {
  @notebooks.fold(self.root(), init, f)
}

///|
/// Resolve aliases before selecting cells. Markdown is a pseudo-kernel.
pub fn Notebook::cells_for_kernel(
  self : Notebook,
  name : String,
) -> ReadOnlyArray[Cell] {
  guard self.registry.resolve(name) is Some(kernel) else { return [] }
  ReadOnlyArray::from_iter(
    self.cells.iter().filter(cell => cell.kernel == kernel),
  )
}
