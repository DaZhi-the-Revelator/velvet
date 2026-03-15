module psi

import analyzer.psi.types

pub struct FieldDeclaration {
	PsiElementImpl
}

pub fn (f &FieldDeclaration) is_embedded_definition() bool {
	return f.has_child_of_type(.embedded_definition)
}

pub fn (f &FieldDeclaration) is_public() bool {
	if owner := f.owner() {
		if owner is InterfaceDeclaration {
			return true // all interface fields are public by default
		}
	}

	_, is_pub := f.is_mutable_public()
	return is_pub
}

pub fn (f &FieldDeclaration) doc_comment() string {
	if stub := f.get_stub() {
		return stub.comment
	}

	if comment := f.find_child_by_type(.line_comment) {
		return comment.get_text().trim_string_left('//').trim(' \t')
	}

	return extract_doc_comment(f)
}

pub fn (f &FieldDeclaration) identifier() ?PsiElement {
	return f.find_child_by_type(.identifier)
}

pub fn (f FieldDeclaration) identifier_text_range() TextRange {
	if stub := f.get_stub() {
		return stub.identifier_text_range
	}

	identifier := f.identifier() or { return TextRange{} }
	return identifier.text_range()
}

pub fn (f &FieldDeclaration) name() string {
	if stub := f.get_stub() {
		return stub.name
	}

	identifier := f.identifier() or { return '' }
	return identifier.get_text()
}

pub fn (f &FieldDeclaration) get_type() types.Type {
	return infer_type(f)
}

// default_value returns the literal text of the declared default value for this
// field, if one is present in the source (e.g. `width f64 = 1.5` → `1.5`).
// Returns `none` for stub-based elements or when no default is declared.
pub fn (f &FieldDeclaration) default_value() ?string {
	// Stubs do not carry the initialiser expression.
	if f.stub_based() {
		return none
	}
	// The grammar for struct_field_declaration is:
	//   <identifier> <plain_type> [ '=' <expression> ]
	// Walk children looking for '=' then grab the next named sibling.
	mut found_eq := false
	mut child := f.node.first_child() or { return none }
	for {
		if !found_eq {
			if child.type_name == .unknown && f.get_text_of_node(child) == '=' {
				found_eq = true
			}
		} else {
			if child.type_name != .unknown {
				// This is the default-value expression node.
				file := f.containing_file() or { return none }
				return child.text(file.source_text)
			}
		}
		child = child.next_sibling() or { break }
	}
	return none
}

fn (f &FieldDeclaration) get_text_of_node(node AstNode) string {
	file := f.containing_file() or { return '' }
	return node.text(file.source_text)
}

pub fn (f &FieldDeclaration) owner() ?PsiElement {
	if struct_ := f.parent_of_type(.struct_declaration) {
		return struct_
	}
	return f.parent_of_type(.interface_declaration)
}

pub fn (f &FieldDeclaration) scope() ?&StructFieldScope {
	element := f.sibling_of_type_backward(.struct_field_scope)?
	if element is StructFieldScope {
		return element
	}
	return none
}

pub fn (f &FieldDeclaration) is_mutable_public() (bool, bool) {
	scope := f.scope() or { return false, false }
	return scope.is_mutable_public()
}

pub fn (_ FieldDeclaration) stub() {}
