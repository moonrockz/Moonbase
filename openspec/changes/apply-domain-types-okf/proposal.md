# Proposal

## Why

`AGENTS.md` now requires domain types: no primitive obsession, parse do not validate, and invalid states that cannot be represented. A review of `moonrockz/okf` against these rules found that most of its public API carries values with rules as raw `String`, `Int` and `Array` values, and that many `pub(all)` structs let a caller build values that break their rules. Some of these gaps already caused bugs, which `check-okf-inputs` fixed one at a time. `moonrockz/okf` is not released yet, so this is the cheapest time to make its API type-safe.

## What Changes

- **BREAKING (unreleased API):** values with rules become types with private fields and smart constructors in the `fn T::T(...) -> T raise E` style: bundle labels, store directories, concept types, frontmatter keys, rule names, register, state and record names, ID widths, search limits, heading levels, log dates, section names, store roots and entry names, OpenSpec capability paths, change names, requirement names and task numbers.
- Fixed sets become enums: link origin, OKF version, facets, scan fields, index groups, key sources, OpenSpec types and change states.
- Sentinel values go away: the `0` line for profile links, the `""` bundle for strays, `""` for "no ID", `Other("")` actors and `""` task numbers become options or enum cases.
- Public values become immutable: arrays and maps in public values become read-only, and `pub(all)` structs with rules become `pub` with private fields.
- Errors become typed where they are not: `FixedClock::at`, the planners and the conversions raise named `suberror` types, and `StoreError` payloads name store-relative locations, not host paths.
- Two behavior fixes that the types make possible: a concept of type `Subdirectories` no longer joins the generated subdirectory section, and a validation config that names an unknown rule is reported.
- Each smart constructor gets tests on each side of each rule.

### Out of scope

- `moonrockz/ears`, `moonrockz/mdc`, the contracts, the apps and the scripts (`apply-domain-types-libraries`).
- New features. Behavior stays the same except for the two fixes above.
- The new types of `add-browser-storage-options` (`StoreDir` is shared: whichever change lands first adds it).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `okf/documents`: typed labels, directories, concept types, keys, OKF versions, and immutable values.
- `okf/relationships`: links with a consistent kind and an origin, typed document references and GitHub sources.
- `okf/indexes`: typed heading levels and log headings, and index groups apart from concept types.
- `okf/queries`: typed search limits, facets, scan fields and status filters.
- `okf/validation`: rule names, finding subjects, the documented finding order, and reports of unknown rule names.
- `okf/profiles`: registers built through a checked constructor, and typed register parts.
- `okf/editing`: typed keys, raw values, section names, dates and planner errors.
- `okf/providers`: typed store roots, directories, entry names, index metadata and store error locations.
- `okf/openspec`: typed capability paths, change names, requirement names, task numbers, types and states.

## Impact

- **Affected published module:** `moonrockz/okf` only (not released, so no caller migrates). The README examples and the tests change with the API.
- **Tests:** unit tests for each constructor rule; the existing acceptance features, laws, golden checks and browser checks must pass after the change.
