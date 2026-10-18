Feature: Markdown documents with frontmatter
  Consumers can read intent metadata and Markdown through immutable views.
  Exports let cmark consumers transform their own copy.

  Scenario: Read metadata and Markdown from one document
    Given the MDC source:
      """
      ---
      title: Goal
      active: true
      ---
      # Goal

      ## Steps
      """
    When the source is parsed
    Then the metadata is:
      """json
      {"title":"Goal","active":true}
      """
    And the Markdown body is:
      """
      # Goal

      ## Steps
      """
    And the heading levels are "1,2"
    And the body starts on line 5

  Scenario: Ordinary Markdown needs no header
    Given the MDC source:
      """
      # Goal

      A **useful** goal.
      """
    When the source is parsed
    Then there is no frontmatter
    And the body is the complete source

  Scenario: An empty header is an empty metadata mapping
    Given the MDC source:
      """
      ---
      ---
      # Goal
      """
    When the source is parsed
    Then the metadata is:
      """json
      {}
      """
    And the heading levels are "1"

  Scenario: An open header must be closed
    Given the MDC source:
      """
      ---
      title: Goal
      """
    When the source is parsed
    Then the header is reported as unterminated

  Scenario: Metadata must be a mapping
    Given the MDC source:
      """
      ---
      - Goal
      ---
      """
    When the source is parsed
    Then invalid frontmatter is reported at line 2 and column 1

  Scenario: Invalid YAML points into the original source
    Given the MDC source:
      """
      ---
      title: ]
      ---
      """
    When the source is parsed
    Then invalid frontmatter is reported at line 2 and column 8

  Scenario: Exporting mutable YAML and cmark trees leaves the document unchanged
    Given the MDC source:
      """
      ---
      title: Goal
      ---
      # Goal

      A **useful** goal.

      [ref]: https://example.com
      """
    When the source is parsed
    And the exported metadata and Markdown are changed
    Then the metadata is:
      """json
      {"title":"Goal"}
      """
    And the heading levels are "1"
    And the document still contains "GoalA useful goal."

  Scenario: Visitors and folders see the same document order
    Given the MDC source:
      """
      ---
      title: Goal
      ---
      # Goal

      > A **nested** goal.
      """
    When the source is parsed
    Then visitor, walk and fold observe the same text
    And pruning block quotes hides their contents

  Scenario: Navigate nodes without changing a saved cursor position
    Given the MDC source:
      """
      ---
      title: Goal
      ---
      # Goal
      """
    When the source is parsed
    Then cursors can navigate metadata, parents and siblings
    And subtree operations retain their original navigation context

  Scenario: Cursor visitors and folders can inspect ancestors during traversal
    Given the MDC source:
      """
      ---
      title: Goal
      ---
      # Goal

      > A **nested** goal.
      """
    When the source is parsed
    Then cursor visitor, walk and fold observe the same positions

  Scenario: Reduce immediate child results before their parents
    Given the MDC source:
      """
      # First

      ## Second
      """
    When the source is parsed
    Then bottom-up reduction composes "FirstSecond" in document order

  Scenario: Implement fold and reduction behavior on an immutable consumer type
    Given the MDC source:
      """
      # Goal

      > A **nested** goal.
      """
    When the source is parsed
    Then consumer traits fold with pruning and reduce complete child results

  Scenario: Implement cursor traits for navigation within a saved subtree
    Given the MDC source:
      """
      ---
      title: Goal
      ---
      # Goal

      > A **nested** goal.
      """
    When the source is parsed
    Then consumer cursor traits preserve saved subtree paths
