Feature: OKF relationships
  Body links resolve to their targets, and the link graph gives outbound links,
  backlinks, orphans and broken links.

  Background:
    Given the file "index.md":
      """
      ---
      okf_version: "0.2"
      ---
      # Tables

      * [Orders](/tables/orders.md) - Orders
      """
    And the file "tables/orders.md":
      """
      ---
      type: Table
      ---
      # Orders

      See [Customers](customers.md), [rev](../metrics/revenue.md#daily),
      [home](https://example.com), [top](#orders) and [gone](/tables/returns.md).

      ```
      [Customers](/tables/customers.md)
      ```

      ![Diagram](/assets/flow.png)
      """
    And the file "tables/customers.md":
      """
      ---
      type: Table
      ---
      # Customers
      """
    And the file "metrics/revenue.md":
      """
      ---
      type: Metric
      ---
      Uses [customers](/tables/customers.md) and [spec](/../../spec/a.md).
      """

  Scenario: Links and their kinds
    When the bundle at "" is loaded
    Then the links of "/tables/orders.md" are:
      | text      | destination                 | line | kind          |
      | Customers | customers.md                | 6    | relative      |
      | rev       | ../metrics/revenue.md#daily | 6    | relative      |
      | home      | https://example.com         | 7    | external      |
      | top       | #orders                     | 7    | anchor        |
      | gone      | /tables/returns.md          | 7    | bundle-rooted |

  Scenario: Backlinks, broken links and escapes
    When the bundle at "" is loaded
    Then the backlinks of "/tables/customers.md" are "/metrics/revenue.md, /tables/orders.md"
    And the broken links are "/metrics/revenue.md -> /../../spec/a.md, /tables/orders.md -> /tables/returns.md"
    And the link from "/metrics/revenue.md" to "/../../spec/a.md" escapes the bundle

  Scenario: Relative links from the bundle root
    Given the file "computations/revenue.md":
      """
      ---
      type: Attested Computation
      ---
      Run with [the skill](skills/run-on-bq.md).
      """
    And the file "skills/run-on-bq.md" with the text "---\ntype: Playbook\n---\n"
    And the options use the bundle root as the link base
    When the bundle at "" is loaded
    Then the backlinks of "/skills/run-on-bq.md" are "/computations/revenue.md"

  Scenario: Orphans without index links
    When the bundle at "" is loaded
    Then the orphans are "/tables/orders.md"

  Scenario: Index links count as backlinks
    Given index links count as backlinks
    When the bundle at "" is loaded
    Then the orphans are ""
