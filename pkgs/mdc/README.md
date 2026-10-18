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

## Tests

The package contains focused unit and regression tests. Public API acceptance
scenarios live in `tests/mdc-acceptance/`, and property laws in `tests/mdc-laws/`.
See [the test guide](../../tests/README.md) for the laws and commands. `mise run test`
runs all of them on their supported targets.
