///|
// Cmark sequences and definition maps are mutable. Copy every container at the
// interoperability boundary. Scalars, strings and parser-created metadata are
// immutable and can be shared. These helpers only receive our private parsed AST.
fn copy_doc(doc : @cmark.Doc) -> @cmark.Doc {
  let defs = Map([])
  for key, definition in doc.defs {
    defs[key] = match definition {
      LinkDef(node) => @cmark.LabelDef::LinkDef(node.map(copy_link_definition))
      FootnoteDef(node) => @cmark.LabelDef::FootnoteDef(node.map(copy_footnote))
    }
  }
  { ..doc, block: copy_block(doc.block), defs, }
}

///|
fn copy_label(label : @cmark.Label) -> @cmark.Label {
  { ..label, text: label.text.map(x => x), }
}

///|
fn copy_link_definition(value : @cmark.LinkDefinition) -> @cmark.LinkDefinition {
  {
    ..value,
    layout: {
      ..value.layout,
      before_dest: value.layout.before_dest.map(x => x),
      after_dest: value.layout.after_dest.map(x => x),
    },
    label: value.label.map(copy_label),
    defined_label: value.defined_label.map(copy_label),
    title: value.title.map(title => title.map(x => x)),
  }
}

///|
fn copy_link(value : @cmark.InlineLink) -> @cmark.InlineLink {
  {
    text: copy_inline(value.text),
    reference: match value.reference {
      Inline(node) =>
        @cmark.ReferenceKind::Inline(node.map(copy_link_definition))
      Ref(layout, label, defined_label) =>
        @cmark.ReferenceKind::Ref(
          layout,
          copy_label(label),
          copy_label(defined_label),
        )
    },
  }
}

///|
fn copy_inline(inline : @cmark.Inline) -> @cmark.Inline {
  match inline {
    Autolink(_) | Break(_) | Text(_) => inline
    CodeSpan(node) =>
      @cmark.Inline::CodeSpan(
        node.map(value => {
          ..value,
          code_layout: value.code_layout.map(x => x),
        }),
      )
    Emphasis(node) =>
      @cmark.Inline::Emphasis(
        node.map(value => { ..value, inline: copy_inline(value.inline), }),
      )
    StrongEmphasis(node) =>
      @cmark.Inline::StrongEmphasis(
        node.map(value => { ..value, inline: copy_inline(value.inline), }),
      )
    Link(node) => @cmark.Inline::Link(node.map(copy_link))
    Image(node) => @cmark.Inline::Image(node.map(copy_link))
    Inlines(node) =>
      @cmark.Inline::Inlines(node.map(values => values.map(copy_inline)))
    RawHtml(node) =>
      @cmark.Inline::RawHtml(
        node.map(value => @cmark.InlineRawHtml(value.0.map(x => x))),
      )
    ExtStrikethrough(node) =>
      @cmark.Inline::ExtStrikethrough(
        node.map(value => @cmark.InlineStrikethrough(copy_inline(value.0))),
      )
    ExtMathSpan(node) =>
      @cmark.Inline::ExtMathSpan(
        node.map(value => { ..value, tex_layout: value.tex_layout.map(x => x), }),
      )
  }
}

///|
fn copy_code(value : @cmark.CodeBlock) -> @cmark.CodeBlock {
  { ..value, code: value.code.map(x => x), }
}

///|
fn copy_footnote(value : @cmark.Footnote) -> @cmark.Footnote {
  {
    ..value,
    label: copy_label(value.label),
    defined_label: value.defined_label.map(copy_label),
    block: copy_block(value.block),
  }
}

///|
fn copy_row(value : @cmark.TableRow) -> @cmark.TableRow {
  match value {
    Header(cells) =>
      @cmark.TableRow::Header(cells.map(cell => (copy_inline(cell.0), cell.1)))
    Data(cells) =>
      @cmark.TableRow::Data(cells.map(cell => (copy_inline(cell.0), cell.1)))
    Sep(cells) => @cmark.TableRow::Sep(cells.map(x => x))
  }
}

///|
fn copy_block(block : @cmark.Block) -> @cmark.Block {
  match block {
    BlankLine(_) | ThematicBreak(_) => block
    Blocks(node) =>
      @cmark.Block::Blocks(node.map(values => values.map(copy_block)))
    BlockQuote(node) =>
      @cmark.Block::BlockQuote(
        node.map(value => { ..value, block: copy_block(value.block), }),
      )
    CodeBlock(node) => @cmark.Block::CodeBlock(node.map(copy_code))
    ExtMathBlock(node) => @cmark.Block::ExtMathBlock(node.map(copy_code))
    Heading(node) =>
      @cmark.Block::Heading(
        node.map(value => { ..value, inline: copy_inline(value.inline), }),
      )
    Paragraph(node) =>
      @cmark.Block::Paragraph(
        node.map(value => { ..value, inline: copy_inline(value.inline), }),
      )
    HtmlBlock(node) =>
      @cmark.Block::HtmlBlock(
        node.map(value => @cmark.HtmlBlock(value.0.map(x => x))),
      )
    LinkRefDefinition(node) =>
      @cmark.Block::LinkRefDefinition(node.map(copy_link_definition))
    List(node) =>
      @cmark.Block::List(
        node.map(value => {
          ..value,
          items: value.items.map(item => {
            item.map(value => { ..value, block: copy_block(value.block), })
          }),
        }),
      )
    ExtFootnoteDefinition(node) =>
      @cmark.Block::ExtFootnoteDefinition(node.map(copy_footnote))
    ExtTable(node) =>
      @cmark.Block::ExtTable(
        node.map(value => {
          ..value,
          rows: value.rows.map(row => (row.0.map(copy_row), row.1)),
        }),
      )
  }
}
