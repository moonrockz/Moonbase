Feature: OKF documents
  A bundle loads into immutable documents with kinds, Concept IDs, typed
  frontmatter, derived trust and lifecycle facts, and every unknown key kept.

  Background:
    Given the file "index.md":
      """
      ---
      okf_version: "0.2"
      ---
      # Tables

      * [Customers](/tables/customers.md) - One row per customer
      """
    And the file "log.md":
      """
      # Log

      ## 2026-10-20

      * **Creation**: Started.
      """
    And the file "tables/customers.md":
      """
      ---
      type: BigQuery Table
      title: Customers
      description: One row per customer
      owner_team: data-platform
      sources:
        - id: ga4-schema
          resource: https://example.com/schema
      verified: {by: "human:jsmith", at: "2026-06-30T14:00:00Z"}
      stale_after: 2026-09-01T00:00:00Z
      ---
      # Customers
      """
    And the file "metrics/revenue.md":
      """
      ---
      type: Metric
      status: archived
      ---
      # Revenue
      """
    And the file "computations/revenue.py" with the text "print(1)"

  Scenario: Load a bundle
    When the bundle at "" is loaded
    Then the documents are:
      | path                 | kind       |
      | /index.md            | root index |
      | /log.md              | log        |
      | /metrics/revenue.md  | concept    |
      | /tables/customers.md | concept    |
    And the assets are "/computations/revenue.py"
    And the Concept ID of "/tables/customers.md" is "tables/customers"
    And the OKF version is "0.2"

  Scenario: Typed fields, extension keys and scalar text
    When the bundle at "" is loaded
    Then the keys of "/tables/customers.md" are "type, title, description, owner_team, sources, verified, stale_after"
    And the field "owner_team" of "/tables/customers.md" is "data-platform"
    And the field "stale_after" of "/tables/customers.md" is "2026-09-01T00:00:00Z"
    And the source ids of "/tables/customers.md" are "ga4-schema"
    And the trust tier of "/tables/customers.md" is "human-reviewed"
    And the trust tier of "/metrics/revenue.md" is "unverified"
    And the display title of "/metrics/revenue.md" is "revenue"

  Scenario: Lifecycle status and staleness
    When the bundle at "" is loaded
    Then "/tables/customers.md" is stale at "2026-09-02T00:00:00Z"
    And "/tables/customers.md" is not stale at "2026-08-31T00:00:00Z"
    And the effective status of "/tables/customers.md" is "stable"
    And the effective status of "/metrics/revenue.md" is "archived"

  Scenario: Status default turned off
    Given the options set no status default
    When the bundle at "" is loaded
    Then the effective status of "/tables/customers.md" is ""

  Scenario: Invalid and duplicate frontmatter stay as data
    Given the file "tables/orders.md":
      """
      ---
      type: Table
      title: [unclosed
      ---
      # Orders
      """
    And the file "tables/returns.md":
      """
      ---
      title: A
      title: B
      ---
      """
    And the file "notes/plain.md" with the text "# Plain"
    When the bundle at "" is loaded
    Then "/tables/orders.md" has a frontmatter error
    And "/tables/returns.md" has a frontmatter error
    And "/notes/plain.md" has no frontmatter and no error
    And the documents include "/tables/customers.md"

  Scenario: Grouped bundles and strays
    Given the file "bundles/morphir/ir/index.md" with the text "---\nokf_version: \"0.2\"\n---\n"
    And the file "bundles/morphir/cli/index.md" with the text "---\nokf_version: \"0.2\"\n---\n"
    And the file "bundles/notes.md" with the text "# Notes"
    And the file "bundles/README.md" with the text "# Read me"
    When the bundles under "bundles" are discovered
    Then the bundles are:
      | label       | group   |
      | morphir/cli | morphir |
      | morphir/ir  | morphir |
    And the strays are "bundles/notes.md"

  Scenario: Unknown OKF version
    Given the file "next/index.md" with the text "---\nokf_version: \"0.3\"\n---\n"
    When the bundles under "next" are discovered
    Then the OKF version is "0.3"
