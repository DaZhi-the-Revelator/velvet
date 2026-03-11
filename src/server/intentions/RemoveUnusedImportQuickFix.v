module intentions

import lsp
import server.tform
import server.file_diff

pub struct RemoveUnusedImportQuickFix {
	id   string = 'v-analyzer.remove_unused_import'
	name string = 'Remove unused import'
}

fn (_ &RemoveUnusedImportQuickFix) is_matched_message(msg string) bool {
	// Matches the actual V compiler diagnostic:
	// "module 'benchmark' is imported but never used..."
	// Also handles older formats just in case:
	// "unused import: json"
	return msg.contains('is imported but never used') || msg.starts_with('unused import')
}

fn (_ &RemoveUnusedImportQuickFix) is_available(ctx IntentionContext) bool {
	pos := tform.lsp_position_to_position(ctx.position)
	element := ctx.containing_file.find_element_at_pos(pos) or { return false }

	// Accept the cursor being anywhere on an import line:
	// directly on the import_declaration node itself, or on any
	// descendant (import_spec, import_path, import_name, identifier).
	if element.element_type() == .import_declaration {
		return true
	}
	_ := element.parent_of_type(.import_declaration) or { return false }
	return true
}

fn (_ &RemoveUnusedImportQuickFix) invoke(ctx IntentionContext) ?lsp.WorkspaceEdit {
	uri := ctx.containing_file.uri()
	pos := tform.lsp_position_to_position(ctx.position)
	element := ctx.containing_file.find_element_at_pos(pos)?

	// Walk up to the import_declaration node regardless of where on the
	// line the cursor sits (identifier, import_name, import_path, etc.).
	import_decl := if element.element_type() == .import_declaration {
		element
	} else {
		element.parent_of_type(.import_declaration) or { return none }
	}

	range := import_decl.text_range()
	mut diff := file_diff.Diff.for_file(uri)
	diff.remove_lines(range.line, range.end_line + 1)
	return diff.to_workspace_edit()
}
