module intentions

import lsp
import analyzer.psi
import server.tform
import server.file_diff

pub struct ImportModuleQuickFix {
	id   string = 'v-analyzer.import_module'
	name string = 'Import module'
}

fn (_ &ImportModuleQuickFix) is_matched_message(msg string) bool {
	// Primary trigger: "undefined ident: json"
	if msg.contains('undefined ident') {
		return true
	}
	// When a module is used but not imported, V may report the call as
	// returning 0 values (because it falls back to treating the name as a
	// local identifier rather than a module reference).
	// e.g. "assignment mismatch: 1 variable(s) but `encode()` returns 0 values"
	if msg.contains('assignment mismatch') && msg.contains('returns 0 values') {
		return true
	}
	return false
}

fn (_ &ImportModuleQuickFix) is_available(ctx IntentionContext) bool {
	pos := tform.lsp_position_to_position(ctx.position)
	element := ctx.containing_file.find_element_at_pos(pos) or { return false }

	// Case 1: cursor is directly on an unqualified reference expression.
	// This covers `undefined ident: json` when `json` is used stand-alone.
	reference_expression := element.parent_of_type(.reference_expression) or {
		// Case 2: cursor is on the left-side identifier of a selector expression
		// (e.g. `json` in `json.encode(...)`).  In that case the element is an
		// Identifier whose parent is a ReferenceExpression that is itself the
		// left child of a SelectorExpression.
		if element is psi.Identifier {
			if parent := element.parent() {
				if parent is psi.ReferenceExpression {
					// Check that this ReferenceExpression is the LEFT (qualifier)
					// part of a SelectorExpression — i.e. it represents a module
					// name being used without an import.
					if grandparent := parent.parent() {
						if grandparent is psi.SelectorExpression {
							if left := grandparent.left() {
								if left.is_equal(parent) {
									module_name := parent.name()
									modules := stubs_index.get_modules_by_name(module_name)
									return modules.len > 0
								}
							}
						}
					}
				}
			}
		}
		return false
	}

	if reference_expression is psi.ReferenceExpression {
		if _ := reference_expression.qualifier() {
			return false
		}

		module_name := reference_expression.get_text()
		modules := stubs_index.get_modules_by_name(module_name)
		if modules.len == 0 {
			return false
		}

		return true
	}
	return false
}

fn (_ &ImportModuleQuickFix) invoke(ctx IntentionContext) ?lsp.WorkspaceEdit {
	uri := ctx.containing_file.uri()
	pos := tform.lsp_position_to_position(ctx.position)
	element := ctx.containing_file.find_element_at_pos(pos)?

	// Resolve the module name from either a plain reference expression or the
	// left side of a selector expression.
	module_name := resolve_import_module_name(element) or { return none }

	modules := stubs_index.get_modules_by_name(module_name)
	if modules.len == 0 {
		return none
	}

	mod := modules.first()
	file := mod.containing_file() or { return none }
	module_fqn := file.module_fqn()

	imports := ctx.containing_file.get_imports()

	mut extra_newline := ''
	mut line_to_insert := 0
	if imports.len > 0 {
		line_to_insert = imports.last().text_range().line + 1
	} else if mod_clause := ctx.containing_file.module_clause() {
		line_to_insert = mod_clause.text_range().line + 2
		extra_newline = '\n'
	} else {
		extra_newline = '\n'
		line_to_insert = 0
	}

	mut diff := file_diff.Diff.for_file(uri)
	diff.append_as_prev_line(line_to_insert, 'import ' + module_fqn + extra_newline)
	return diff.to_workspace_edit()
}

// resolve_import_module_name returns the module name to import given the PSI
// element at the cursor, handling both plain reference expressions and the
// qualifier side of selector expressions.
fn resolve_import_module_name(element psi.PsiElement) ?string {
	// Plain reference expression: `json` used as a standalone identifier
	if ref_expr := element.parent_of_type(.reference_expression) {
		if ref_expr is psi.ReferenceExpression {
			if _ := ref_expr.qualifier() {
				// has a qualifier — try the selector path below
			} else {
				return ref_expr.get_text()
			}
		}
	}

	// Selector expression qualifier: `json` in `json.encode(...)`
	if element is psi.Identifier {
		if parent := element.parent() {
			if parent is psi.ReferenceExpression {
				if grandparent := parent.parent() {
					if grandparent is psi.SelectorExpression {
						if left := grandparent.left() {
							if left.is_equal(parent) {
								return parent.name()
							}
						}
					}
				}
			}
		}
	}

	return none
}
