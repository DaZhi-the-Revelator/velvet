module server

import lsp
import loglib
import analyzer.psi
import server.tform

pub fn (mut ls LanguageServer) prepare_rename(params lsp.PrepareRenameParams) !lsp.PrepareRenameResult {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri) or { return error('cannot rename element from not opened file') }

	offset := file.find_offset(params.position)
	// When text is pre-selected the editor may send a position at the end of
	// the selection (one past the last character of the token). Try the exact
	// offset first and fall back to offset-1 so we land inside the identifier.
	mut element := file.psi_file.find_element_at(offset) or {
		if offset > 0 {
			file.psi_file.find_element_at(offset - 1) or {
				loglib.with_fields({
					'offset': offset.str()
				}).warn('Cannot find element')
				return error('cannot find element at ' + offset.str())
			}
		} else {
			loglib.with_fields({
				'offset': offset.str()
			}).warn('Cannot find element')
			return error('cannot find element at ' + offset.str())
		}
	}

	// If the resolved element is not an Identifier (e.g. offset landed just
	// after the token boundary), retry one byte earlier.
	if element !is psi.Identifier && offset > 0 {
		if fallback := file.psi_file.find_element_at(offset - 1) {
			element = fallback
		}
	}

	if element !is psi.Identifier {
		return error('cannot rename non identifier element')
	}

	resolved := resolve_identifier(element)

	// Accept any named element as renameable, not just VarDefinition.
	// Use the identifier range at the cursor position (not the declaration
	// site) so the editor highlights the correct token for rename.
	if resolved is psi.PsiNamedElement {
		return lsp.PrepareRenameResult{
			range:       tform.text_range_to_lsp_range(element.text_range())
			placeholder: resolved.name()
		}
	}

	return error('cannot rename this element')
}

fn resolve_identifier(element psi.PsiElement) psi.PsiElement {
	parent := element.parent() or { return element }
	resolved := if parent is psi.ReferenceExpression {
		parent.resolve() or { return element }
	} else if parent is psi.TypeReferenceExpression {
		parent.resolve() or { return element }
	} else {
		parent
	}

	return resolved
}
