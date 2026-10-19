# Shared notebook navigation examples

Import `moonrockz/notebooks` as `@notebooks`, its `nbformat` and `dib` packages
under those aliases, and `moonrockz/expect` as `@expect`. Each `mbt check`
block below runs as a documentation test.

The shared engine uses each format's concrete node type. Generic algorithms
use `Node.kind()`, `source()` and `metadata()`; specialized algorithms pattern match the
node returned by `Cursor[N].node()`.

## Use one algorithm with both formats

Select cells by their common kind. A DIB directive can expose source too, so
checking the kind prevents counting a directive as a second code cell.

```mbt check
///|
fn[N : @notebooks.Node] example_code_sources(root : N) -> ReadOnlyArray[String] {
  let sources = []
  @notebooks.walk(root, node => {
    if node.kind() is Cell(Code) {
      if node.source() is Some(source) {
        sources.push(source)
      }
      SkipChildren
    } else {
      Continue
    }
  })
  ReadOnlyArray::from_array(sources[:])
}

///|
test "example: one source query for Jupyter and DIB" {
  let jupyter = @nbformat.Notebook::from_json({
    "nbformat": 4,
    "nbformat_minor": 5,
    "metadata": {},
    "cells": [
      {
        "id": "title",
        "cell_type": "markdown",
        "metadata": {},
        "source": "# Results",
      },
      {
        "id": "code",
        "cell_type": "code",
        "metadata": {},
        "source": "print(42)",
        "execution_count": null,
        "outputs": [],
      },
    ],
  })
  let dib = @dib.parse("#!markdown\n# Results\n#!csharp\nprint(42)")
  @expect.expect_all(s => {
    s.expect(example_code_sources(jupyter.root())).to_equal(["print(42)"])
    s.expect(example_code_sources(dib.root())).to_equal(["print(42)"])
  })
}
```

This is shared inspection, not format conversion. Each format's parser and
writer retain its own data and constraints.

## Save a position and move around it

Moves return a new position or `None` at a boundary. Keeping a cursor saves
its node, path and ancestors. Paths use zero-based traversal-child indices.

```mbt check
///|
test "example: immutable cursor moves and path lookup" {
  let book = @dib.parse(
    "#!csharp\n#!share --from fsharp x\nprint(x)\n#!markdown\n# Results",
  )
  let root = @notebooks.Cursor(book.root())
  guard root.first_child() is Some(first) else { fail("missing first cell") }
  guard first.first_child() is Some(directive) else {
    fail("missing directive")
  }
  guard first.next_sibling() is Some(second) else {
    fail("missing second cell")
  }
  @expect.expect_all(s => {
    s.expect(root.depth()).to_equal(0)
    s.expect(root.path().to_string()).to_equal("$")
    s.expect(first.path().to_string()).to_equal("$[0]")
    s
    .expect(second.previous_sibling().map(cursor => cursor.path()))
    .to_equal(Some(first.path()))
    s
    .expect(root.last_child().map(cursor => cursor.path()))
    .to_equal(Some(second.path()))
    s
    .expect(directive.parent().map(cursor => cursor.path()))
    .to_equal(Some(first.path()))
    s
    .expect(@notebooks.at(book.root(), directive.path()))
    .to_equal(Some(directive.node()))
    s
    .expect(@notebooks.at(book.root(), @notebooks.NodePath([-1])))
    .to_equal(None)
    s.expect(root.parent() is None).to_be_true()
    s.expect(second.next_sibling() is None).to_be_true()
    s.expect(directive.first_child() is None).to_be_true()
    s.expect(first.path().to_string()).to_equal("$[0]")
  })
}
```

A path is relative to its originating tree. Another format can have a
different tree at the same indices. Paths are not persistent cell IDs.

## Prune descendants while keeping balanced leave callbacks

`SkipChildren` still calls `leave` for the skipped node. Here the code cell's
directive is skipped while the next Markdown cell is visited.

