Feature: OKF editing
  Edits change only the intended text, and plans group edits until a caller
  applies them.

  Scenario: Set a key in a CRLF file
    Given the text "---\r\ntype: Metric\r\nstatus: draft\r\n---\r\nBody\r\n"
    When the key "status" is set to "stable"
    Then the text is "---\r\ntype: Metric\r\nstatus: stable\r\n---\r\nBody\r\n"
    And the text changed

  Scenario: Setting an equal value changes nothing
    Given the text "---\ntype: Metric\nstatus: stable\n---\n"
    When the key "status" is set to "stable"
    Then the text did not change

  Scenario: A value that needs quotes
    Given the text "---\ntype: A\n---\n"
    When the key "title" is set to "Revenue: net"
    Then the text is "---\ntype: A\ntitle: \"Revenue: net\"\n---\n"

  Scenario: Plan a new concept
    Given the file "index.md" with the text "---\nokf_version: \"0.2\"\n---\n# Table\n"
    And the file "log.md" with the text "# Log\n"
    When the bundle at "" is loaded
    And the concept "/metrics/revenue.md" of type "Metric" titled "Revenue" is planned on "2026-10-23"
    Then the plan changes "metrics/revenue.md, index.md, log.md"
    And nothing is written

  Scenario: A reserved path is refused
    Given the file "index.md" with the text "---\nokf_version: \"0.2\"\n---\n"
    When the bundle at "" is loaded
    And the concept "/tables/index.md" of type "Table" titled "Bad" is planned on "2026-10-23"
    Then the plan is refused because "index.md is a reserved name"
