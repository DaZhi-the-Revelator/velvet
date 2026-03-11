module psi

import analyzer.psi.types

pub struct TypeAliasDeclaration {
	PsiElementImpl
}

pub fn (a &TypeAliasDeclaration) get_type() types.Type {
	types_list := a.types()
	inner_type := if types_list.len > 0 {
		convert_type(types_list[0])
	} else {
		types.Type(types.unknown_type)
	}
	return types.new_alias_type(a.name(), a.module_name(), inner_type)
}

pub fn (a &TypeAliasDeclaration) generic_parameters() ?&GenericParameters {
	generic_parameters := a.find_child_by_type_or_stub(.generic_parameters)?
	if generic_parameters is GenericParameters {
		return generic_parameters
	}
	return none
}

pub fn (a &TypeAliasDeclaration) is_public() bool {
	modifiers := a.visibility_modifiers() or { return false }
	return modifiers.is_public()
}

pub fn (a &TypeAliasDeclaration) module_name() string {
	file := a.containing_file() or { return '' }
	return stubs_index.get_module_qualified_name(file.path)
}

pub fn (a TypeAliasDeclaration) doc_comment() string {
	if stub := a.get_stub() {
		return stub.comment
	}
	return extract_doc_comment(a)
}

pub fn (a &TypeAliasDeclaration) types() []PlainType {
	// The tree-sitter grammar stores the RHS of a type declaration in the
	// "type" field, which is either a plain_type (simple alias) or a
	// sum_type (union alias, e.g. `string | int | f64`).
	//
	// For plain aliases the direct plain_type children are at the top level;
	// for sum types we have to descend into the sum_type child to collect
	// the individual plain_type members.

	// Simple alias: direct plain_type children
	direct := a.find_children_by_type_or_stub(.plain_type)
	if direct.len > 0 {
		mut result := []PlainType{cap: direct.len}
		for type_ in direct {
			if type_ is PlainType {
				result << type_
			}
		}
		return result
	}

	// Sum type: look for a sum_type child, then collect its plain_type members
	sum_node := a.find_child_by_type(.sum_type) or { return [] }
	inner_types := sum_node.find_children_by_type(.plain_type)
	mut result := []PlainType{cap: inner_types.len}
	for type_ in inner_types {
		if type_ is PlainType {
			result << type_
		}
	}
	return result
}

pub fn (a TypeAliasDeclaration) identifier() ?PsiElement {
	return a.find_child_by_type(.identifier)
}

pub fn (a &TypeAliasDeclaration) identifier_text_range() TextRange {
	if stub := a.get_stub() {
		return stub.identifier_text_range
	}

	identifier := a.identifier() or { return TextRange{} }
	return identifier.text_range()
}

pub fn (a TypeAliasDeclaration) name() string {
	if stub := a.get_stub() {
		return stub.name
	}

	identifier := a.identifier() or { return '' }
	return identifier.get_text()
}

pub fn (a TypeAliasDeclaration) visibility_modifiers() ?&VisibilityModifiers {
	modifiers := a.find_child_by_type_or_stub(.visibility_modifiers)?
	if modifiers is VisibilityModifiers {
		return modifiers
	}
	return none
}

fn (_ &TypeAliasDeclaration) stub() {}
