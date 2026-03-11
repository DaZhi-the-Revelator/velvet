module server

import lsp
import loglib
import analyzer
import analyzer.psi

pub fn (mut ls LanguageServer) did_open(params lsp.DidOpenTextDocumentParams) {
	src := params.text_document.text
	uri := params.text_document.uri.normalize()

	res := ls.main_parser.parse_code(src)
	psi_file := psi.new_psi_file(uri.path(), res.tree, res.source_text)

	ls.opened_files[uri] = analyzer.OpenedFile{
		uri:      uri
		version:  0
		psi_file: psi_file
	}

	// Index the opened file's symbols so that resolution (e.g. for parameter
	// name hints and implicit-err hints) works immediately on first open,
	// without requiring the user to make an edit to trigger did_change.
	if file_index := ls.indexing_mng.indexer.add_file(uri.path()) {
		if !isnil(file_index.sink) {
			ls.indexing_mng.update_stub_indexes_from_sinks([*file_index.sink])
		}
	}

	if 'no-diagnostics' !in ls.initialization_options {
		ls.run_diagnostics_in_bg(uri)
	}

	// Useful for debugging
	//
	// mut visitor := psi.PrinterVisitor{}
	// psi_file.root().accept_mut(mut visitor)
	// visitor.print()
	//
	// tree := index.build_stub_tree(psi_file, '')
	// tree.print()

	loglib.with_fields({
		'uri':              uri.str()
		'opened_files len': ls.opened_files.len.str()
	}).info('Opened file')
}
