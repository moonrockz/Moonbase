# Agent Instructions

This is a [MoonBit](https://docs.moonbitlang.com) monorepo for Moonbase. Read [README.md](README.md) for the layout.

## Toolchain

- `mise` installs and pins every tool (`.config/mise/config.toml`). Run `mise trust` and then `mise install` once.
- The MoonBit version is pinned there. Change it in the version field and in each URL together.
- `moon.work` lists the workspace members. `moon build`, `moon test`, `moon check` and `moon fmt` at the root act on all of them.

## Task scripts

Write task and automation scripts in MoonBit, as standalone `.mbtx` scripts, not as bash or PowerShell. One script then works on every platform, and it uses the toolchain that mise already installs.

- Put the script in `scripts/` and run it with `moonx scripts/<name>.mbtx`.
- Declare its mise task in `.config/mise/config.toml`: `run = "moonx scripts/<name>.mbtx"`.
- Pin the version of each import: `"moonbitlang/async@0.22.5/process"`. Use `moonbitlang/async` for processes (`@process.run`, `@process.collect_output`), files (`@fs`) and `@stdio`; `moonbitlang/core/env` for `@env.args()` and environment variables; `moonbitlang/x/sys` for `@sys.exit`.
- `@env.args()` has the script binary at index 0. Task arguments start at index 1 (`mise run task -- arg`).
- A `.mbtx` file cannot start with a shebang line, so a mise file task cannot be a `.mbtx` file. Keep the toml task declaration.
- Exit with a non-zero code on failure. Do not print and continue.

## Pre-push checks

`mise run lint` and `mise run validate` must pass before a push. The git hooks are managed by [lefthook](https://lefthook.dev/) and defined in `lefthook.yml`. Install them once with `mise run hooks:install`. The pre-commit hook runs `moon fmt --check` and `moon check --deny-warn`. The pre-push hook runs lint, validate and test. `mise run check` runs lint, validate, test and build, which is what CI runs.

## Working rules

- Commits use Conventional Commits, in plain English, with no AI attribution and no `Co-Authored-By` lines.
- Run `mise run format` before you commit MoonBit code.
- Production modules go under `pkgs/` for libraries or `apps/` for executables. Acceptance and law suites go under `tests/`. Add every module to `moon.work`.

## Development style

- Prioritize functional programming. Use a functional core for domain rules and transformations, with an imperative shell for I/O, external services and orchestration. Pass dependencies and inputs explicitly; return values and decisions from the core for the shell to act on.
- Model the domain with meaningful types. Avoid primitive obsession: use distinct types for values with different meanings or constraints, rather than interchangeable strings, integers and booleans.
- Prefer immutable domain values and public contracts. Hide representations and use smart constructors to establish invariants. Validate external data at boundaries, then pass validated values through the core.
- Use MoonBit's custom constructor functions for APIs we own: `fn Foo::Foo(...) -> Foo`, or `fn Fallible::Fallible(...) -> Fallible raise MyErrorType` for fallible construction. Prefer these over `::new`; call them as `Foo(...)` or `Foo::Foo(...)` when qualification is needed. Keep smart constructor validation and representation hiding in place. Use dependency APIs as provided.
- Protect immutability through the whole value graph. Do not expose mutable maps, arrays or other aliases that let callers invalidate a domain value. Use immutable views or defensive copies where needed.
- Avoid shared mutable state in the core. Express state changes as explicit transitions that produce new values; keep ownership and data flow clear.
- Use functional domain modeling and algebraic data types. Represent alternatives with enums and related data with structs. Make invalid states unrepresentable and handle alternatives with exhaustive pattern matching.
- Use typestate when operations depend on lifecycle or validation state. Give states distinct types and expose valid transitions through their APIs, so the compiler enforces operation order. Avoid boolean flag combinations and repeated runtime guards for facts already established by a type. Keep runtime checks for conditions that types cannot guarantee.
- Imperative algorithms and local mutation are allowed inside implementations for performance. Keep that mutation encapsulated, prevent mutable aliases from escaping, and preserve the observable behavior and invariants of the functional API.

## Testing style

- Write acceptance tests with `moonrockz/moonspec`, using Gherkin features and step definitions under `tests/<area>-acceptance/`. Exercise public APIs and describe observable behavior. Keep scenario state local to each World.
- Use `moonrockz/expect` for assertions. Group related independent assertions with `expect_all` and use the supplied scope's `s.expect` so one failure does not hide the others. Keep prerequisite checks outside the soft assertion group when later checks require their values.
- Establish domain and traversal laws with property-based tests under `tests/<area>-laws/`, using Expect's `for_all` and MoonBit QuickCheck. Generate valid domain inputs by construction, supply shrinkers that preserve validity, and set explicit seeds, case counts and size limits so failures are reproducible.
- Keep focused unit and implementation regression tests beside the package. Acceptance tests and laws belong to the unpublished `tests` workspace module. Declare target restrictions per package in `moon.pkg`; the test task discovers packages recursively.

## Working documents

`.dev/` is a gitignored area for AI-assisted work: specs, plans, brainstorming notes, scratch scripts and their output. Nothing in it is committed.

- Specs: `.dev/docs/superpowers/specs/YYYY-MM-DD-<topic>-design.html`.
- Plans: `.dev/docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.html`.
- Scratch scripts and output: `.dev/scripts/`, `.dev/out/`.
- Write these documents as standalone HTML, not Markdown: one file with inline CSS that works in light and dark mode, and inline SVG for diagrams.
- Never put a spec or plan under `docs/`, and never `git add` anything under `.dev/`.

## Product layout

- `pkgs/contracts` (`moonrockz/moonbase-contracts`) holds the commands the CLI, the web UI and the desktop shell share. `version()` matches the workspace version.
- `pkgs/mdc` (`moonrockz/moonbase-mdc`) adds YAML frontmatter to cmark documents and exposes visitor, fold and traversal APIs for downstream format modules such as OKF.
- `tests` (`moonrockz/moonbase-tests`) contains acceptance suites and property laws. It is a workspace member and is excluded from both publish lists.
- `apps/cli` (`moonrockz/moonbase-cli`) is the `moonbase` command. `preferred_target` is `wasm`, so `moonx` runs it.
- `apps/web` (`moonrockz/moonbase-web`) is the Rabbita page. It is JavaScript only and mounts into the element `app`.
- `apps/desktop` (`moonrockz/moonbase-desktop`) defines the Proton command `moonbase.version` and the HTML document. It imports `moonbit-community/proton_contract`. It does not import `moonbit-community/proton`, because that link needs the CEF SDK.

`apps/web` sets `supported_targets = "js"` in `moon.mod` and in `moon.pkg`. `scripts/test.mbtx` reads the `moon.pkg` line and skips the package on other targets.

## Release process

Moonbase publishes to mooncakes.io and GitHub Releases, and records every release in `CHANGELOG.md`. The published modules are `moonrockz/moonbase-contracts`, `moonrockz/moonbase-mdc`, `moonrockz/moonbase-cli`, `moonrockz/moonbase-web` and `moonrockz/moonbase-desktop`.

- `mise run release:status` checks that main, the tags, the GitHub release and mooncakes.io agree. Each problem it prints names the command that fixes it.
- All modules share one version. The root `moon.mod` is the source of truth. `mise run validate:versions` fails when a module, a sibling import or a `version()` string has another version. `moonx scripts/versions.mbtx set X.Y.Z` rewrites them. The first release is `0.0.1`.
- To release, run `mise run release:prepare [X.Y.Z]` on a clean working tree. It computes the next version with git-cliff (`cliff.toml`), sets the version everywhere, prepends the section to `CHANGELOG.md`, commits `chore(release): vX.Y.Z` on `release/vX.Y.Z`, pushes it and opens a draft pull request. `--local` stops before the push.
- Replace the highlights comment in `CHANGELOG.md` with a few sentences. Push, then run `mise run release:refresh`. Then merge. Do not bump the version in another pull request.
- The merge changes `moon.mod` on main, so the Release workflow (`.github/workflows/release.yml`) runs. The jobs are `plan`, `validate`, `build-windows`, `build`, `smoke`, `publish` and `release`.
- `build` cross-compiles four native binaries with `moonx moonrockz/zig-cross@0.1.2`. Windows is built on a Windows runner. A cross-built Windows binary reads its arguments wrongly.
- `publish` needs the `MOONCAKES_USER_TOKEN` org secret. It runs after `smoke`. A mooncakes.io version is permanent.
- A pull request that changes a release file, and a manual run with `dry_run`, run `plan`, `validate`, `build-windows`, `build` and `smoke` only. They never publish and never create a release.
- **Re-run failed jobs.** After a transient failure, use "Re-run failed jobs" on the run. `publish` skips a version that is already published. `release` uploads only the missing assets.
- Write commit and pull request titles for the changelog: the squash-merge title is the changelog line.

The two copies of the publish list, in `scripts/publish.mbtx` and `scripts/release.mbtx`, must stay equal. A script test checks that.
