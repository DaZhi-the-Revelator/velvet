module server

import lsp
import loglib
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
	edits := tform.elements_to_text_edits(references, params.new_name)

	return lsp.WorkspaceEdit{
		changes: {
			uri: edits
		}
	}
}
