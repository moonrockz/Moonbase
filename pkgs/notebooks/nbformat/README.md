# Jupyter notebooks

`moonrockz/notebooks/nbformat` represents the
[Jupyter notebook format](https://nbformat.readthedocs.io/en/latest/format_description.html)
as immutable MoonBit values. It reads and writes nbformat 4.x JSON and provides
cursors and depth-first traversal over cells, outputs and attachments.

Add the `moonrockz/notebooks` module to `moon.mod` and import its
`moonrockz/notebooks/nbformat` package as `@nbformat` in `moon.pkg`.
The module supports wasm, wasm-gc, JavaScript and native targets.

## Read and write

```moonbit
let book = @nbformat.parse(source)
let first_cell = book.cell(0) // Cell?, with None at an invalid index
let code_cell = book.cell_by_id(@nbformat.CellId("calculation"))
let json = book.to_json()
let text = book.to_string()
```

`Notebook::from_json` imports an existing `Json` value. Both entry points raise
`FormatError`. Invalid fields report their location, such as
`$.cells[0].outputs[1].data.text/plain`. Invalid JSON, unsupported major versions,
duplicate cell IDs and duplicate cell names have distinct error variants.

The reader accepts v4.0 through v4.5 and future v4 minor versions. It requires
cell IDs from v4.5 onward, checks their permitted characters and length, and
rejects duplicate IDs even in older documents. It rejects other major versions
without converting them. Construction defaults to v4.5 and requires callers
to supply IDs. The library does not generate IDs or execute notebook code.

Cell sources, stream text and textual MIME data accept strings or arrays of
strings. Arrays join without inserted separators. JSON MIME values, identified
by `application/json` or a `+json` suffix, retain their JSON structure. The
writer emits normalized strings; it does not preserve indentation, object key
order or the input's division into lines.

## Construct values

```moonbit
let cell = @nbformat.Cell::Cell(
  @nbformat.Markdown(source="# Results", attachments=None),
  id=Some(@nbformat.CellId("intro")),
)
let book = @nbformat.Notebook::Notebook([cell])
```

`CellContent` distinguishes `Markdown`, `Raw`, `Code` and `Unknown`. Code cells
carry an optional `ExecutionCount` and a read-only sequence of `Output` values.
Markdown and raw cells carry optional `Attachments`, indexed by filename.
Access the complete variant with `cell.content()`, or use `source()`,
`outputs()`, `metadata()`, `id()` and `cell_type()` for common queries.
`source()` returns `None` for an unknown cell; `outputs()` is empty for cells
whose type is not code.

`OutputContent` distinguishes `Stream`, `DisplayData`, `ExecuteResult`, `Error`
and `Unknown`. Rich outputs use `MimeBundle` and `JsonObject` metadata. Error
outputs retain a read-only sequence of traceback frames. Stream names remain
strings, as allowed by the schema. `ExecutionCount(n)` validates a nonnegative
integer; `ExecutionCount::from_json` also accepts numeric JSON representations
outside the machine integer range and retains their representation. `None`
represents a null execution count. Execute-result counts also accept null,
following the official v4 JSON schema.

`JsonObject(json)`, `MimeBundle(json)` and `Attachments(json)` validate and
copy their inputs. Lookup and JSON export return defensive copies of arbitrary
JSON. Domain arrays are read-only, including arrays inside public variants.
Keeping a notebook, cell or cursor therefore saves an immutable value.

## Metadata and extensions

Notebook, cell and rich-output metadata use `JsonObject`. Known metadata fields
are checked when present, including kernel and language names, authors, cell
tags, visibility flags and execution timestamps' string types. Empty metadata
objects are valid. Custom metadata can contain arbitrary JSON.

The reader preserves extra fields on notebooks, cells and outputs. Retrieve
them with `extensions()`. Unknown cell and output types use `Unknown` variants,
whose `fields` contain their additional payload. They serialize without losing
that payload and remain leaves during traversal. Unknown cell metadata and IDs
remain available through the common cell accessors. Common fields must be
supplied separately when constructing an unknown value.

This is a forward-compatible codec with structural and domain validation.
It deliberately accepts extension fields and unknown types, including those
that the official schema's closed objects reject. It is not a general JSON
Schema validator. Validation checks required fields, field types, MIME text,
IDs, counts and defined metadata constraints; it does not inspect attachment
base64, render Markdown, validate timestamp syntax or implement notebook trust.

## Navigation

```moonbit
let root = book.cursor()
let first = root.first_child()
@nbformat.walk_cursor(book.root(), cursor => {
  println(cursor.path().to_string())
  @nbformat.Continue
})
let node_count = book.fold(0, (count, _cursor) => count + 1)
```

`Node` contains `Notebook`, `Cell`, `Output` and named `Attachment` variants.
It implements the shared `@notebooks.Node` contract. Its cursors are
`@notebooks.Cursor[Node]`, preserving Jupyter payloads while using the same
navigation and traversal engine as DIB. The package re-exports the shared
`Cursor`, `Control` and `NodePath` types.
Notebook children are cells in document order. Code-cell children are outputs
in execution order. Markdown and raw cell children are attachments in lexical
filename order. Outputs and attachments are leaves. Metadata and MIME payloads
are available through accessors rather than traversal children.

Cursor moves return a new position or `None` at a boundary. Use `parent()`,
`first_child()`, `last_child()`, `next_sibling()`, `previous_sibling()` and
`children()`. Saved cursors retain their original position and ancestors.
`depth()` is zero at the root. `path()` returns a `NodePath` of child indices;
`root.at(path)` resolves it against that root. Paths refer to traversal
children, rather than JSON object keys. They can also be constructed explicitly
with `NodePath(indices)`; an invalid index resolves to `None`.

`walk` supplies nodes; `walk_cursor` supplies positions. Both visit in depth-first
pre-order and accept an optional `leave` callback. `Continue` descends,
`SkipChildren` skips descendants but still calls `leave`, and `Stop` ends
immediately without pending leave calls. `cursor.walk` visits a subtree while
retaining its original paths and ancestors. Starting from `node.cursor()`
establishes a new root. `book.fold` threads an accumulator through the same
pre-order, supplying cursor context. Traversal uses an explicit stack.
