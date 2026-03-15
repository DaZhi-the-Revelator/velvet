module server

// Tests for textDocument/selectionRange.

import lsp
import os
import analyzer
import analyzer.psi
import analyzer.parser

fn new_selrange_ls() &LanguageServer {
	mut ls := LanguageServer.new(analyzer.IndexingManager.new())
	ls.setup_toolchain()
	ls.setup_vpaths()
	return ls
}

fn open_selrange_file(mut ls LanguageServer, filename string, content string) lsp.DocumentUri {
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

fn sel_range_at(mut ls LanguageServer, uri lsp.DocumentUri, positions []lsp.Position) ?[]lsp.SelectionRange {
	return ls.selection_range(lsp.SelectionRangeParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		positions:     positions
	})
}

fn test_selection_range_returns_result() {
	mut ls := new_selrange_ls()
	src := 'module main\n\nfn main() {\n\tx := 1 + 2\n}\n'
	uri := open_selrange_file(mut ls, 'selrange_basic.v', src)

	results := sel_range_at(mut ls, uri, [lsp.Position{ line: 3, character: 9 }]) or {
		assert false, 'selectionRange should not return none for a valid position'
		return
	}
	assert results.len > 0, 'expected at least one SelectionRange result'
}

fn test_selection_range_innermost_contains_cursor() {
	mut ls := new_selrange_ls()
	src := 'module main\n\nfn main() {\n\tmy_variable := 100\n\t_ := my_variable + 1\n}\n'
	uri := open_selrange_file(mut ls, 'selrange_cursor.v', src)

	pos := lsp.Position{ line: 4, character: 6 }
	results := sel_range_at(mut ls, uri, [pos]) or {
		assert false, 'selectionRange should not return none'
		return
	}
	assert results.len > 0, 'no results returned'

	r := results[0].range
	assert r.start.line <= pos.line, 'innermost range start line (${r.start.line}) must be <= cursor line (${pos.line})'
	assert r.end.line >= pos.line, 'innermost range end line (${r.end.line}) must be >= cursor line (${pos.line})'
}

fn test_selection_range_parent_not_smaller_than_child() {
	mut ls := new_selrange_ls()
	src := 'module main\n\nfn main() {\n\tresult := (1 + 2) * 3\n}\n'
	uri := open_selrange_file(mut ls, 'selrange_nesting.v', src)

	results := sel_range_at(mut ls, uri, [lsp.Position{ line: 3, character: 15 }]) or {
		assert false, 'selectionRange should not return none'
		return
	}
	assert results.len > 0, 'no results returned'

	// Walk the chain iteratively without mutable pointer reassignment.
	// Collect all ranges from innermost to outermost, capped at 64 levels.
	mut ranges := []lsp.Range{}
	ranges << results[0].range
	mut node := &results[0]
	for _ in 0 .. 64 {
		parent := node.parent or { break }
		ranges << parent.range
		node = parent
	}

	// Verify each consecutive pair: ranges[i] is child, ranges[i+1] is parent.
	for i in 0 .. ranges.len - 1 {
		child  := ranges[i]
		parent := ranges[i + 1]
		c_start := child.start.line  * 100000 + child.start.character
		c_end   := child.end.line    * 100000 + child.end.character
		p_start := parent.start.line * 100000 + parent.start.character
		p_end   := parent.end.line   * 100000 + parent.end.character
		assert p_start <= c_start, 'parent range start must be <= child range start at depth ${i}'
		assert p_end   >= c_end,   'parent range end must be >= child range end at depth ${i}'
	}
}

fn test_selection_range_multiple_positions() {
	mut ls := new_selrange_ls()
	src := 'module main\n\nfn main() {\n\ta := 1\n\tb := 2\n\tc := a + b\n}\n'
	uri := open_selrange_file(mut ls, 'selrange_multi.v', src)

	positions := [
		lsp.Position{ line: 3, character: 1 },
		lsp.Position{ line: 4, character: 1 },
	]
	results := sel_range_at(mut ls, uri, positions) or {
		assert false, 'selectionRange should not return none'
		return
	}
	assert results.len == 2, 'expected 2 results for 2 positions, got ${results.len}'
}
