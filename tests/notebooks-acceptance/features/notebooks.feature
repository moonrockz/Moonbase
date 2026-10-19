Feature: Navigate notebooks through common and specialized APIs
  Shared traversal keeps each format's concrete nodes available to callers.

  Scenario: Navigate a polyglot DIB notebook and inspect its directives
    Given the DIB source:
      """dib
      #!meta
      {"title":"Polyglot","kernelInfo":{"defaultKernelName":"csharp","items":[{"name":"custom","aliases":["alt"]}]}}
      #!md
      # Results
      #!c#
      #!share --from fsharp x
      Console.WriteLine(x);
      #!alt
      example()
      """
    When the notebook is parsed
    Then the common cell kinds are "markdown,code,code"
    And common cursor paths resolve to their concrete nodes
    And the specialized directive is "share" with arguments "--from fsharp x"
    And the custom kernel alias finds source "example()"
    And the DIB source round-trips

  Scenario: Navigate a Jupyter notebook and inspect its outputs
    Given the Jupyter JSON:
      """json
      {"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[
        {"id":"intro","cell_type":"markdown","metadata":{},"source":"# Results","attachments":{"plot.png":{"image/png":"YWJj"}}},
        {"id":"calculation","cell_type":"code","metadata":{},"source":"1 + 1","execution_count":1,"outputs":[{"output_type":"stream","name":"stdout","text":"2"}]}]}
      """
    When the notebook is parsed
    Then the common cell kinds are "markdown,code"
    And common cursor paths resolve to their concrete nodes
    And specialized Jupyter navigation finds the stream and attachment

  Scenario: Keep executable directives inside their cell
    Given the DIB source:
      """dib
      #!csharp
      #!connect named-pipe --kernel-name external
      #!external -h
      #!fsharp
      let x = 1
      """
    When the notebook is parsed
    Then the common cell kinds are "code,code"
    And common cursor paths resolve to their concrete nodes
    And the first DIB cell has 2 directives
