# Spec Delta

## ADDED Requirements

### Requirement: Dated log headings
The library SHALL treat a log section heading as dated only when it is a real calendar date in the form `YYYY-MM-DD`. A heading such as `2026-13-45` SHALL be undated.

#### Scenario: Impossible date
- **WHEN** a log has the headings `2026-13-45`, `2026-02-30` and `2026-10-23`
- **THEN** the undated sections are `2026-13-45` and `2026-02-30`
