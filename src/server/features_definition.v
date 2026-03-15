module server

import lsp
import loglib
import analyzer.psi
import server.tform

pub fn (mut ls LanguageServer) definition(params lsp.TextDocumentPositionParams) ?[]lsp.LocationLink {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri)?

	offset := file.find_offset(params.position)

	// ── Special case 1: @FILE, @LINE, @MOD, … ──────────────────────────────
	// pseudo_compile_time_identifier nodes are not ReferenceExpressionBase so
	// find_reference_at will return none for them.  They are compiler built-ins
	// with no source location, so we simply return no links (no crash).
	if raw_elem := file.psi_file.root().find_element_at(offset) {
		if raw_elem.node().type_name == .pseudo_compile_time_identifier {
			loglib.with_fields({
				'element': raw_elem.get_text()
			}).warn('go-to-def on compile-time identifier: no source location')
			return none
		}

		// ── Special case 2: $if <condition> { ──────────────────────────────
		// When the cursor is on the condition identifier inside a
		// compile_time_if_expression try normal resolution first; if that
		// yields nothing we fall through to the general path which will also
		// return none gracefully.
		if raw_elem.node().type_name == .identifier {
			if parent := raw_elem.parent() {
				if parent.node().type_name == .reference_expression {
					if grand := parent.parent() {
						if grand.node().type_name == .compile_time_if_expression {
							// Let normal resolution run — the condition ident is a
							// reference_expression and will resolve to a ConstantDefinition
							// in the stubs index when one exists (e.g. 'windows').
							// We set element = parent (the ReferenceExpression) and
							// fall through to normal multi-resolve below.
							if parent is psi.ReferenceExpressionBase {
								resolved_elements := (parent as psi.ReferenceExpressionBase).reference().multi_resolve()
								if resolved_elements.len > 0 {
									mut links := []lsp.LocationLink{cap: resolved_elements.len}
									for resolved in resolved_elements {
										containing_file := resolved.containing_file() or { continue }
										if data := new_resolve_result(containing_file, resolved) {
											links << data.to_location_link(parent.text_range())
										}
									}
									if links.len > 0 {
										return links
									}
								}
							}
							// Condition did not resolve — no definition to jump to.
							return none
						}
					}
				}
			}
		}
	}

	// ── Normal resolution path ──────────────────────────────────────────────
	element := file.psi_file.find_reference_at(offset) or {
		loglib.with_fields({
			'offset': offset.str()
		}).warn('Cannot find reference')
		return none
	}

	resolved_elements := element.reference().multi_resolve()
	if resolved_elements.len == 0 {
		return none
	}

	mut links := []lsp.LocationLink{cap: resolved_elements.len}

	for resolved in resolved_elements {
		containing_file := resolved.containing_file() or { continue }
		if data := new_resolve_result(containing_file, resolved) {
			links << data.to_location_link(element.text_range())
		}
	}

	return links
}

struct ResolveResult {
pub:
	filepath string
	name     string
	range    psi.TextRange
}

pub fn new_resolve_result(containing_file &psi.PsiFile, element psi.PsiElement) ?ResolveResult {
	if element is psi.PsiNamedElement {
		text_range := element.identifier_text_range()
		return ResolveResult{
			range:    text_range
			filepath: containing_file.path()
			name:     element.name()
		}
	}

	return none
}

fn (r &ResolveResult) to_location_link(origin_selection_range psi.TextRange) lsp.LocationLink {
	range := tform.text_range_to_lsp_range(r.range)
	return lsp.LocationLink{
		target_uri:             lsp.document_uri_from_path(r.filepath)
		origin_selection_range: tform.text_range_to_lsp_range(origin_selection_range)
		target_range:           range
		target_selection_range: range
	}
}