```mbt check
///|
test "example: prune code descendants" {
  let book = @dib.parse("#!csharp\n#!share --from fsharp x\n#!markdown\n# Note")
  let events = []
  @notebooks.walk_cursor(
    book.root(),
    cursor => {
      events.push("enter " + cursor.path().to_string())
      if cursor.node().kind() is Cell(Code) {
        SkipChildren
      } else {
        Continue
      }
    },
    leave=cursor => events.push("leave " + cursor.path().to_string()),
  )
  @expect.expect(events).to_equal([
    "enter $", "enter $[0]", "leave $[0]", "enter $[1]", "leave $[1]", "leave $",
  ])
}
```

## Stop immediately after finding a node

`Stop` cancels all pending `leave` calls, including those for ancestors.
Use a walk when a query should stop at its first result.

```mbt check
///|
test "example: stop at the first code cell" {
  let book = @dib.parse("#!csharp\nfirst()\n#!csharp\nsecond()")
  let found = []
  let left = []
  @notebooks.walk_cursor(
    book.root(),
    cursor => {
      if cursor.node().kind() is Cell(Code) {
        found.push(cursor.path().to_string())
        Stop
      } else {
        Continue
      }
    },
    leave=cursor => left.push(cursor.path().to_string()),
  )
  @expect.expect_all(s => {
    s.expect(found).to_equal(["$[0]"])
    s.expect(left.length()).to_equal(0)
  })
}
```

## Fold only the kinds needed by a query

A fold visits every node in pre-order and passes the accumulator returned by
one callback into the next. Concrete payloads remain accessible in the cursor.

```mbt check
///|
test "example: count code cells and retained directives" {
  let book = @dib.parse(
    "#!csharp\n#!share --from fsharp x\nprint(x)\n#!markdown\n# Note",
  )
  let counts = @notebooks.fold(book.root(), (0, 0), (counts, cursor) => {
    match cursor.node().kind() {
      Cell(Code) => (counts.0 + 1, counts.1)
      Directive(_) => (counts.0, counts.1 + 1)
      _ => counts
    }
  })
  @expect.expect(counts).to_equal((1, 1))
}
```

## Keep subtree context or establish a new root

`cursor.walk` and `cursor.fold` retain the position's original ancestors and
paths. Constructing a new cursor from that node starts paths again at `$`.

```mbt check
///|
test "example: subtree traversal and explicit rerooting" {
  let book = @dib.parse("#!csharp\n#!share --from fsharp x\nprint(x)")
  guard book.cursor().first_child() is Some(cell) else { fail("missing cell") }
  let original_paths = cell.fold([], (paths : Array[String], cursor) => {
    paths.push(cursor.path().to_string())
    paths
  })
  let fresh_paths = @notebooks.fold(cell.node(), [], (
    paths : Array[String],
    cursor,
  ) => {
    paths.push(cursor.path().to_string())
    paths
  })
  @expect.expect_all(s => {
    s.expect(original_paths).to_equal(["$[0]", "$[0][0]"])
    s.expect(fresh_paths).to_equal(["$", "$[0]"])
    s.expect(cell.path().to_string()).to_equal("$[0]")
  })
}
```

Local mutable accumulators are convenient for collecting results. The tree
and cursor positions remain immutable throughout the fold.

## Implement a node contract for another format

A consumer-defined format can use the engine without changing either built-in
format. Return immutable children in stable order and avoid cycles. The
`source` and `metadata` methods are optional and default to `None`.

