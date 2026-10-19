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
pub using @notebooks {type Cursor, type NodePath, type Control}

///|
pub fn Node::kind(self : Node) -> @notebooks.NodeKind {
  match self {
    Notebook(_) => @notebooks.NodeKind::Notebook
    Cell(cell) =>
      @notebooks.NodeKind::Cell(
        match cell.content {
          Code(_) => @notebooks.Code
          Markdown(_) => @notebooks.Markdown
          Raw(_) => @notebooks.Raw
          Unknown(cell_type~, ..) => @notebooks.Unknown(cell_type)
        },
      )
    Output(output) => @notebooks.NodeKind::Output(output.output_type())
    Attachment(name~, ..) => @notebooks.NodeKind::Attachment(name)
  }
}

///|
pub fn Node::source(self : Node) -> String? {
  match self {
    Cell(cell) => cell.source()
    _ => None
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
