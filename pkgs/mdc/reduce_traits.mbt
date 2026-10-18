///|
/// Implement on the result type of a bottom-up reduction. Child results arrive
/// in `children()` order; leaves receive an empty read-only collection.
pub(open) trait Reducer {
  fn reduce(Node, ReadOnlyArray[Self]) -> Self
}

///|
/// A result type whose reduction can inspect immutable navigation context.
pub(open) trait CursorReducer {
  fn reduce(Cursor, ReadOnlyArray[Self]) -> Self
}

///|
/// Reduce with the implementation on the requested result type. Supply a result
/// type annotation when it cannot be inferred, for example `let n : Count = ...`.
pub fn[A : Reducer] reduce_with(root : Node) -> A {
  reduce(root, (node, children) => Reducer::reduce(node, children))
}

///|
pub fn[A : CursorReducer] reduce_cursor_with(root : Node) -> A {
  root.cursor().reduce_with()
}

///|
pub fn[A : Reducer] Document::reduce_with(self : Document) -> A {
  reduce_with(self.root())
}

///|
pub fn[A : Reducer] Node::reduce_with(self : Node) -> A {
  reduce_with(self)
}

///|
pub fn[A : CursorReducer] Document::reduce_cursor_with(self : Document) -> A {
  self.cursor().reduce_with()
}

///|
pub fn[A : CursorReducer] Node::reduce_cursor_with(self : Node) -> A {
  self.cursor().reduce_with()
}

///|
/// Reduce a saved position's subtree with its original ancestors and paths.
pub fn[A : CursorReducer] Cursor::reduce_with(self : Cursor) -> A {
  self.reduce((cursor, children) => CursorReducer::reduce(cursor, children))
}
