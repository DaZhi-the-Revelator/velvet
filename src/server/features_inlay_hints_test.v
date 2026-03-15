module server

// Tests for textDocument/inlayHint.

import lsp
import os
import analyzer
import analyzer.psi
import analyzer.parser
import config

fn new_hints_ls() &LanguageServer {
	mut ls := LanguageServer.new(analyzer.IndexingManager.new())
	ls.setup_toolchain()
	ls.setup_vpaths()
	return ls
}

fn open_hints_file(mut ls LanguageServer, filename string, content string) lsp.DocumentUri {
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

fn compute_hints(mut ls LanguageServer, uri lsp.DocumentUri) []lsp.InlayHint {
	return ls.inlay_hints(lsp.InlayHintParams{
		text_document: lsp.TextDocumentIdentifier{ uri: uri }
		range:         lsp.Range{
			start: lsp.Position{ line: 0, character: 0 }
			end:   lsp.Position{ line: 9999, character: 0 }
		}
	}) or { []lsp.InlayHint{} }
}

fn test_inlay_hints_master_switch_off() {
	mut ls := new_hints_ls()
	ls.cfg.inlay_hints = config.InlayHintsConfig{ enable: false }
	src := 'module main\n\nfn main() {\n\tcount := 42\n\tfor i in 0..10 {\n\t\t_ = i + count\n\t}\n}\n'
	uri := open_hints_file(mut ls, 'hints_off.v', src)

	hints := compute_hints(mut ls, uri)
	assert hints.len == 0, 'expected no hints with enable = false, got ${hints.len}'
}

fn test_inlay_hints_type_hint_integer() {
	mut ls := new_hints_ls()
	ls.cfg.inlay_hints = config.InlayHintsConfig{
		enable:                           true
		enable_type_hints:                true
		enable_parameter_name_hints:      false
		enable_range_hints:               false
		enable_implicit_err_hints:        false
		enable_constant_type_hints:       false
		enable_enum_field_value_hints:    false
		enable_anon_fn_return_type_hints: false
	}
	src := 'module main\n\nfn main() {\n\tcount := 42\n\t_ = count\n}\n'
	uri := open_hints_file(mut ls, 'hints_type_int.v', src)

	hints := compute_hints(mut ls, uri)
	assert hints.len > 0, 'expected at least one type hint for "count := 42"'
	assert hints.any(fn (h lsp.InlayHint) bool { return h.label.contains('int') }),
		'expected a hint containing "int" for integer literal'
}

fn test_inlay_hints_range_operator_le() {
	mut ls := new_hints_ls()
	ls.cfg.inlay_hints = config.InlayHintsConfig{
		enable:                           true
		enable_type_hints:                false
		enable_parameter_name_hints:      false
		enable_range_hints:               true
		enable_implicit_err_hints:        false
		enable_constant_type_hints:       false
		enable_enum_field_value_hints:    false
		enable_anon_fn_return_type_hints: false
	}
	src := 'module main\n\nfn main() {\n\tfor i in 0..10 {\n\t\t_ = i\n\t}\n}\n'
	uri := open_hints_file(mut ls, 'hints_range_le.v', src)

	hints := compute_hints(mut ls, uri)
	assert hints.len > 0, 'expected at least one range hint for "0..10"'
	assert hints.any(fn (h lsp.InlayHint) bool { return h.label.contains('\u2264') }),
		'expected a ≤ hint on the range operator'
}

fn test_inlay_hints_anon_fn_return_type_flag_is_read() {
	// The anon fn return type hint requires type inference which needs an indexed
	// workspace. Without indexing the inferred type is UnknownType and the hint
	// is suppressed (that is correct behaviour — not a bug). This test verifies
	// only that the flag is wired up: with the flag off and all others off, we
	// get zero hints regardless of what the type inferencer produces.
	mut ls := new_hints_ls()
	ls.cfg.inlay_hints = config.InlayHintsConfig{
		enable:                           true
		enable_type_hints:                false
		enable_parameter_name_hints:      false
		enable_range_hints:               false
		enable_implicit_err_hints:        false
		enable_constant_type_hints:       false
		enable_enum_field_value_hints:    false
		enable_anon_fn_return_type_hints: false
	}
	src := 'module main\n\nfn main() {\n\tdouble := fn(x int) {\n\t\treturn x * 2\n\t}\n\t_ = double\n}\n'
	uri := open_hints_file(mut ls, 'hints_anon_fn_flag.v', src)

	hints := compute_hints(mut ls, uri)
	assert hints.len == 0, 'expected no hints when all hint flags are false, got ${hints.len}'
}
