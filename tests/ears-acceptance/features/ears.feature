Feature: Parse EARS specifications in text and documents
  Consumers read validated requirements without losing their source context.

  Scenario Outline: Recognize each EARS pattern
    Given the plain EARS source:
      """
      <source>
      """
    When the EARS specification is parsed
    Then there are 1 requirements and 0 diagnostics
    And the first requirement is "<pattern>"
    And the first requirement names "sensor" and requires "report temperature."

    Examples:
      | source                                                                          | pattern            |
      | The sensor shall report temperature.                                            | ubiquitous         |
      | While enabled, the sensor shall report temperature.                             | state driven       |
      | When polled, the sensor shall report temperature.                               | event driven       |
      | Where fitted, the sensor shall report temperature.                              | optional feature   |
      | If overheating, then the sensor shall report temperature.                       | unwanted behaviour |
      | Where fitted, while enabled, when polled, the sensor shall report temperature.  | complex            |

  Scenario: Keep valid requirements around a malformed sentence
    Given the plain EARS source:
      """
      The sensor shall report temperature.
      The sensor should reset.
      When polled, the sensor shall reply.
      """
    When the EARS specification is parsed
    Then there are 2 requirements and 1 diagnostics
    And the diagnostic reports a missing SHALL

  Scenario: Read formatted requirements in a Markdown list
    Given the Markdown EARS source:
      """
      # Requirements

      This paragraph explains the design.

      - When **polled**, the sensor shall
        report `temperature`.

      ```text
      The sensor shall be an example only.
      ```
      """
    When the EARS specification is parsed
    Then there are 1 requirements and 0 diagnostics
    And the first requirement is "event driven"
    And the first requirement names "sensor" and requires "report temperature."

  Scenario: Preserve frontmatter and original positions in an MDC document
    Given the existing MDC source:
      """
      ---
      title: Sensor
      ---
      # Requirements

      The sensor shall report temperature.
      """
    When the EARS specification is parsed
    Then there are 1 requirements and 0 diagnostics
    And the YAML payload remains "title: Sensor"
    And the first requirement starts on original line 6

  Scenario: Diagnose a malformed EARS candidate embedded in Markdown
    Given the Markdown EARS source:
      """
      The document describes a sensor.

      The sensor should reset.

      The sensor shall report temperature.
      """
    When the EARS specification is parsed
    Then there are 1 requirements and 1 diagnostics
    And the diagnostic reports a missing SHALL
