///|
/// A visitor with immutable navigation positions. Default enter callbacks
/// continue; default leave does nothing. Nodes are available through `node()`.
pub(open) trait CursorVisitor {
  fn visit_document(Self, Cursor) -> Control = _
  fn visit_frontmatter(Self, Cursor) -> Control = _
  fn visit_block(Self, Cursor) -> Control = _
  fn visit_inline(Self, Cursor) -> Control = _
  fn leave(Self, Cursor) -> Unit = _
}

///|
impl CursorVisitor with fn visit_document(_self, _cursor) {
  Continue
}

///|
impl CursorVisitor with fn visit_frontmatter(_self, _cursor) {
  Continue
}

///|
impl CursorVisitor with fn visit_block(_self, _cursor) {
  Continue
}

///|
impl CursorVisitor with fn visit_inline(_self, _cursor) {
  Continue
}

///|
impl CursorVisitor with fn leave(_self, _cursor) {
  ()
}

///|
pub fn[V : CursorVisitor] Document::accept_cursor(
  self : Document,
  visitor : V,
) -> Unit {
  self.root().accept_cursor(visitor)
}

///|
pub fn[V : CursorVisitor] Node::accept_cursor(self : Node, visitor : V) -> Unit {
  self.cursor().accept(visitor)
}

///|
/// Visit this subtree with its original navigation context.
pub fn[V : CursorVisitor] Cursor::accept(self : Cursor, visitor : V) -> Unit {
  self.walk(
    cursor => {
      match cursor.node() {
        Document(_) => visitor.visit_document(cursor)
        Frontmatter(_) => visitor.visit_frontmatter(cursor)
        Block(_) => visitor.visit_block(cursor)
        Inline(_) => visitor.visit_inline(cursor)
      }
    },
    leave=cursor => visitor.leave(cursor),
  )
}
