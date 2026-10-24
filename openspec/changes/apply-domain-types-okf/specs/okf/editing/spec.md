# Spec Delta

## ADDED Requirements

### Requirement: Typed edit inputs
The edit functions SHALL take frontmatter keys, raw YAML values, section names and log dates as values whose constructors check the rules that `check-okf-inputs` added, so that an edit receives only valid inputs and checks no rule again.

#### Scenario: Section name with a line break
- **WHEN** a caller builds a section name from `A\nB`
- **THEN** the constructor raises an error that names the line break

### Requirement: Typed planner errors
The planners and conversions SHALL raise one typed error that covers path refusals, edit errors and transition refusals, so that a caller can match every case.

#### Scenario: Refused path in a plan
- **WHEN** a caller plans a concept at `/tables/index.md`
- **THEN** the planner raises the plan error case for a reserved name
