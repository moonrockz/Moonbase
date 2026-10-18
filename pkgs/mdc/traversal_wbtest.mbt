///|
test "walk handles a deeply nested constructed tree" {
  let mut block = @cmark.Block::empty()
  for _ in 0..<10000 {
    block = @cmark.Block::BlockQuote(
      @cmark.Node::new(@cmark.BlockQuote::new(block)),
    )
  }
  let mut count = 0
  walk(block_node(block), _ => {
    count += 1
    Continue
  })
  assert_eq(count, 10001)
}

///|
test "cmark export preserves parsed layout, locations and reference definitions" {
  let fixtures = [
    "", "# Heading\n\nparagraph with *em*, **strong**, ~~strike~~, ![alt][ref], [link](dest \"title\"), <https://example.com>, `code`, $math$ and <b>html</b>.\n\n[ref]: image.png \"title\"\n",
    "Heading\n=======\n\n> quote\n>\n> - [x] task\n> - item\n\n---\n", "```mbt\ncode\n```\n\n    indented\n\n$$\nmath\n$$\n\n<div>\nhtml\n</div>\n",
    "| head | right |\n| :--- | ---: |\n| *cell* | data |\n\n[^note]: footnote\n\nref[^note]\n",
    "soft\nbreak\\\nhard\n",
  ]
  for source in fixtures {
    let doc = Document::Document(source, strict=false, file="intent.mdc")
    assert_eq(@debug.to_string(doc.to_cmark()), @debug.to_string(doc.markdown))
  }
}
