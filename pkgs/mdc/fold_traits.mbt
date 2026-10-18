///|
/// Implement on an accumulator type. Each call returns the next accumulator
/// and traversal control, just like a `Folder` callback. No state is copied by
/// the engine; immutable implementations return a new value for each update.
pub(open) trait Fold {
  fn enter(Self, Node) -> FoldAction[Self]
}

///|
/// An accumulator with immutable cursor context. Saved cursor positions and
/// navigation have the same semantics as `Folder::with_cursor`.
pub(open) trait CursorFold {
  fn enter(Self, Cursor) -> FoldAction[Self]
}

///|
/// Adapt a user-implemented fold to the closure-based folder API.
pub fn[A : Fold] Folder::from_trait() -> Folder[A] {
  Folder::Folder((acc, node) => Fold::enter(acc, node))
}

///|
pub fn[A : CursorFold] Folder::from_cursor_trait() -> Folder[A] {
  Folder::with_cursor((acc, cursor) => CursorFold::enter(acc, cursor))
}

///|
/// The concrete state may itself be generic, with a conditional `Fold` impl.
pub fn[A : Fold] fold_with(root : Node, init : A) -> A {
  root.fold(init, Folder::from_trait())
}

///|
pub fn[A : CursorFold] fold_cursor_with(root : Node, init : A) -> A {
  root.cursor().fold_with(init)
}

///|
pub fn[A : Fold] Document::fold_with(self : Document, init : A) -> A {
  fold_with(self.root(), init)
}

///|
/// Fold with a user-implemented accumulator, starting a new navigation root.
pub fn[A : Fold] Node::fold_with(self : Node, init : A) -> A {
  fold_with(self, init)
}

///|
pub fn[A : CursorFold] Document::fold_cursor_with(
  self : Document,
  init : A,
) -> A {
  self.cursor().fold_with(init)
}

///|
pub fn[A : CursorFold] Node::fold_cursor_with(self : Node, init : A) -> A {
  self.cursor().fold_with(init)
}

///|
/// Fold a saved position's subtree, retaining its original navigation context.
pub fn[A : CursorFold] Cursor::fold_with(self : Cursor, init : A) -> A {
  self.fold(init, Folder::from_cursor_trait())
}
