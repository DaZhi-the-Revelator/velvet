module lsp

// method: 'textDocument/selectionRange'
// response: []SelectionRange | none

pub struct SelectionRangeParams {
pub:
	text_document TextDocumentIdentifier @[json: 'textDocument']
	positions     []Position
}

pub struct SelectionRange {
pub mut:
	range  Range
	parent ?&SelectionRange @[omitempty]
}
