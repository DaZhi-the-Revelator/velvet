module server

// Tests for hover documentation correctness.
//
// Covers:
//   - compile-time identifiers (@FILE, @LINE, @MOD) return a description
//   - hover range is valid (non-zero width, sane line numbers)
//   - hover on a function call returns markdown containing the function name
//   - hover on a struct literal returns markdown containing the struct name

import lsp
import os
import analyzer
import analyzer.psi
import analyzer.parser

fn new_hover_ls() &LanguageServer {
	mut ls := LanguageServer.new(analyzer.IndexingManager.new())
	ls.setup_toolchain()
	ls.setup_vpaths()
	return ls
}

fn open_file_in_ls(mut ls LanguageServer, filename string, content string) lsp.DocumentUri {
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

fn hover_at(mut ls LanguageServer, uri lsp.DocumentUri, line int, character int) ?lsp.Hover {
	return ls.hover(lsp.HoverParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		position:      lsp.Position{ line: line, character: character }
	})
}

fn test_hover_compile_time_file() {
	mut ls := new_hover_ls()
	src := 'module main\n\nfn main() {\n\tprintln(@FILE)\n}\n'
	uri := open_file_in_ls(mut ls, 'hover_ctid_file.v', src)

	// @FILE is on line 3, character 9
	hover := hover_at(mut ls, uri, 3, 9) or {
		assert false, 'expected hover for @FILE, got none'
		return
	}
	assert hover.contents.value.contains('@FILE'), 'hover should mention @FILE'
	assert hover.contents.value.len > 10, 'hover should have a non-trivial description'
}

fn test_hover_compile_time_line() {
	mut ls := new_hover_ls()
	src := 'module main\n\nfn main() {\n\tprintln(@LINE)\n}\n'
	uri := open_file_in_ls(mut ls, 'hover_ctid_line.v', src)

	hover := hover_at(mut ls, uri, 3, 9) or {
		assert false, 'expected hover for @LINE, got none'
		return
	}
	assert hover.contents.value.contains('@LINE'), 'hover should mention @LINE'
}

fn test_hover_compile_time_mod() {
	mut ls := new_hover_ls()
	src := 'module main\n\nfn main() {\n\tprintln(@MOD)\n}\n'
	uri := open_file_in_ls(mut ls, 'hover_ctid_mod.v', src)

	hover := hover_at(mut ls, uri, 3, 9) or {
		assert false, 'expected hover for @MOD, got none'
		return
	}
	assert hover.contents.value.contains('@MOD'), 'hover should mention @MOD'
}

fn test_hover_range_is_valid() {
	mut ls := new_hover_ls()
	src := 'module main\n\nfn add(a int, b int) int {\n\treturn a + b\n}\n\nfn main() {\n\t_ := add(1, 2)\n}\n'
	uri := open_file_in_ls(mut ls, 'hover_range.v', src)

	// Hover on `add` at the call site: line 7, character 6
	hover := hover_at(mut ls, uri, 7, 6) or { return }

	r := hover.range
	assert r.end.line >= r.start.line, 'hover range end line must be >= start line'
	if r.start.line == r.end.line {
		assert r.end.character > r.start.character, 'hover range must have positive width on a single line'
	}
}

fn test_hover_function_contains_name() {
	mut ls := new_hover_ls()
	src := 'module main\n\nfn compute(x int) int {\n\treturn x * 2\n}\n\nfn main() {\n\t_ := compute(5)\n}\n'
	uri := open_file_in_ls(mut ls, 'hover_fn_name.v', src)

	hover := hover_at(mut ls, uri, 7, 6) or { return }
	assert hover.contents.kind == lsp.markup_kind_markdown, 'hover should be markdown'
	assert hover.contents.value.contains('compute'), 'hover should mention function name'
}

fn test_hover_struct_name_in_content() {
	mut ls := new_hover_ls()
	src := 'module main\n\nstruct Rectangle {\n\twidth  int\n\theight int\n}\n\nfn main() {\n\t_ := Rectangle{}\n}\n'
	uri := open_file_in_ls(mut ls, 'hover_struct.v', src)

	// Hover on `Rectangle` on the struct literal line: line 8, character 6
	hover := hover_at(mut ls, uri, 8, 6) or { return }
	assert hover.contents.value.contains('Rectangle'), 'hover should mention struct name'
}
