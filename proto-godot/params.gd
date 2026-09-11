class_name Params
extends RefCounted
## Parameter registry accessor (spec/DOCS-parameters.md). Every tunable comes
## from params.json; nothing is hardcoded. Reload with load_registry().
## The overlay writes through set_value; registry_hash tags saves and logs.

static var _values: Dictionary = {}
static var _hash: String = ""


static func load_registry(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "params.json unreadable at " + path)
	_values.clear()
	for key: String in parsed.keys():
		if not key.begins_with("_"):
			_values[key] = parsed[key]
	_hash = text.sha256_text()


static func get_value(key: String) -> float:
	assert(_values.has(key), "unknown param: " + key)
	return float(_values[key]["value"])


## Live tweak from the debug overlay (M7). Clamped to the entry's bounds.
static func set_value(key: String, value: float) -> void:
	assert(_values.has(key), "unknown param: " + key)
	var e: Dictionary = _values[key]
	e["value"] = clampf(value, float(e["min"]), float(e["max"]))


## Full entry: value/min/max/step/unit/desc. Feeds the generated overlay.
static func entry(key: String) -> Dictionary:
	assert(_values.has(key), "unknown param: " + key)
	return _values[key]


static func keys() -> Array:
	return _values.keys()


static func registry_hash() -> String:
	return _hash
