module server

import lsp
import server.hints

pub fn (mut ls LanguageServer) inlay_hints(params lsp.InlayHintParams) ?[]lsp.InlayHint {
	if !ls.cfg.inlay_hints.enable {
		return none
	}

	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri)?

	mut visitor := hints.InlayHintsVisitor{
		cfg:          ls.cfg.inlay_hints
		range_start: params.range.start.line
		range_end:   params.range.end.line
	}
	visitor.accept(file.psi_file.root())
	return visitor.result
}
