///|
/// Immutable nodes visited in document order. Obtain a root from `doc.root()`.
pub(all) enum Node {
  Document(Document)
  Frontmatter(Frontmatter)
  Block(BlockView)
  Inline(InlineView)
} derive(Debug)

///|
pub extend Node with @debug.Debug::{to_repr}

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
/// Direct children, in source order. Frontmatter is a leaf containing YAML.
pub fn Node::children(self : Node) -> ReadOnlyArray[Node] {
  let children = []
  match self {
    Document(doc) => {
      if doc.frontmatter is Some(frontmatter) {
        children.push(Node::Frontmatter(frontmatter))
      }
      children.push(block_node(doc.markdown.block))
    }
    Frontmatter(_) => ()
    Block(view) =>
      match view.block {
        Blocks({ v, .. }) =>
          for child in v {
            children.push(block_node(child))
          }
        BlockQuote({ v, .. }) => children.push(block_node(v.block))
        List({ v, .. }) =>
          for item in v.items {
            children.push(block_node(item.v.block))
          }
        Heading({ v, .. }) => children.push(inline_node(v.inline))
        Paragraph({ v, .. }) => children.push(inline_node(v.inline))
        ExtFootnoteDefinition({ v, .. }) => children.push(block_node(v.block))
        ExtTable({ v, .. }) =>
          for row in v.rows {
            if row.0.v is (Header(cells) | Data(cells)) {
              for cell in cells {
                children.push(inline_node(cell.0))
              }
            }
          }
        BlankLine(_)
        | CodeBlock(_)
        | HtmlBlock(_)
        | LinkRefDefinition(_)
        | ThematicBreak(_)
        | ExtMathBlock(_) => ()
      }
    Inline(view) =>
      match view.inline {
        Inlines({ v, .. }) =>
          for child in v {
            children.push(inline_node(child))
          }
        Emphasis({ v, .. }) | StrongEmphasis({ v, .. }) =>
          children.push(inline_node(v.inline))
        Link({ v, .. }) | Image({ v, .. }) => children.push(inline_node(v.text))
        ExtStrikethrough({ v, .. }) => children.push(inline_node(v.0))
        Autolink(_)
        | Break(_)
        | CodeSpan(_)
        | RawHtml(_)
        | Text(_)
        | ExtMathSpan(_) => ()
      }
  }
  ReadOnlyArray::from_array(children[:])
}

///|
fn block_node(block : @cmark.Block) -> Node {
  Node::Block(BlockView::{ block, })
}

///|
fn inline_node(inline : @cmark.Inline) -> Node {
  Node::Inline(InlineView::{ inline, })
}

///|
priv enum WalkFrame {
  Enter(Cursor)
  Leave(Cursor)
}

///|
/// Walk depth-first, calling `enter` before children and `leave` after them.
/// Skipped nodes still receive `leave`. Stop returns immediately without
/// pending leave calls. An explicit stack avoids recursive traversal.
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
/// Walk with immutable cursor positions. Navigation in either callback cannot
/// change this walk. Positions retain their ancestors and may be saved safely.
pub fn walk_cursor(
  root : Node,
  enter : (Cursor) -> Control,
  leave~ : (Cursor) -> Unit = _ => (),
) -> Unit {
  root.cursor().walk(enter, leave~)
}

///|
/// Walk this position's subtree, retaining its original ancestors and paths.
pub fn Cursor::walk(
  self : Cursor,
  enter : (Cursor) -> Control,
  leave~ : (Cursor) -> Unit = _ => (),
) -> Unit {
  let pending : Array[WalkFrame] = [Enter(self)]
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
/// A visitor overrides only the callbacks it needs. Enter callbacks control
/// traversal; `leave` follows the same rules as `walk`.
pub(open) trait Visitor {
  fn visit_document(Self, Document) -> Control = _
  fn visit_frontmatter(Self, Frontmatter) -> Control = _
  fn visit_block(Self, BlockView) -> Control = _
  fn visit_inline(Self, InlineView) -> Control = _
  fn leave(Self, Node) -> Unit = _
}

///|
impl Visitor with fn visit_document(_self, _doc) {
  Continue
}

///|
impl Visitor with fn visit_frontmatter(_self, _frontmatter) {
  Continue
}

///|
impl Visitor with fn visit_block(_self, _block) {
  Continue
}

///|
impl Visitor with fn visit_inline(_self, _inline) {
  Continue
}

///|
impl Visitor with fn leave(_self, _node) {
  ()
}

///|
pub fn[V : Visitor] Document::accept(self : Document, visitor : V) -> Unit {
  walk(
    Document(self),
    node => {
      match node {
        Document(doc) => visitor.visit_document(doc)
        Frontmatter(frontmatter) => visitor.visit_frontmatter(frontmatter)
        Block(block) => visitor.visit_block(block)
        Inline(inline) => visitor.visit_inline(inline)
      }
    },
    leave=node => visitor.leave(node),
  )
}

///|
pub(all) enum FoldAction[A] {
  Continue(A)
  SkipChildren(A)
  Stop(A)
} derive(Eq, Debug)

///|
pub extend FoldAction with Eq::{equal, not_equal}

///|
pub extend FoldAction with @debug.Debug::{to_repr}

///|
/// A fold callback threads an accumulator through nodes in pre-order.
struct Folder[A] {
  enter : (A, Cursor) -> FoldAction[A]
}

///|
pub fn[A] Folder::Folder(enter : (A, Node) -> FoldAction[A]) -> Folder[A] {
  { enter: (acc, cursor) => enter(acc, cursor.node()), }
}

///|
/// A folder with navigation context, using the same accumulator and control
/// semantics as the node-only constructor.
pub fn[A] Folder::with_cursor(
  enter : (A, Cursor) -> FoldAction[A],
) -> Folder[A] {
  { enter, }
}

///|
pub fn[A] Document::fold(self : Document, init : A, folder : Folder[A]) -> A {
  self.root().fold(init, folder)
}

///|
/// Fold a subtree. Cursor paths start at this node.
pub fn[A] Node::fold(self : Node, init : A, folder : Folder[A]) -> A {
  self.cursor().fold(init, folder)
}

///|
/// Fold this subtree while retaining navigation context from its original root.
pub fn[A] Cursor::fold(self : Cursor, init : A, folder : Folder[A]) -> A {
  let mut acc = init
  self.walk(cursor => {
    match (folder.enter)(acc, cursor) {
      Continue(value) => {
        acc = value
        Continue
      }
      SkipChildren(value) => {
        acc = value
        SkipChildren
      }
      Stop(value) => {
        acc = value
        Stop
      }
    }
  })
  acc
}
