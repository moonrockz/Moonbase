# Tasks

## 1. Input checks

Beads: none yet.

- [x] 1.1 Accept only plain frontmatter keys and refuse raw values that add lines; verify the unit tests in `pkgs/okf/edit/edit_test.mbt`
- [x] 1.2 Refuse line breaks in log and index entries, and dates that are not real; verify the unit tests in `pkgs/okf/edit/edit_test.mbt` and `pkgs/okf/document_test.mbt`
- [x] 1.3 Refuse an extra state key, a missing state key and a broken preview in `plan_transition`; verify the unit tests
- [x] 1.4 Refuse unsafe export names and import dates in `moonrockz/okf/openspec`; verify the unit tests in `pkgs/okf/openspec/openspec_test.mbt`
- [x] 1.5 Treat only real dates as dated log headings; verify the unit test in `pkgs/okf/scenarios_test.mbt`
- [x] 1.6 Run `mise run check`; verify it passes
