///|
/// An immutable view into a document's Markdown block. Only the parser and
/// traversal create views; no mutable cmark value can be supplied by callers.
struct BlockView {
  block : @cmark.Block
} derive(Debug)

///|
pub extend BlockView with @debug.Debug::{to_repr}

///|
struct InlineView {
  inline : @cmark.Inline
} derive(Debug)

///|
pub extend InlineView with @debug.Debug::{to_repr}

///|
/// Block alternatives contain only immutable inspection data.
pub enum BlockKind {
  BlankLine
  BlockQuote
  Blocks
  CodeBlock
  Heading(level~ : Int32)
  HtmlBlock
  LinkRefDefinition
  List
  Paragraph
  ThematicBreak
  ExtMathBlock
  ExtTable
  ExtFootnoteDefinition
} derive(Eq, Debug)

///|
pub extend BlockKind with Eq::{equal, not_equal}

///|
pub extend BlockKind with @debug.Debug::{to_repr}

///|
pub enum InlineKind {
  Autolink
  Break
  CodeSpan(code~ : String)
  Emphasis
  Image
  Inlines
  Link
  RawHtml
  StrongEmphasis
  Text(text~ : String)
  ExtStrikethrough
  ExtMathSpan(tex~ : String)
} derive(Eq, Debug)

///|
pub extend InlineKind with Eq::{equal, not_equal}

///|
pub extend InlineKind with @debug.Debug::{to_repr}

///|
pub fn BlockView::kind(self : BlockView) -> BlockKind {
  match self.block {
    BlankLine(_) => BlankLine
    BlockQuote(_) => BlockQuote
    Blocks(_) => Blocks
    CodeBlock(_) => CodeBlock
    Heading({ v, .. }) => Heading(level=v.level)
    HtmlBlock(_) => HtmlBlock
    LinkRefDefinition(_) => LinkRefDefinition
    List(_) => List
    Paragraph(_) => Paragraph
    ThematicBreak(_) => ThematicBreak
    ExtMathBlock(_) => ExtMathBlock
    ExtTable(_) => ExtTable
    ExtFootnoteDefinition(_) => ExtFootnoteDefinition
  }
}

///|
pub fn InlineView::kind(self : InlineView) -> InlineKind {
  match self.inline {
    Autolink(_) => Autolink
    Break(_) => Break
    CodeSpan({ v, .. }) => CodeSpan(code=v.code())
    Emphasis(_) => Emphasis
    Image(_) => Image
    Inlines(_) => Inlines
    Link(_) => Link
    RawHtml(_) => RawHtml
    StrongEmphasis(_) => StrongEmphasis
    Text({ v, .. }) => Text(text=v)
    ExtStrikethrough(_) => ExtStrikethrough
    ExtMathSpan({ v, .. }) => ExtMathSpan(tex=v.tex())
  }
}

///|
pub fn BlockView::location(self : BlockView) -> @cmark_base.TextLoc {
  self.block.meta().loc
}

///|
pub fn InlineView::location(self : InlineView) -> @cmark_base.TextLoc {
  self.inline.meta().loc
}

///|
/// Export an owned cmark subtree. Mutating it cannot change the view or document.
/// Use `kind()` and `location()` for inspection without copying the subtree.
pub fn BlockView::to_cmark(self : BlockView) -> @cmark.Block {
  copy_block(self.block)
}

///|
/// Export an owned cmark subtree. Use `kind()` for inspection without copying.
pub fn InlineView::to_cmark(self : InlineView) -> @cmark.Inline {
  copy_inline(self.inline)
}
