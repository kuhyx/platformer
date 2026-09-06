class_name Params
extends RefCounted
## Parameter registry accessor (spec/DOCS-parameters.md). Every tunable comes
## from params.json; nothing is hardcoded. Reload with load_registry().

static var _values: Dictionary = {}


static func load_registry(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "params.json unreadable at " + path)
	_values.clear()
	for key: String in parsed.keys():
		if not key.begins_with("_"):
			_values[key] = parsed[key]


static func get_value(key: String) -> float:
	assert(_values.has(key), "unknown param: " + key)
	return float(_values[key]["value"])


static func keys() -> Array:
	return _values.keys()
