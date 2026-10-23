# Mission Control

A MoonBit monorepo for Mission Control: shared contracts, a command-line application, a web UI and a Proton desktop shell.

## Packages

| Path | Module | Purpose |
|------|--------|---------|
| `pkgs/contracts` | `moonrockz/mission-control-contracts` | Commands shared by the CLI, the web UI and the desktop shell |
| `pkgs/mdc` | `moonrockz/mdc` | Markdown with YAML frontmatter, cursors, visitors, folds and reduction |
| `pkgs/ears` | `moonrockz/ears` | Typed EARS requirements, plain-text parsing and Markdown/MDC extraction |
| `pkgs/okf` | `moonrockz/okf` | Open Knowledge Format bundles: model, links, indexes, queries, validation, edits, stores and profiles |
| `apps/cli` | `moonrockz/mission-control-cli` | The `mission-control` command |
| `apps/web` | `moonrockz/mission-control-web` | Web UI written with [Rabbita](https://github.com/moonbit-community/rabbita) |
| `apps/desktop` | `moonrockz/mission-control-desktop` | Desktop shell: Proton command descriptors and the HTML document the window loads |
| `tests` | `moonrockz/mission-control-tests` | Unpublished acceptance suites and property laws |

The workspace members are listed in `moon.work`.

## Install

Install the `mission-control` command with [mise](https://mise.jdx.dev/) from a GitHub release:

```shell
mise use -g github:moonrockz/mission-control
mission-control version
```

Run the CLI module from mooncakes.io without a native binary:

```shell
moonx moonrockz/mission-control-cli@latest version
```

Use the contracts in a MoonBit project:

```shell
moon add moonrockz/mission-control-contracts
```

Each GitHub release has 8 assets. The names have no version, so `releases/latest/download/<name>` is a stable URL.

| Asset | Content |
|-------|---------|
| `mission-control-linux-x64.tar.gz` | `mission-control` for Linux x86-64 (static musl) |
| `mission-control-linux-arm64.tar.gz` | `mission-control` for Linux arm64 (static musl) |
| `mission-control-darwin-arm64.tar.gz` | `mission-control` for macOS on Apple silicon |
| `mission-control-darwin-x64.tar.gz` | `mission-control` for macOS on Intel |
| `mission-control-windows-x64.zip` | `mission-control.exe` for Windows x86-64 (built on Windows) |
| `mission-control.wasm` | The CLI for the MoonBit `wasm` target |
| `mission-control-gc.wasm` | The CLI for the MoonBit `wasm-gc` target |
| `checksums.txt` | SHA-256 of the other 7 assets |

The binary is at the root of each archive. Check a download with `sha256sum -c checksums.txt`.

The two wasm files are not WASI programs. They import MoonBit host functions from the module `__moonbit_fs_unstable`. A runtime must provide these functions. `wasmtime` cannot run them alone.

## Ecosystem

Mission Control builds on packages from these orgs:

- **moonbitlang.** The toolchain, `moonbitlang/core` and `moonbitlang/x`.
- **moonbit-community.** [Rabbita](https://github.com/moonbit-community/rabbita) `0.16.5` for the web UI. [Proton](https://github.com/moonbit-community/proton) `proton_contract` `0.4.0` for the desktop command descriptors. The Proton window runtime (`moonbit-community/proton`) links CEF. It is not a dependency yet. See [apps/desktop/README.md](apps/desktop/README.md).
- **moonrockz.** `zig-cross` `0.1.2` cross-builds the release binaries. `moonspec` and `expect` test the task scripts.
- **moonstack.** No package from moonstack is pinned. Add one when its release matches the MoonBit version in `.config/mise/config.toml`.

## Prerequisites

- [mise](https://mise.jdx.dev/). It installs every other tool: the pinned MoonBit toolchain, Node.js and yamllint.

## Setup

```shell
git clone https://github.com/moonrockz/mission-control.git
cd mission-control
mise trust
mise install
```

The mise binary archive of MoonBit omits the core library and `moonx`. If `moon version --all` does not show `moonc`, complete the toolchain into the mise install directory:

```shell
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | MOON_HOME="$(mise where http:moonbit)" bash -s -- "$(mise current http:moonbit)"
```

Then install the git hooks, which [lefthook](https://lefthook.dev/) manages from `lefthook.yml`:

```shell
mise run hooks:install
```

The pre-commit hook checks formatting and runs `moon check`. The pre-push hook runs lint, validate and test.

## Tasks

Every task is a MoonBit script in `scripts/*.mbtx`, run with `moonx`, so one script works on every platform. Run `mise tasks` for the list.

```shell
mise run check                 # lint, validate, test, build
mise run lint                  # yamllint, moon fmt --check, moon check
mise run format                # moon fmt
mise run validate              # package structure and versions
mise run test                  # all targets
mise run build                 # all targets
mise run build:native          # native release build
mise run build:release         # 4 native binaries (zig), 2 wasm files, dist/
mise run release:status        # main, tags, GitHub release and mooncakes.io agree
mise run hooks:install         # git hooks (lefthook)
```

Without mise: `moonx scripts/<name>.mbtx [args]`.

## Layout

```
mission-control/
├── .config/mise/config.toml   # tools and tasks
├── .github/workflows/ci.yml   # lint, build and test
├── .github/workflows/release.yml # plan, validate, build, smoke, publish, release
├── apps/cli/                  # mission-control command (moonrockz/mission-control-cli)
├── apps/web/                  # Rabbita UI (moonrockz/mission-control-web)
├── apps/desktop/              # Proton shell (moonrockz/mission-control-desktop)
├── pkgs/contracts/            # shared commands (moonrockz/mission-control-contracts)
├── pkgs/mdc/                  # Markdown with frontmatter (moonrockz/mdc)
├── pkgs/ears/                 # EARS specifications (moonrockz/ears)
├── pkgs/okf/                  # Open Knowledge Format (moonrockz/okf)
├── tests/                     # acceptance suites and domain laws, unpublished
├── openspec/                  # requirements and change proposals (OpenSpec)
├── scripts/*.mbtx             # task scripts, run with moonx
├── moon.mod                   # workspace root module
└── moon.work                  # workspace members
```

## Release

All modules share one version. The root `moon.mod` is the source of truth. `mise run validate:versions` fails when a module, a sibling import or a `version()` string has another version.

`mise run release:prepare [X.Y.Z]` computes the next version with git-cliff, sets the version, prepends a section to `CHANGELOG.md`, commits `chore(release): vX.Y.Z` on `release/vX.Y.Z`, pushes it and opens a draft pull request. `--local` stops before the push. Replace the highlights comment, push, then run `mise run release:refresh`. Merge that pull request. The Release workflow publishes the modules to mooncakes.io and creates the GitHub release. A pull request run and a manual run with `dry_run` do not publish.

The first push of this repository does not run the release plan. `CHANGELOG.md` has no section until `release:prepare` writes one.

## Adding a package

1. Create `pkgs/<name>/moon.mod` (module `moonrockz/mission-control-<name>`) and a `moon.pkg`.
2. Add `"./pkgs/<name>"` to `moon.work`.
3. Add the module to `publish_list` in `scripts/publish.mbtx` and `scripts/release.mbtx` when it should be published.
4. Run `mise run validate`.

## License

Apache-2.0. See [LICENSE](LICENSE).
