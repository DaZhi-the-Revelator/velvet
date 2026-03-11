module server

import lsp
import loglib
import analyzer.psi

// selection_range handles the 'textDocument/selectionRange' LSP request.
// For each requested position it builds a chain of nested ranges, from the
// smallest syntactic node up to the whole source file, so that the editor can
// expand / shrink the selection one structural step at a time.
pub fn (mut ls LanguageServer) selection_range(params lsp.SelectionRangeParams) ?[]lsp.SelectionRange {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri) or {
		loglib.with_fields({
			'uri': uri.str()
		}).warn('Selection range requested for unopened file')
		return none
	}

	mut results := []lsp.SelectionRange{cap: params.positions.len}

	for pos in params.positions {
		offset := file.find_offset(pos)
		leaf := file.psi_file.find_element_at(offset) or {
			results << lsp.SelectionRange{
				range: lsp.Range{}
			}
			continue
		}

		results << build_selection_range_chain(leaf)
	}

	return results
}

// build_selection_range_chain walks from the given leaf element up to the
// root, collecting one lsp.SelectionRange per interesting node.
fn build_selection_range_chain(leaf psi.PsiElement) lsp.SelectionRange {
	// Collect ancestors from leaf → root, skipping boring wrapper nodes.
	mut chain := []psi.PsiElement{}
	mut cur := leaf
	for {
		if should_include_node(cur) {
			chain << cur
		}
		cur = cur.parent() or { break }
	}

	if chain.len == 0 {
		return lsp.SelectionRange{
			range: psi_element_to_lsp_range(leaf)
		}
	}

	// Build the linked list from outermost → innermost.
	// The LSP spec requires the innermost SelectionRange to have a `parent`
	// pointing to the next larger one.
	mut outer := lsp.SelectionRange{
		range: psi_element_to_lsp_range(chain.last())
	}
	for i := chain.len - 2; i >= 0; i-- {
		outer = lsp.SelectionRange{
			range:  psi_element_to_lsp_range(chain[i])
			parent: &outer
		}
	}

	return outer
}

// should_include_node returns true if this node type is a useful selection
// boundary.  We skip trivia / wrapper nodes that would produce duplicate
// ranges.
fn should_include_node(el psi.PsiElement) bool {
	match el.element_type() {
		.identifier { return true }
		.error, .unknown { return false }
		else {
			named := el.named_children()
			if named.len == 1 {
				child_r := named[0].text_range()
				self_r := el.text_range()
				if child_r.line == self_r.line && child_r.column == self_r.column
					&& child_r.end_line == self_r.end_line
					&& child_r.end_column == self_r.end_column {
					return false
				}
			}
			return true
		}
	}
}

fn psi_element_to_lsp_range(el psi.PsiElement) lsp.Range {
	r := el.text_range()
	return lsp.Range{
		start: lsp.Position{
			line:      r.line
			character: r.column
		}
		end:   lsp.Position{
			line:      r.end_line
			character: r.end_column
		}
	}
}
