///|
priv struct ReduceFrame[A] {
  cursor : Cursor
  children : ReadOnlyArray[Cursor]
  mut next : Int32
  results : Array[A]
}

///|
/// Bottom-up reduction: `f` receives a node and its immediate children's results
/// in `children()` order. Leaves receive an empty collection. The root's result
/// is returned. Every node is reduced exactly once, using an explicit stack.
pub fn[A] reduce(root : Node, f : (Node, ReadOnlyArray[A]) -> A) -> A {
  reduce_cursor(root, (cursor, children) => f(cursor.node(), children))
}

///|
/// Bottom-up reduction with immutable navigation context. Child result
/// collections are immutable; their values belong to the caller and are not
/// deep-copied. Cursor paths start at `root`.
pub fn[A] reduce_cursor(root : Node, f : (Cursor, ReadOnlyArray[A]) -> A) -> A {
  root.cursor().reduce(f)
}

///|
/// Reduce this subtree while retaining its original ancestors and paths.
pub fn[A] Cursor::reduce(
  self : Cursor,
  f : (Cursor, ReadOnlyArray[A]) -> A,
) -> A {
  let stack : Array[ReduceFrame[A]] = [
    { cursor: self, children: self.children(), next: 0, results: [], },
  ]
  for ;; {
    let top = stack[stack.length() - 1]
    if top.next < top.children.length() {
      let child = top.children[top.next]
      top.next += 1
      stack.push({
        cursor: child,
        children: child.children(),
        next: 0,
        results: [],
      })
    } else {
      ignore(stack.pop())
      let result = f(top.cursor, ReadOnlyArray::from_array(top.results[:]))
      match stack.last() {
        Some(parent) => parent.results.push(result)
        None => return result
      }
    }
  }
}

///|
pub fn[A] Document::reduce(
  self : Document,
  f : (Node, ReadOnlyArray[A]) -> A,
) -> A {
  reduce(self.root(), f)
}

///|
pub fn[A] Document::reduce_cursor(
  self : Document,
  f : (Cursor, ReadOnlyArray[A]) -> A,
) -> A {
  reduce_cursor(self.root(), f)
}
