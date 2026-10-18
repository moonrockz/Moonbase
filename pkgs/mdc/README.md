# MDC

`moonrockz/moonbase-mdc` parses Markdown with optional YAML frontmatter. It uses
[cmark](https://github.com/moonbit-community/cmark.mbt) `0.4.12` for Markdown and
[yaml](https://github.com/moonbit-community/yaml.mbt) `0.0.7` for metadata.

This module handles document syntax. A later OKF module can interpret metadata
and Markdown nodes without adding OKF rules to the MDC parser.

## Parsing

Import `moonrockz/moonbase-mdc` as `@mdc` in your `moon.pkg`.

```moonbit
let doc = @mdc.Document::Document("---\ntitle: Goal\n---\n# Goal\n")
// doc.frontmatter() contains the raw YAML and a parsed Yaml mapping.
// doc.body() is exactly the Markdown after the closing delimiter line.
```

`Document` is opaque and immutable. Its constructor derives the frontmatter,
Markdown tree and source positions from the input. `parse(source, ...)` is an
alias for the constructor. Accessors return immutable values. `to_cmark()`
exports a detached Markdown tree for cmark folders, mappers and renderers;
changing that tree cannot change the document or its traversal views.

`Frontmatter` is opaque. Create one from delimiter-free YAML text with
`Frontmatter::Frontmatter(raw)`. The constructor validates the payload and
derives the mapping from it. `raw()` returns the exact original text, and
`value()` returns a deep copy of the YAML mapping. Mutating that copy leaves the frontmatter
unchanged. The document parser uses this same constructor.

`parse` raises `ParseError` for an unterminated header, invalid YAML or a payload
that is not a mapping. `InvalidFrontmatter` contains a message and one-based
line and column numbers in the original input. `Frontmatter::Frontmatter` reports
positions relative to its payload. An empty or comment-only header is an empty
mapping.

Frontmatter must start on the first line with `---`. Either `---` or `...` closes
it. Delimiters accept trailing spaces and tabs, but no leading indentation.
The parser accepts a leading BOM and LF, CRLF or CR line endings. Later `---`
lines belong to Markdown. A first-line `---` always opens frontmatter, so it
requires a closing delimiter even when the intended content is a thematic break.

`strict`, `layout`, `locs` and `file` pass through to cmark. Defaults are
`strict=true`, `layout=true`, `locs=true` and `file=""`. Use `strict=false` for
cmark extensions such as tables, task lists, strikethrough and footnotes.

Cmark locations refer to `doc.body()`. Add `doc.body_offset()` to string offsets
and `doc.body_line() - 1` to line numbers to recover original source positions.
String offsets use UTF-16 code units, as MoonBit strings do. The BOM contributes
one code unit to the offset when present. Cmark layout nodes, including blank
lines, remain in the AST.

## Traversal

All traversal APIs visit the document, frontmatter when present, then Markdown
blocks and inlines in depth-first document order. Frontmatter is a leaf with a
parsed YAML mapping. Markdown nodes expose opaque `BlockView` and `InlineView`
values. Their `kind()` methods return algebraic data types containing immutable
inspection data, such as heading levels and text. `location()` returns the
source location. Link definitions and code blocks are leaves; link and image
text, table cells and footnote definition
bodies are children. Resolved references are not followed a second time.

Use `doc.root()` to obtain a traversal root. `Node::children()` returns a
`ReadOnlyArray[Node]` of immutable views. Use `walk` with enter and optional
leave callbacks. Enter returns `Continue`, `SkipChildren` or `Stop`.
Skipped nodes still receive leave callbacks. Stop ends the walk immediately,
without pending leave callbacks. Traversal uses an explicit stack.

Implement `Visitor` and call `doc.accept(visitor)` for named callbacks:
`visit_document`, `visit_frontmatter`, `visit_block`, `visit_inline` and `leave`.
Block and inline callbacks receive immutable views, so callbacks cannot change
the document or the nodes that other callbacks observe.
Default enter callbacks return `Continue`; default `leave` does nothing.

Use `doc.fold(initial, Folder::Folder(callback))` to accumulate a result. The
callback receives the accumulator and a `Node`, and returns
`FoldAction::Continue(acc)`, `SkipChildren(acc)` or `Stop(acc)`.

```moonbit
let headings = doc.fold(0, @mdc.Folder::Folder((count, node) => {
  match node {
    Block(view) => match view.kind() {
      Heading(_) => Continue(count + 1)
      _ => Continue(count)
    }
    _ => Continue(count)
  }
}))
```

To use cmark's existing APIs directly, pass `doc.to_cmark()` to a cmark folder,
mapper or renderer. These APIs operate on the Markdown body alone. Block and
inline views also offer `to_cmark()` for exporting a detached subtree, including
its layout and metadata. Exports copy mutable containers throughout the tree;
use `kind()`, `location()` and `children()` for inspection without subtree copies.

## Cursor navigation

`doc.cursor()`, `node.cursor()` and `Cursor::Cursor(node)` create immutable
positions at a navigation root. `node()` gives the focused node. `first_child()`,
`last_child()`, `parent()`, `next_sibling()` and `previous_sibling()` return a new
`Cursor` in `Some`, or `None` at a boundary. The original position remains a
bookmark. `children()` returns a read-only collection of child positions.

`depth()` counts edges from the navigation root. `path()` returns an opaque
`NodePath` with read-only child `indices()`. Its display form is `$[0][1]`, with
`$` denoting the root. Paths follow MDC traversal children, including blank
lines and other cmark layout nodes. Frontmatter, when present, is the document's
first child. `node.at(path)` resolves a path relative to that node and returns
`None` if it does not exist there.

Use `walk_cursor(root, enter, leave=...)` for cursor callbacks, or implement
`CursorVisitor` and call `doc.accept_cursor(visitor)`. Its `visit_document`,
`visit_frontmatter`, `visit_block`, `visit_inline` and `leave` methods receive
a `Cursor`. The enter methods return the same traversal controls as `Visitor`.
Saved positions and navigation within callbacks cannot move the outer traversal.

`Folder::with_cursor(callback)` passes `(accumulator, Cursor)` to a fold callback:

```moonbit
let deepest = doc.fold(0, @mdc.Folder::with_cursor((deepest, cursor) => {
  Continue(if cursor.depth() > deepest { cursor.depth() } else { deepest })
}))
```

`Node::fold` starts a new navigation root at that node. A saved cursor's
`walk`, `accept` and `fold` methods traverse its subtree while retaining its
original ancestors, depth and path. `Cursor::accept` takes a `CursorVisitor`.
The existing node-only visitor, folder and walk APIs remain available.

## Bottom-up reduce

`doc.reduce(callback)` and `reduce(root, callback)` compute one result per node
after its children. The callback receives `(Node, ReadOnlyArray[A])`, with one
result per immediate child in `children()` order. Leaves receive an empty
collection. The final answer is the root's result:

```moonbit
let nodes = doc.reduce((_, children : ReadOnlyArray[Int]) => {
  1 + children.fold(init=0, (total, count) => total + count)
})
```

`doc.reduce_cursor` and `reduce_cursor(root, callback)` pass a `Cursor` instead
of a node. `cursor.reduce(callback)` retains that position's original navigation
context while reducing its subtree. A reduction visits every node exactly once
in postorder and uses an explicit stack. Fold threads one accumulator in
preorder and supports pruning and stopping; reduce combines the completed
results of each node's own children.

Child result collections are immutable. Values supplied by callbacks belong
to the caller and are not deep-copied. Use immutable result types when sharing
them between reduction results.

## Trait implementations

Consumers can implement these open traits on their own types:

| Trait | Required method | Entry point |
| --- | --- | --- |
| `Fold` | `enter(Self, Node) -> FoldAction[Self]` | `fold_with(root, initial)` or `doc.fold_with(initial)` |
| `CursorFold` | `enter(Self, Cursor) -> FoldAction[Self]` | `fold_cursor_with(root, initial)` or `doc.fold_cursor_with(initial)` |
| `Reducer` | `reduce(Node, ReadOnlyArray[Self]) -> Self` | `reduce_with(root)` or `doc.reduce_with()` |
| `CursorReducer` | `reduce(Cursor, ReadOnlyArray[Self]) -> Self` | `reduce_cursor_with(root)` or `doc.reduce_cursor_with()` |

Fold implementations return the next accumulator with traversal control. Reducer
implementations construct a result from the node and its completed child results.
The reducer method has no receiver; a result annotation selects the implementation.
Neither operation requires mutable fields or shared state.

The traits are not generic, but their implementations and the traversal functions
can be. A generic wrapper can preserve a domain result while adding node counts:

```moonbit
struct Tracked[A] {
  value : A
  count : Int
}

impl[A : @mdc.Reducer] @mdc.Reducer for Tracked[A] with fn reduce(node, children) {
  {
    value: @mdc.Reducer::reduce(node, children.map(child => child.value)),
    count: 1 + children.fold(init=0, (sum, child) => sum + child.count),
  }
}
```

If a consumer's `Intent` type implements `Reducer`, then
`let result : Tracked[Intent] = doc.reduce_with()` computes both the domain result
and its node count. Generic fold wrappers work the same way, forwarding each
`FoldAction` while returning a new wrapper value. The
[trait laws](../../tests/mdc-laws/traits_wbtest.mbt) exercise generic wrappers for
all four traits through the public API.

`Node` offers the same trait entry points as `Document`, starting a new root.
`cursor.fold_with(initial)` takes a `CursorFold` and `cursor.reduce_with()` uses
a `CursorReducer`; both retain the saved position's original ancestors and paths.
`Folder::from_trait()` and `Folder::from_cursor_trait()` adapt trait implementations
to the existing `fold(initial, folder)` API. Closure-based APIs remain available
when a separate type would add no useful contract.

## Tests

The package contains focused unit and regression tests. Public API acceptance
scenarios live in `tests/mdc-acceptance/`, and property laws in `tests/mdc-laws/`.
See [the test guide](../../tests/README.md) for the laws and commands. `mise run test`
runs all of them on their supported targets.
