module lsp

pub struct HoverSettings {
	dynamic_registration bool     @[json: dynamicRegistration]
	content_format       []string @[json: contentFormat]
}

// method: ‘textDocument/hover’
// response: Hover | none
// request: TextDocumentPositionParams
pub struct HoverParams {
pub:
	text_document TextDocumentIdentifier @[json: textDocument]
	position      Position
}

// HoverResponseContent is kept for reference but we always emit MarkupContent
// so that clients like Zed can deserialise the response without errors.
// V's sum-type JSON encoding is non-standard and crashes LSP clients.
type HoverResponseContent = MarkedString | MarkupContent | []MarkedString | string

pub struct Hover {
pub:
	// Always MarkupContent (kind: markdown). Using the sum type here produces
	// non-standard JSON that kills the LSP connection in Zed.
	contents MarkupContent
	range    Range
}

// pub type MarkedString = string | MarkedString
pub struct MarkedString {
	language string
	value    string
}

pub fn hover_v_marked_string(text string) MarkupContent {
	return MarkupContent{
		kind:  markup_kind_markdown
		value: '```v\n${text}\n```'
	}
}

pub fn hover_markdown_string(text string) MarkupContent {
	return MarkupContent{
		kind:  markup_kind_markdown
		value: text
	}
}
