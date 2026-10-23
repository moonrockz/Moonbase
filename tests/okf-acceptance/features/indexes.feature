Feature: OKF indexes, logs and queries
  Indexes and logs parse into models, coverage and drift are checked, and
  concepts can be found by path, filters, facets, scans and ranked search.

  Background:
    Given the file "index.md":
      """
      ---
      okf_version: "0.2"
      ---
      # Metric

      * [Revenue](/metrics/revenue.md) - Net revenue per day
      * [Churn](/metrics/churn.md) - one row per churned customer.

      Prose that is not an entry.
      """
    And the file "log.md":
      """
      # Log

      ## 2026-09-01

      * **Creation**: Started.

      ## 2026-10-20

      * **Update**: Added revenue metric.
      """
    And the file "metrics/revenue.md":
      """
      ---
      type: Metric
      title: Revenue
      description: Revenue per day
      tags: [finance, daily]
      ---
      # Revenue

      ## Computation

      ```sql
      SELECT SUM(amount) FROM orders
      ```
      """
    And the file "metrics/churn.md":
      """
      ---
      type: Metric
      title: Churn
      description: One row per churned customer
      tags: finance
      ---
      # Churn

      Churn counts customers who left.
      """
    And the file "tables/orders.md":
      """
      ---
      type: BigQuery Table
      title: Orders
      ---
      # Orders
      """

  Scenario: Index model, coverage and drift
    When the bundle at "" is loaded
    Then the index entries of "/index.md" are:
      | text    | destination         | description                   |
      | Revenue | /metrics/revenue.md | Net revenue per day           |
      | Churn   | /metrics/churn.md   | one row per churned customer. |
    And the unindexed concepts are "/tables/orders.md"
    And drift is reported only for "/metrics/revenue.md"

  Scenario: Log model and order
    When the bundle at "" is loaded
    Then the log of "/log.md" has the dates "2026-09-01, 2026-10-20"
    And the log of "/log.md" is not newest first

  Scenario: Generated index groups concepts by type
    When the bundle at "" is loaded
    Then the generated index of "metrics" is:
      """
      # Metric

      * [Churn](churn.md) - One row per churned customer
      * [Revenue](revenue.md) - Revenue per day

      """

  Scenario: Lookup, filters and facets
    When the bundle at "" is loaded
    Then the lookup of "customers.md" finds nothing
    And the lookup of "revenue.md" finds "/metrics/revenue.md"
    And the concepts with type "metric" and tag "FINANCE" are "/metrics/churn.md, /metrics/revenue.md"
    And the facet "type" is "Metric=2, BigQuery Table=1"

  Scenario: Text scan with bodies
    When the bundle at "" is loaded
    Then the scan for "left" with bodies finds "/metrics/churn.md" on line 9

  Scenario: Ranked search
    When the bundle at "" is loaded
    Then the search for "revenue" with limit 5 returns "/metrics/revenue.md"
    And the search for "churn customers" with limit 5 returns "/metrics/churn.md"

  Scenario: Outline and body sections
    When the bundle at "" is loaded
    Then the outline of "/metrics/revenue.md" is "1:Revenue:7, 2:Computation:9"
    And the code of section "Computation" of "/metrics/revenue.md" is "sql: SELECT SUM(amount) FROM orders"
