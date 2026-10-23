Feature: OKF validation
  Validation reports sorted findings from the OKF v0.2 conformance rules and
  from advisory rules, with severities and rules that the caller chooses.

  Background:
    Given the file "index.md":
      """
      ---
      okf_version: "0.2"
      ---
      # Table

      * [Orders](/tables/orders.md) - Orders
      """
    And the file "tables/orders.md":
      """
      ---
      type: Table
      title: Orders
      description: Orders
      ---
      See [returns](/tables/returns.md).
      """
    And the clock is "2026-10-23T00:00:00Z"

  Scenario: A conformant bundle with a broken link has no error
    When the knowledge at "" is validated
    Then there are no errors
    And the findings are:
      | severity | rule        | path              |
      | warning  | link-broken | /tables/orders.md |

  Scenario: A concept without a type is an error
    Given the file "tables/customers.md" with the text "---\ntype: \"\"\n---\n"
    When the knowledge at "" is validated
    Then the findings include "error concept-missing-type /tables/customers.md"

  Scenario: Severity overrides, turned-off rules and strict mode
    Given the rule "link-broken" has the severity "error"
    And the rule "concept-not-indexed" is turned off
    When the knowledge at "" is validated
    Then the findings are:
      | severity | rule        | path              |
      | error    | link-broken | /tables/orders.md |
    And the result fails

  Scenario: Warnings fail only in strict mode
    When the knowledge at "" is validated
    Then the result passes
    And the result fails in strict mode

  Scenario: Staleness uses the supplied clock
    Given the file "tables/old.md" with the text "---\ntype: Table\ntitle: Old\ndescription: Old\nstale_after: 2026-01-01T00:00:00Z\n---\n"
    When the knowledge at "" is validated
    Then the findings include "warning stale-after-passed /tables/old.md"
