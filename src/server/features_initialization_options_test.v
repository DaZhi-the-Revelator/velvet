module server

// Tests for apply_initialization_options.

import lsp
import analyzer
import config

fn new_init_opt_ls() &LanguageServer {
	mut ls := LanguageServer.new(analyzer.IndexingManager.new())
	return ls
}

fn test_init_options_semantic_tokens_syntax() {
	mut ls := new_init_opt_ls()
	mut m := map[string]lsp.LSPAny{}
	m['enable_semantic_tokens'] = lsp.LSPAny('syntax')
	ls.apply_initialization_options(lsp.LSPAny(m))
	assert ls.cfg.enable_semantic_tokens == config.SemanticTokensMode.syntax
}

fn test_init_options_semantic_tokens_none() {
	mut ls := new_init_opt_ls()
	mut m := map[string]lsp.LSPAny{}
	m['enable_semantic_tokens'] = lsp.LSPAny('none')
	ls.apply_initialization_options(lsp.LSPAny(m))
	assert ls.cfg.enable_semantic_tokens == config.SemanticTokensMode.none_
}

fn test_init_options_semantic_tokens_full() {
	mut ls := new_init_opt_ls()
	ls.cfg.enable_semantic_tokens = config.SemanticTokensMode.none_
	mut m := map[string]lsp.LSPAny{}
	m['enable_semantic_tokens'] = lsp.LSPAny('full')
	ls.apply_initialization_options(lsp.LSPAny(m))
	assert ls.cfg.enable_semantic_tokens == config.SemanticTokensMode.full
}

fn test_init_options_semantic_tokens_unknown_unchanged() {
	mut ls := new_init_opt_ls()
	ls.cfg.enable_semantic_tokens = config.SemanticTokensMode.syntax
	mut m := map[string]lsp.LSPAny{}
	m['enable_semantic_tokens'] = lsp.LSPAny('bogus_value')
	ls.apply_initialization_options(lsp.LSPAny(m))
	assert ls.cfg.enable_semantic_tokens == config.SemanticTokensMode.syntax
}

fn test_init_options_inlay_hints_enable_false() {
	mut ls := new_init_opt_ls()
	ls.cfg.inlay_hints.enable = true

	mut ih := map[string]lsp.LSPAny{}
	ih['enable'] = lsp.LSPAny(false)
	mut m := map[string]lsp.LSPAny{}
	m['inlay_hints'] = lsp.LSPAny(ih)
	ls.apply_initialization_options(lsp.LSPAny(m))

	assert ls.cfg.inlay_hints.enable == false
}

fn test_init_options_inlay_hints_individual_flags() {
	mut ls := new_init_opt_ls()
	ls.cfg.inlay_hints.enable_type_hints = true
	ls.cfg.inlay_hints.enable_parameter_name_hints = true

	mut ih := map[string]lsp.LSPAny{}
	ih['enable'] = lsp.LSPAny(true)
	ih['enable_type_hints'] = lsp.LSPAny(false)
	ih['enable_parameter_name_hints'] = lsp.LSPAny(false)
	mut m := map[string]lsp.LSPAny{}
	m['inlay_hints'] = lsp.LSPAny(ih)
	ls.apply_initialization_options(lsp.LSPAny(m))

	assert ls.cfg.inlay_hints.enable_type_hints == false
	assert ls.cfg.inlay_hints.enable_parameter_name_hints == false
}

fn test_init_options_inlay_hints_missing_key_unchanged() {
	mut ls := new_init_opt_ls()
	ls.cfg.inlay_hints.enable = true
	ls.cfg.inlay_hints.enable_type_hints = true

	mut m := map[string]lsp.LSPAny{}
	m['enable_semantic_tokens'] = lsp.LSPAny('full')
	ls.apply_initialization_options(lsp.LSPAny(m))

	assert ls.cfg.inlay_hints.enable == true
	assert ls.cfg.inlay_hints.enable_type_hints == true
}

fn test_init_options_code_lens_enable_false() {
	mut ls := new_init_opt_ls()
	ls.cfg.code_lens.enable = true

	mut cl := map[string]lsp.LSPAny{}
	cl['enable'] = lsp.LSPAny(false)
	mut m := map[string]lsp.LSPAny{}
	m['code_lens'] = lsp.LSPAny(cl)
	ls.apply_initialization_options(lsp.LSPAny(m))

	assert ls.cfg.code_lens.enable == false
}

fn test_init_options_code_lens_individual_flags() {
	mut ls := new_init_opt_ls()
	ls.cfg.code_lens.enable_run_lens = true
	ls.cfg.code_lens.enable_run_tests_lens = true

	mut cl := map[string]lsp.LSPAny{}
	cl['enable'] = lsp.LSPAny(true)
	cl['enable_run_lens'] = lsp.LSPAny(false)
	cl['enable_run_tests_lens'] = lsp.LSPAny(false)
	mut m := map[string]lsp.LSPAny{}
	m['code_lens'] = lsp.LSPAny(cl)
	ls.apply_initialization_options(lsp.LSPAny(m))

	assert ls.cfg.code_lens.enable_run_lens == false
	assert ls.cfg.code_lens.enable_run_tests_lens == false
}

fn test_init_options_unknown_keys_no_crash() {
	mut ls := new_init_opt_ls()
	mut m := map[string]lsp.LSPAny{}
	m['this_key_does_not_exist'] = lsp.LSPAny('some_value')
	m['another_unknown_key'] = lsp.LSPAny(true)
	ls.apply_initialization_options(lsp.LSPAny(m))
	// Reaching here without panic is the pass condition.
	assert true
}
