module lsp

pub type InlineHintLabel = []InlayHintLabelPart | string

pub struct InlayHint {
pub:
	// The position of this hint.
	position Position
	// The label of this hint. A human readable string or an array of
	// InlayHintLabelPart label parts.
	//
	// *Note* that neither the string nor the label part can be empty.
	// We always emit a plain string so that every client (including Zed)
	// can deserialise it without errors. The sum-type produces non-standard
	// JSON that Zed cannot parse.
	label string
	// The kind of this hint. Can be omitted in which case the client
	// should fall back to a reasonable default.
	kind InlayHintKind
	// Optional text edits that are performed when accepting this inlay hint.
	//
	// *Note* that edits are expected to change the document so that the inlay
	// hint (or its nearest variant) is now part of the document and the inlay
	// hint itself is now obsolete.
	text_edits []TextEdit @[json: 'textEdits'; omitempty]
	// The tooltip text when you hover over this item.
	// LSP spec allows string | MarkupContent here; we always emit a plain
	// string so that every client (including Zed) can deserialise it without
	// errors.  The previous sum-type field produced a non-standard JSON shape
	// that Zed could not parse ("untagged enum InlayHintTooltip").
	tooltip string @[json: 'tooltip'; omitempty]
	// Render padding before the hint.
	padding_left bool @[json: 'paddingLeft'; omitempty]
	// Render padding after the hint.
	padding_right bool @[json: 'paddingRight'; omitempty]
	// A data entry field that is preserved on an inlay hint between
	// a `textDocument/inlayHint` and a `inlayHint/resolve` request.
	data string @[raw]
}

pub struct InlayHintClientCapabilities {
pub:
	// Whether inlay hints support dynamic registration.
	dynamic_registration bool @[json: 'dynamicRegistration']
	// Indicates which properties a client can resolve lazily on an inlay
	// hint.
	resolve_support bool @[json: 'resolveSupport']
}

@[json_as_number]
pub enum InlayHintKind {
	type_      = 1
	parameter  = 2
}

pub struct InlayHintLabelPart {
pub:
	// The value of this label part.
	value string
	// Tooltip as a plain string (see note on InlayHint.tooltip above).
	tooltip string @[omitempty]
	// An optional source code location that represents this label part.
	location Location @[omitempty]
	// An optional command for this label part.
	command Command @[omitempty]
}

// A parameter literal used in inlay hint requests.
//
// @since 3.17.0
pub struct InlayHintOptions {
pub:
	resolve_provider bool @[json: 'resolveProvider']
}

// A parameter literal used in inlay hint requests.
//
// @since 3.17.0
pub struct InlayHintParams {
pub:
	// The text document.
	text_document TextDocumentIdentifier @[json: 'textDocument']
	// The document range for which inlay hints should be computed.
	range Range
}
