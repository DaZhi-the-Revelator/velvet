module server

import lsp
import analyzer.psi
import server.documentation
import server.completion.providers as compl_providers
import loglib
import server.tform

pub fn (mut ls LanguageServer) hover(params lsp.HoverParams) ?lsp.Hover {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri)?

	loglib.with_fields({
		'position': params.position.str()
		'uri':      file.uri
	}).warn('Hover request')

	offset := file.find_offset(params.position)
	element := file.psi_file.find_element_at(offset) or {
		loglib.with_fields({
			'offset': offset.str()
		}).warn('Cannot find element')
		return none
	}

	// Hover for @FILE, @LINE, @MOD … (pseudo_compile_time_identifier nodes)
	if element.node().type_name == .pseudo_compile_time_identifier {
		token := element.get_text().trim_string_left('@')
		if description := compl_providers.compile_time_constant[token] {
			return lsp.Hover{
				contents: lsp.hover_markdown_string('**${element.get_text()}**\n\n${description}')
				range:    tform.text_range_to_lsp_range(element.text_range())
			}
		}
		return none
	}

	if element.element_type() == .unknown {
		mut provider := documentation.KeywordProvider{}
		if content := provider.documentation(element) {
			return lsp.Hover{
				contents: lsp.hover_markdown_string(content)
				range:    tform.text_range_to_lsp_range(element.text_range())
			}
		}
	}

	mut provider := documentation.Provider{}
	doc_element := provider.find_documentation_element(element)?
	if content := provider.documentation(doc_element) {
		// The hover range must always be expressed in the *current* file's
		// coordinates (where the cursor is), never the declaration file's.
		//
		// The old code used doc_element.identifier_text_range() unconditionally.
		// When doc_element lives in a different file its line/column numbers are
		// valid in *that* file, but the editor interprets them relative to the
		// file currently open — so the popup appeared at a random position
		// (often the top of the window).
		//
		// Fix: only use the declaration's identifier range when the declaration
		// is in the same file as the hovered token; otherwise anchor to the
		// hovered element itself.
		hover_range := tform.text_range_to_lsp_range(hover_anchor_range(element, doc_element))
		return lsp.Hover{
			contents: lsp.hover_markdown_string(content)
			range:    hover_range
		}
	}

	$if show_ast_on_hover ? {
		// Show AST tree for debugging purposes.
		if grand := element.parent_nth(2) {
			parent := element.parent()?
			this := element.type_name() + ': ' + element.node().type_name.str()
			parent_elem := parent.type_name() + ': ' + parent.node().type_name.str()
			grand_elem := grand.type_name() + ': ' + grand.node().type_name.str()
			return lsp.Hover{
				contents: lsp.hover_markdown_string('```\n' + grand_elem + '\n  ' + parent_elem +
					'\n   ' + this + '\n```')
				range:    tform.text_range_to_lsp_range(element.text_range())
			}
		}

		return lsp.Hover{
			contents: lsp.hover_markdown_string(element.type_name() + ': ' +
				element.node().type_name.str())
			range:    tform.text_range_to_lsp_range(element.text_range())
		}
	}

	return none
}

// hover_anchor_range returns the TextRange to use as the LSP hover anchor.
//
// We want to highlight the exact identifier the user hovered when possible,
// but the range must be in the *current* file's coordinate space.
//
// - If the declaration is in the same file: use its identifier span (narrow).
// - If the declaration is in a different file (stdlib, other module, stubs):
//   use the hovered element's own span, which is always in the current file.
//
// Both parameters are psi.PsiElement so we can call containing_file() on both.
// We then check whether doc_element also satisfies PsiNamedElement to get the
// identifier range.
fn hover_anchor_range(element psi.PsiElement, doc_element psi.PsiElement) psi.TextRange {
	element_path := if ef := element.containing_file() { ef.path } else { '' }
	doc_path := if df := doc_element.containing_file() { df.path } else { '' }

	if element_path != '' && element_path == doc_path {
		// Same file: narrow to the declaration's identifier span if possible.
		if doc_element is psi.PsiNamedElement {
			return doc_element.identifier_text_range()
		}
		return doc_element.text_range()
	}

	// Different file: anchor to the hovered token in the current file.
	return element.text_range()
}
