# Notebooks

`moonrockz/notebooks` provides immutable notebook models and shared navigation
and traversal. The module has no dependency on the other Moonbase modules.

| Package | Purpose |
| --- | --- |
| `moonrockz/notebooks` | Open node contract, common node kinds, typed cursors, paths, walks and folds |
| `moonrockz/notebooks/nbformat` | Jupyter v4 JSON, cells, outputs, attachments and metadata |
| `moonrockz/notebooks/dib` | .NET Interactive source notebooks, kernels, metadata and directives |

Add the module with `moon add moonrockz/notebooks`. In `moon.pkg`, import the
packages you use:

```moonbit
import {
  "moonrockz/notebooks" @notebooks,
  "moonrockz/notebooks/nbformat" @nbformat,
  "moonrockz/notebooks/dib" @dib,
}
```

All packages support wasm, wasm-gc, JavaScript and native targets.
See the [Jupyter API](nbformat/README.md) and [DIB API](dib/README.md) for
format-specific codecs and constraints.

## Runnable usage guides

The following guides contain complete examples with assertions. MoonBit
compiles and runs their `mbt check` blocks as documentation tests, and
`mise run test` includes them on all four targets.

| Guide | Recipes |
| --- | --- |
| [Shared navigation](examples.mbt.md) | Cross-format queries, cursor moves, saved paths, prune/stop callbacks, folds, subtree roots and consumer-defined formats |
| [Jupyter notebooks](nbformat/examples.mbt.md) | Reading, construction, rich outputs, attachments, immutable metadata, ID lookup, errors, extensions and edits |
| [DIB notebooks](dib/examples.mbt.md) | Selectors, aliases, construction, custom environments, metadata, directive navigation, errors and empty-cell normalization |

Run all usage guides and package tests on one target:

```shell
mise exec -- moon test pkgs/notebooks pkgs/notebooks/nbformat pkgs/notebooks/dib --target js --deny-warn
```

## Shared navigation with concrete payloads

Each format has its own `Notebook`, `Cell` and `Node` values. Its `Node`
implements the open `@notebooks.Node` trait:

- `children()` returns immutable children in document order.
- `kind()` classifies a notebook, cell, output, attachment or directive.
- `source()` returns available source text, with `None` as the default.

`CellKind` distinguishes code, Markdown, raw and unknown cells. The shared
classification leaves the concrete format's payload intact. The traversal
engine does not convert notebooks or discard format-specific data.

Write a generic function once and call it with either format's root:

```moonbit
fn[N : @notebooks.Node] cell_sources(root : N) -> ReadOnlyArray[String] {
  let sources = []
  @notebooks.walk(root, node => {
    if node.kind() is Cell(_) {
      if node.source() is Some(source) { sources.push(source) }
    }
    Continue
  })
  ReadOnlyArray::from_array(sources[:])
}

let jupyter = @nbformat.parse(jupyter_json)
let interactive = @dib.parse(dib_source)
let jupyter_sources = cell_sources(jupyter.root())
let dib_sources = cell_sources(interactive.root())
```

`Cursor[N]` retains the concrete node type `N`. For a Jupyter root,
`cursor.node()` returns `@nbformat.Node`; for a DIB root, it returns
`@dib.Node`. Pattern match that value to inspect outputs, attachment MIME
bundles, kernel names or directive arguments. Both format packages expose
`book.cursor()`, `node.cursor()`, `node.at(path)`, `walk`, `walk_cursor` and
`book.fold` as convenience methods backed by the shared engine.

The trees differ where their formats differ. Jupyter cells have outputs or
attachments as children. DIB cells have directives as children. A generic
algorithm should use `kind()` to select the nodes it needs, rather than assume
identical tree shapes.

## Cursors, paths and traversal

Construct a cursor with `Cursor(root)`. Moves return a new position or `None`
at a boundary. Use `parent`, `first_child`, `last_child`, `next_sibling`,
`previous_sibling` and `children`. Saved positions retain their node and
ancestors. `depth()` starts at zero; `path()` returns a `NodePath` of child
indices. `@notebooks.at(root, path)` resolves it, or returns `None` for an
invalid index. Paths are relative to their original traversal root and refer
to child order, not JSON object keys or persistent cell IDs.

`walk(root, enter, leave~)` supplies nodes. `walk_cursor` supplies positions.
Both walk depth-first in pre-order. `Continue` visits children;
`SkipChildren` skips descendants but still calls `leave`; `Stop` returns
immediately without pending leave calls. `cursor.walk` retains the original
paths and ancestors while walking that subtree. Starting a cursor from the
node itself establishes a new root. Traversal uses an explicit stack.

`fold(root, init, f)` and `cursor.fold(init, f)` thread an accumulator through
the same pre-order, supplying cursor context. They visit every descendant.
Use a walk when pruning or early termination is needed.

## Additional notebook formats

A consumer can implement `@notebooks.Node` on its own immutable tree and use
the same cursors, path resolution, walks and folds. Children must be stable,
ordered, finite and immutable. Neither this package nor existing formats need
to change when another format implements the contract.

This module does not convert between file formats. Reading and writing remain
explicit operations on each format's notebook type, so saving a DIB notebook
cannot silently discard Jupyter outputs or attachments.

## Migration from moonbase-nbformat

Replace the module dependency `moonrockz/moonbase-nbformat` with
`moonrockz/notebooks` at the workspace version. Replace the package import
`moonrockz/moonbase-nbformat` with `moonrockz/notebooks/nbformat`, keeping the
`@nbformat` alias. Existing Jupyter codecs and convenience navigation methods
remain available. Explicit cursor annotations now use
`@nbformat.Cursor[@nbformat.Node]`, or `@notebooks.Cursor[@nbformat.Node]`.
`Control` and `NodePath` are shared types re-exported by both format packages.
