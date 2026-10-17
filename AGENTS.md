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
- New packages go under `pkgs/` (libraries) or `apps/` (executables), and into `moon.work`.

## Working documents

`.dev/` is a gitignored area for AI-assisted work: specs, plans, brainstorming notes, scratch scripts and their output. Nothing in it is committed.

- Specs: `.dev/docs/superpowers/specs/YYYY-MM-DD-<topic>-design.html`.
- Plans: `.dev/docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.html`.
- Scratch scripts and output: `.dev/scripts/`, `.dev/out/`.
- Write these documents as standalone HTML, not Markdown: one file with inline CSS that works in light and dark mode, and inline SVG for diagrams.
- Never put a spec or plan under `docs/`, and never `git add` anything under `.dev/`.

## Product layout

- `pkgs/contracts` (`moonrockz/moonbase-contracts`) holds the commands the CLI, the web UI and the desktop shell share. `version()` matches the workspace version.
- `apps/cli` (`moonrockz/moonbase-cli`) is the `moonbase` command. `preferred_target` is `wasm`, so `moonx` runs it.
- `apps/web` (`moonrockz/moonbase-web`) is the Rabbita page. It is JavaScript only and mounts into the element `app`.
- `apps/desktop` (`moonrockz/moonbase-desktop`) defines the Proton command `moonbase.version` and the HTML document. It imports `moonbit-community/proton_contract`. It does not import `moonbit-community/proton`, because that link needs the CEF SDK.

`apps/web` sets `supported_targets = "js"` in `moon.mod` and in `moon.pkg`. `scripts/test.mbtx` reads the `moon.pkg` line and skips the package on other targets.

## Release process

Moonbase publishes to mooncakes.io and GitHub Releases, and records every release in `CHANGELOG.md`. The published modules are `moonrockz/moonbase-contracts`, `moonrockz/moonbase-cli`, `moonrockz/moonbase-web` and `moonrockz/moonbase-desktop`.

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