```mbt check
///|
enum ExampleNode {
  Document(ReadOnlyArray[ExampleNode])
  Code(String)
}

///|
impl @notebooks.Node for ExampleNode with fn children(self) {
  match self {
    Document(children) => children
    Code(_) => []
  }
}

///|
impl @notebooks.Node for ExampleNode with fn kind(self) {
  match self {
    Document(_) => @notebooks.NodeKind::Notebook
    Code(_) => @notebooks.Cell(@notebooks.CellKind::Code)
  }
}

///|
impl @notebooks.Node for ExampleNode with fn source(self) {
  match self {
    Document(_) => None
    Code(source) => Some(source)
  }
}

///|
test "example: consumer-defined tree with typed cursors" {
  let root = ExampleNode::Document([Code("run()")])
  let cursor : @notebooks.Cursor[ExampleNode] = @notebooks.Cursor(root)
  guard cursor.first_child() is Some(child) else { fail("missing child") }
  guard child.node() is Code(source) else { fail("expected concrete payload") }
  @expect.expect_all(s => {
    s.expect(source).to_equal("run()")
    s.expect(example_code_sources(root)).to_equal(["run()"])
    s.expect(child.path().to_string()).to_equal("$[0]")
  })
}
```

## Query metadata in either format

Metadata belongs to the node being inspected. `None` means the node has no
metadata container; `Some(empty)` means its container has no keys. Custom keys
are retained and JSON lookups return independent copies. Key order is unspecified.

```mbt check
///|
fn[N : @notebooks.Node] example_title(root : N) -> Json? {
  match root.metadata() {
    Some(metadata) => metadata.get("title")
    None => None
  }
}

///|
test "example: shared metadata construction and generic lookup" {
  let metadata = @notebooks.Metadata({
    "title": "Results",
    "vendor": { "tags": ["review"] },
    "optional": null,
  })
  let jupyter = @nbformat.Notebook::Notebook([], metadata~)
  let dib = @dib.Notebook::Notebook([], metadata~)
  @expect.expect_all(s => {
    s.expect(example_title(jupyter.root())).to_equal(Some(Json("Results")))
    s.expect(example_title(dib.root())).to_equal(Some(Json("Results")))
    s.expect(metadata.keys().contains("vendor")).to_be_true()
    s.expect(metadata.get("optional")).to_equal(Some(null))
    s.expect(metadata.get("absent")).to_equal(None)
    s.expect(@notebooks.Metadata::empty().is_empty()).to_be_true()
    s.expect(jupyter.metadata()).to_equal(dib.metadata())
  })
  guard metadata.to_json() is Object(fields) else { fail("expected object") }
  fields.clear()
  @expect.expect(metadata.get("title")).to_equal(Some(Json("Results")))
}
```

Jupyter notebook, cell and rich-output constructors accept this shared type.
Jupyter `JsonObject` still represents extension fields and unknown payloads.
DIB metadata applies to the document; cells and directives have no container.
Jupyter stream, error and unknown output nodes and attachments return `None`.

## Read ancestor metadata explicitly

No automatic inheritance occurs. When your query needs document attributes,
keep the cursor's ancestry and request the parent metadata explicitly.

```mbt check
///|
test "example: local attributes differ from ancestor attributes" {
  let dib = @dib.parse("#!meta\n{\"title\":\"Results\"}\n#!csharp\nrun()")
  guard dib.cursor().first_child() is Some(cell) else { fail("expected cell") }
  guard cell.parent() is Some(parent) else { fail("expected document") }
  let jupyter = @nbformat.Notebook::from_json({
    "nbformat": 4,
    "nbformat_minor": 5,
    "metadata": { "title": "Results" },
    "cells": [
      {
        "id": "intro",
        "cell_type": "markdown",
        "metadata": {},
        "source": "# Results",
      },
    ],
  })
  guard jupyter.cursor().first_child() is Some(markdown) else {
    fail("expected cell")
  }
  @expect.expect_all(s => {
    s.expect(cell.node().metadata()).to_equal(None)
    s.expect(example_title(parent.node())).to_equal(Some(Json("Results")))
    s
    .expect(markdown.node().metadata())
    .to_equal(Some(@notebooks.Metadata::empty()))
    s.expect(example_title(markdown.node())).to_equal(None)
  })
}
```
