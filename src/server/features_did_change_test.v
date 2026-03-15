module server

// Tests for textDocument/didChange.

import lsp
import os
import analyzer
import analyzer.psi
import analyzer.parser

fn new_didchange_ls() &LanguageServer {
	mut ls := LanguageServer.new(analyzer.IndexingManager.new())
	ls.setup_toolchain()
	ls.setup_vpaths()
	return ls
}

fn open_didchange_file(mut ls LanguageServer, filename string, content string) lsp.DocumentUri {
	uri := lsp.document_uri_from_path(os.join_path(os.vtmp_dir(), filename))
	abs := uri.path()
	os.write_file(abs, content) or {}

	mut p := parser.Parser.new()
	defer { p.free() }
	res := p.parse_code(content)
	psi_file := psi.new_psi_file(abs, res.tree, res.source_text)
	ls.opened_files[uri] = analyzer.OpenedFile{
		uri:      uri
		version:  0
		psi_file: psi_file
	}
	return uri
}

fn send_did_change(mut ls LanguageServer, uri lsp.DocumentUri, new_content string) {
	ls.did_change(lsp.DidChangeTextDocumentParams{
		text_document:   lsp.VersionedTextDocumentIdentifier{
			uri:     uri
			version: 2
		}
		content_changes: [lsp.TextDocumentContentChangeEvent{ text: new_content }]
	})
}

fn test_did_change_updates_source_text() {
	mut ls := new_didchange_ls()
	src := 'module main\n\nfn main() {\n\tx := 1\n}\n'
	uri := open_didchange_file(mut ls, 'didchange_update.v', src)

	new_content := 'module main\n\nfn main() {\n\tx := 999\n}\n'
	send_did_change(mut ls, uri, new_content)

	file := ls.get_file(uri) or {
		assert false, 'file should still be tracked after didChange'
		return
	}
	assert file.psi_file.source_text == new_content, 'source_text should reflect the new content after didChange'
}

fn test_did_change_version_increments() {
	mut ls := new_didchange_ls()
	src := 'module main\n\nfn main() {}\n'
	uri := open_didchange_file(mut ls, 'didchange_version.v', src)

	file_before := ls.get_file(uri) or {
		assert false, 'file should be open'
		return
	}
	version_before := file_before.version

	send_did_change(mut ls, uri, 'module main\n\nfn main() {\n\ty := 1\n}\n')

	file_after := ls.get_file(uri) or {
		assert false, 'file should still be open after didChange'
		return
	}
	assert file_after.version > version_before, 'version should increment after didChange'
}

fn test_did_change_unopened_file_no_crash() {
	mut ls := new_didchange_ls()

	ghost_uri := lsp.document_uri_from_path(os.join_path(os.vtmp_dir(), 'velvet_ghost_xyz_never_opened.v'))
	ls.did_change(lsp.DidChangeTextDocumentParams{
		text_document:   lsp.VersionedTextDocumentIdentifier{
			uri:     ghost_uri
			version: 1
		}
		content_changes: [lsp.TextDocumentContentChangeEvent{ text: 'module main\n' }]
	})

	// Server must remain functional after the spurious change.
	src := 'module main\n\nfn main() {}\n'
	uri := open_didchange_file(mut ls, 'didchange_alive.v', src)
	_ := ls.get_file(uri) or {
		assert false, 'server should remain functional after spurious didChange'
		return
	}
}
