module server

import lsp
import loglib
import analyzer.psi
import server.tform
import analyzer.psi.search

pub fn (mut ls LanguageServer) rename(params lsp.RenameParams) !lsp.WorkspaceEdit {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri) or { return error('cannot rename element from not opened file') }

	offset := file.find_offset(params.position)
	// When text is already selected the editor sends a position at the end of
	// the selection. Step back one byte as a fallback so we land inside the
	// identifier token rather than past its end.
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

	references := search.references(element, include_declaration: true)

	// Group edits by source file URI so that renames touching multiple files
	// are applied correctly. Bundling all edits under the requesting file's URI
	// would silently skip any reference in a different file.
	mut changes := map[string][]lsp.TextEdit{}
	for ref in references {
		ref_file := ref.containing_file() or { continue }
		ref_uri := ref_file.uri().str()
		range := if ref is psi.PsiNamedElement {
			tform.text_range_to_lsp_range(ref.identifier_text_range())
		} else {
			tform.text_range_to_lsp_range(ref.text_range())
		}
		changes[ref_uri] << lsp.TextEdit{
			range:    range
			new_text: params.new_name
		}
	}

	return lsp.WorkspaceEdit{
		changes: changes
	}
}
