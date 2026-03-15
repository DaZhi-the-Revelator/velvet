module server

import lsp
import analyzer.psi
import analyzer.psi.types as psi_types
import server.completion
import server.completion.providers
import loglib

pub fn (mut ls LanguageServer) completion(params lsp.CompletionParams) ![]lsp.CompletionItem {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri) or { return [] }

	offset := file.find_offset(params.position)

	mut source := file.psi_file.source_text

	if offset >= source.len {
		loglib.with_fields({
			'offset':     offset.str()
			'source_len': source.len.str()
		}).warn('Offset is out of range')
		return []
	}

	// The idea behind this solution is:
	// When we have an expression like `foo.` and we want to get the autocompletion variants,
	// it can be difficult to directly try to figure out what is before the dot, since the
	// parser does not parse it correctly, since there must be an identifier after the dot.
	// The idea is that we add some dummy identifier at the cursor point and call go to definition,
	// which goes through all the variants that may be for this place.
	// Thus, we collect them, filter and show them to the user.
	source = insert_to_string(source, offset, completion.dummy_identifier)

	res := ls.main_parser.parse_code(source)
	mut patched_psi_file := psi.new_psi_file(uri.path(), res.tree, res.source_text)
	defer { patched_psi_file.free() }

	element := patched_psi_file.root().find_element_at(offset) or {
		loglib.with_fields({
			'offset': offset.str()
		}).warn('Cannot find element')
		return []
	}

	// We use CompletionContext in order not to calculate the current partial context
	// in each provider, but to calculate it once and pass it to all providers.
	mut ctx := &completion.CompletionContext{
		element:      element
		position:     params.position
		offset:       offset
		trigger_kind: params.context.trigger_kind
	}
	ctx.compute()

	mut result_set := &completion.CompletionResultSet{}

	// Build the generic substitution map for dot-completions on generic
	// instantiations (e.g. `container_of_point.`). We inspect the qualifier of
	// the selector expression that wraps the dummy identifier.
	generic_ts_map := build_generic_ts_map(element)

	mut processor := &providers.ReferenceCompletionProcessor{
		file:           file.psi_file
		module_fqn:     file.psi_file.module_fqn()
		root:           ls.root_uri.path()
		ctx:            ctx
		generic_ts_map: generic_ts_map
	}

	mut completion_providers := []completion.CompletionProvider{}
	completion_providers << providers.ReferenceCompletionProvider{
		processor: processor
	}
	completion_providers << providers.ModulesImportProvider{}
	completion_providers << providers.ReturnCompletionProvider{}
	completion_providers << providers.CompileTimeConstantCompletionProvider{}
	completion_providers << providers.InitsCompletionProvider{}
	completion_providers << providers.KeywordsCompletionProvider{}
	completion_providers << providers.TopLevelCompletionProvider{}
	completion_providers << providers.LoopKeywordsCompletionProvider{}
	completion_providers << providers.PureBlockExpressionCompletionProvider{}
	completion_providers << providers.PureBlockStatementCompletionProvider{}
	completion_providers << providers.OrBlockExpressionCompletionProvider{}
	completion_providers << providers.FunctionLikeCompletionProvider{}
	completion_providers << providers.AssertCompletionProvider{}
	completion_providers << providers.ModuleNameCompletionProvider{}
	completion_providers << providers.NilKeywordCompletionProvider{}
	completion_providers << providers.JsonAttributeCompletionProvider{}
	completion_providers << providers.AttributesCompletionProvider{}
	completion_providers << providers.ImportsCompletionProvider{}

	for mut provider in completion_providers {
		if !provider.is_available(ctx) {
			continue
		}
		provider.add_completion(ctx, mut result_set)
	}

	for el in processor.elements() {
		result_set.add_element(el)
	}

	// unsafe { res.tree.free() }

	return result_set.elements()
}

fn insert_to_string(str string, offset u32, insert string) string {
	return str[..offset] + insert + str[offset..]
}

// build_generic_ts_map inspects the qualifier of the selector expression
// containing `element` and, if the qualifier's type is a GenericInstantiationType,
// returns a map of generic-parameter-name → concrete-type ready to be passed to
// substitute_generics().
fn build_generic_ts_map(element psi.PsiElement) map[string]psi_types.Type {
	parent := element.parent() or { return map[string]psi_types.Type{} }

	// The dummy identifier lands inside a SelectorExpression (after `.`).
	// Walk up one or two levels to find it.
	if parent is psi.SelectorExpression {
		return extract_generic_map(parent)
	}
	grand := parent.parent() or { return map[string]psi_types.Type{} }
	if grand is psi.SelectorExpression {
		return extract_generic_map(grand)
	}
	return map[string]psi_types.Type{}
}

fn extract_generic_map(sel psi.SelectorExpression) map[string]psi_types.Type {
	qualifier := sel.qualifier() or { return map[string]psi_types.Type{} }
	qualifier_type := psi.infer_type(qualifier)

	instantiation := unwrap_to_instantiation(qualifier_type) or {
		return map[string]psi_types.Type{}
	}

	// Ask GenericTypeInferer for the ordered type-parameter names.
	// extract_instantiation_ts takes a GenericInstantiationType by value.
	inferer := psi.GenericTypeInferer{}
	params := inferer.extract_instantiation_ts(instantiation)
	if params.len == 0 {
		return map[string]psi_types.Type{}
	}

	mut mapping := map[string]psi_types.Type{}
	for i, param_name in params {
		if i < instantiation.specialization.len {
			mapping[param_name] = instantiation.specialization[i]
		}
	}
	return mapping
}

fn unwrap_to_instantiation(typ psi_types.Type) ?psi_types.GenericInstantiationType {
	if typ is psi_types.GenericInstantiationType {
		return *typ
	}
	if typ is psi_types.AliasType {
		return unwrap_to_instantiation(typ.inner)
	}
	if typ is psi_types.PointerType {
		return unwrap_to_instantiation(typ.inner)
	}
	if typ is psi_types.OptionType {
		return unwrap_to_instantiation(typ.inner)
	}
	if typ is psi_types.ResultType {
		return unwrap_to_instantiation(typ.inner)
	}
	return none
}
