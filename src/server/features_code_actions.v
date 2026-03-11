module server

import lsp
import json
import server.intentions

pub fn (mut ls LanguageServer) code_actions(params lsp.CodeActionParams) ?[]lsp.CodeAction {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri)?

	mut actions := []lsp.CodeAction{}

	ctx := intentions.IntentionContext.from(file.psi_file, params.range.start)

	for _, mut intention in ls.intentions {
		if !intention.is_available(ctx) {
			continue
		}

		actions << lsp.CodeAction{
			title:   intention.name
			kind:    lsp.refactor
			command: lsp.Command{
				title:     intention.name
				command:   intention.id
				arguments: [
					json.encode(IntentionData{
						file_uri: uri
						position: params.range.start
					}),
				]
			}
		}
	}

	// Build a combined list of diagnostic messages to check against.
	// Zed (and some other editors) send an empty diagnostics array in the
	// codeAction context even when diagnostics exist for the file, so we
	// fall back to the reports we already published for this URI.
	stored_reports := ls.reporter.reports[uri] or { [] }
	has_context_diag := params.context.diagnostics.len > 0

	for _, mut intention in ls.compiler_quick_fixes {
		if !intention.is_available(ctx) {
			continue
		}

		// Check the diagnostics Zed sent with the request first; if none were
		// sent, fall back to the stored reports for this file.
		matched := if has_context_diag {
			params.context.diagnostics.any(intention.is_matched_message(it.message))
		} else {
			stored_reports.any(intention.is_matched_message(it.message))
		}
		if !matched {
			continue
		}

		actions << lsp.CodeAction{
			title:   intention.name
			kind:    lsp.quick_fix
			command: lsp.Command{
				title:     intention.name
				command:   intention.id
				arguments: [
					json.encode(IntentionData{
						file_uri: uri
						position: params.range.start
					}),
				]
			}
		}
	}

	return actions
}
