# Tests

This workspace module contains acceptance tests and domain laws. It is excluded
from publication. Test packages import the public APIs of the modules they test.

Use `tests/<area>-acceptance/` for Moonspec step definitions and Gherkin features.
Use `tests/<area>-laws/` for generated properties. Keep unit tests and implementation
regressions beside their production package.

## MDC acceptance tests

`mdc-acceptance/features/mdc.feature` covers metadata and Markdown parsing,
source positions, rejected input, export isolation, traversal order, pruning,
cursor navigation, bottom-up reduction and consumer-implemented traversal traits.
The scenario World owns its state. Expect's `expect_all` reports related assertion
failures together. Feature paths are relative to the `tests` module directory,
which is the working directory Moon uses for these tests.

Run the thirteen scenarios on JS or native:

```shell
mise exec -- moon test tests/mdc-acceptance --target js
mise exec -- moon test tests/mdc-acceptance --target native
```

## MDC laws

`mdc-laws/` runs thirteen properties with 2,400 generated cases per target:

- Parsing preserves the exact body, header presence and original source origin.
- Frontmatter reconstruction preserves metadata, even after exported YAML is mutated.
- Cmark and view exports preserve text observations and cannot mutate the document.
- Walk, visitor and fold agree with a recursive traversal model for continue, prune and stop.
- A fold that preserves its accumulator returns its initial value.
- Adding or removing frontmatter leaves Markdown traversal unchanged.
- Cursor moves round-trip, saved positions stay fixed and paths resolve from their root.
- Cursor visitor, folder and walk callbacks agree with a positioned recursive model.
- Reduce matches recursive structural reduction and calls children before parents.
- Reduced node count and height match traversal observations.
- Subtree cursor operations retain ancestors and paths; node operations establish a new root.
- Generic trait folds agree with closure adapters and the traversal model, including pruning and stopping.
- Generic trait reducers preserve child grouping, order and saved cursor context.

Generators produce nested Markdown, Unicode metadata, BOMs and LF/CRLF/CR line
endings. Shrinking reduces the choices used to generate a document and renders
them again, keeping every candidate valid. Each property declares its seed,
case count, maximum size and shrink limit. Expect's `for_all` reports the shrunk
counterexample and assertion failures. To reproduce one, rerun its named test
with the checked-in seed; keep a focused regression case for a discovered bug.

```shell
mise exec -- moon test tests/mdc-laws --target wasm
mise exec -- moon test tests/mdc-laws --target wasm-gc
mise exec -- moon test tests/mdc-laws --target js
mise exec -- moon test tests/mdc-laws --target native
```

`mise run test` includes these suites automatically. Acceptance tests declare
`supported_targets = "js+native"`; laws run on all four targets. The runner reads
package restrictions instead of skipping the entire tests module on wasm.

## Notebook tests

`nbformat-acceptance/` covers cells, outputs, attachments, older and future
minor versions, retained extension payloads, cursor paths and validation errors.
Each scenario owns its state. These scenarios run on JavaScript and native.

`nbformat-laws/` runs three properties with 600 generated cases per target.
They check JSON and text round trips, agreement between recursive traversal,
walk and fold, and reversible cursor moves with resolvable saved paths.
Generators build valid cells with unique IDs, rich outputs, Unicode metadata,
attachments and unknown payloads. Shrinking rebuilds valid notebooks from
smaller generation choices. Seeds, sizes and shrink limits are explicit.
The laws run on all four targets.

```shell
mise exec -- moon test pkgs/notebooks/nbformat tests/nbformat-acceptance tests/nbformat-laws --target js
mise exec -- moon test pkgs/notebooks/nbformat tests/nbformat-acceptance tests/nbformat-laws --target native
mise exec -- moon test pkgs/notebooks/nbformat tests/nbformat-laws --target wasm
mise exec -- moon test pkgs/notebooks/nbformat tests/nbformat-laws --target wasm-gc
```

`notebooks-acceptance/` covers shared traversal on Jupyter and DIB, custom
kernel aliases, retained directives and access to specialized payloads. It
runs on JavaScript and native. Existing Jupyter acceptance scenarios continue
to run against the relocated `moonrockz/notebooks/nbformat` package.

`notebooks-laws/` adds four properties with 800 generated cases per target.
They compare common source observations across formats, verify cursor paths
and document order, check DIB newline and alias normalization, and compare
prune/stop behavior with a recursive model. Generators and shrinkers preserve
valid notebook sources and IDs. A consumer-defined third format also checks
that the open node contract does not require changes to the traversal engine.

```shell
mise exec -- moon test pkgs/notebooks/dib tests/notebooks-acceptance tests/notebooks-laws --target js
mise exec -- moon test pkgs/notebooks/dib tests/notebooks-acceptance tests/notebooks-laws --target native
mise exec -- moon test pkgs/notebooks/dib tests/notebooks-laws --target wasm
mise exec -- moon test pkgs/notebooks/dib tests/notebooks-laws --target wasm-gc
```

## EARS tests

`ears-acceptance/features/ears.feature` covers all six EARS patterns, malformed
sentences, formatted Markdown lists, existing MDC documents, retained frontmatter
and original source positions. Each scenario owns its state.

`ears-laws/` runs three properties with 600 generated cases per target. They
check clause preservation, canonical rendering and whitespace invariance, and
agreement between text and Markdown extraction with exact source spans.
Generators include complex clauses, Unicode, BOMs and LF/CRLF/CR line endings.
Shrinking preserves valid syntax. Seeds, case counts and size limits are explicit.

```shell
mise exec -- moon test tests/ears-acceptance tests/ears-laws --target js
mise exec -- moon test tests/ears-acceptance tests/ears-laws --target native
mise exec -- moon test tests/ears-laws --target wasm
mise exec -- moon test tests/ears-laws --target wasm-gc
```
