module server

// Tests for textDocument/prepareRename and textDocument/rename.
//
// Note: rename of public symbols and non-scope-bound symbols (functions,
// structs) requires a fully indexed workspace (stubs_index must be populated).
// These tests cover only the paths that work without indexing:
//   - prepareRename resolution and placeholder
//   - prepareRename highlight range is on the cursor line
//   - rename of local variables (scope-based search, no index required)

import lsp
import os
import analyzer
import analyzer.psi
import analyzer.parser

fn new_rename_ls() &LanguageServer {
	mut ls := LanguageServer.new(analyzer.IndexingManager.new())
	ls.setup_toolchain()
	ls.setup_vpaths()
	return ls
}

fn open_rename_file(mut ls LanguageServer, filename string, content string) lsp.DocumentUri {
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

fn test_prepare_rename_variable_placeholder() {
	mut ls := new_rename_ls()
	src := 'module main\n\nfn main() {\n\tmy_value := 42\n\tprintln(my_value)\n}\n'
	uri := open_rename_file(mut ls, 'prepare_rename_var.v', src)

	result := ls.prepare_rename(lsp.PrepareRenameParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		position:      lsp.Position{ line: 3, character: 1 }
	}) or {
		assert false, 'prepareRename should not fail for a variable: ${err}'
		return
	}
	assert result.placeholder == 'my_value', 'expected placeholder "my_value", got "${result.placeholder}"'
}

fn test_prepare_rename_function_placeholder() {
	mut ls := new_rename_ls()
	src := 'module main\n\nfn do_work() {}\n\nfn main() {\n\tdo_work()\n}\n'
	uri := open_rename_file(mut ls, 'prepare_rename_fn.v', src)

	result := ls.prepare_rename(lsp.PrepareRenameParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		position:      lsp.Position{ line: 2, character: 3 }
	}) or {
		assert false, 'prepareRename should not fail for a function name: ${err}'
		return
	}
	assert result.placeholder == 'do_work', 'expected placeholder "do_work", got "${result.placeholder}"'
}

fn test_prepare_rename_range_on_cursor_line() {
	mut ls := new_rename_ls()
	// Declaration on line 3, reference on line 4. Caret is on the reference.
	src := 'module main\n\nfn main() {\n\tmy_var := 42\n\tprintln(my_var)\n}\n'
	uri := open_rename_file(mut ls, 'prepare_rename_range.v', src)

	result := ls.prepare_rename(lsp.PrepareRenameParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		position:      lsp.Position{ line: 4, character: 9 }
	}) or { return }

	assert result.range.start.line == 4, 'range should start on the cursor line (4), got line ${result.range.start.line}'
}

fn test_rename_variable_all_occurrences() {
	mut ls := new_rename_ls()
	// counter: declaration (line 3), two increments (lines 4-5), println arg (line 6)
	src := 'module main\n\nfn main() {\n\tcounter := 0\n\tcounter++\n\tcounter++\n\tprintln(counter)\n}\n'
	uri := open_rename_file(mut ls, 'rename_var.v', src)

	edit := ls.rename(lsp.RenameParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		position:      lsp.Position{ line: 3, character: 1 }
		new_name:      'idx'
	}) or {
		assert false, 'rename should not fail: ${err}'
		return
	}

	edits := edit.changes[uri.str()]
	assert edits.len == 4, 'expected 4 rename edits (decl + 2 increments + println arg), got ${edits.len}'
	for e in edits {
		assert e.new_text == 'idx', 'expected new_text "idx", got "${e.new_text}"'
	}
}

fn test_rename_parameter_all_occurrences() {
	mut ls := new_rename_ls()
	// 'name' appears 3 times: parameter declaration + 2 uses in the body
	src := 'module main\n\nfn greet(name string) string {\n\treturn "hello " + name + " and " + name\n}\n'
	uri := open_rename_file(mut ls, 'rename_param.v', src)

	edit := ls.rename(lsp.RenameParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		position:      lsp.Position{ line: 2, character: 9 }
		new_name:      'person'
	}) or {
		assert false, 'rename should not fail: ${err}'
		return
	}

	edits := edit.changes[uri.str()]
	assert edits.len == 3, 'expected 3 rename edits (param decl + 2 uses), got ${edits.len}'
	for e in edits {
		assert e.new_text == 'person', 'expected new_text "person", got "${e.new_text}"'
	}
}
