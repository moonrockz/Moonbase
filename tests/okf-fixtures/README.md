# OKF test fixtures

Fixtures for the `moonrockz/okf` acceptance suites and laws. Do not edit them by hand; update them from their sources.

| Directory | Source | Commit | License |
| --- | --- | --- | --- |
| `okf-samples/acme_retail`, `okf-samples/ga4` | [GoogleCloudPlatform/open-knowledge-format](https://github.com/GoogleCloudPlatform/open-knowledge-format) `bundles/` (without `viz.html`) | `ad30107` | Apache-2.0 |
| `morphir/kb/bundles` | [finos/morphir](https://github.com/finos/morphir) `kb/bundles/` | `ab8d5c91` | Apache-2.0 |
| `morphir/golden/*.json` | Output of the morphir CLI (`v0.4.0-beta.10`) at that commit: `morphir kb list --json`, `morphir kb check --json` and `morphir kb decision list --json`, run with `--kb kb` in this directory | `ab8d5c91` | Apache-2.0 |

The morphir copy leaves out the files at the root of `kb/` (`AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `README.md`), because they are not part of a bundle. Links from the bundles to repository files outside `kb/` are broken in this copy; the golden `check.json` records them as `link-broken`.
