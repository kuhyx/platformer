class_name Analytics
extends RefCounted
## Debug-build session log (D09, spec/DOCS-analytics.md): one directory per
## run under user://analytics/<utc-timestamp>/ with meta.json, inputs.jsonl,
## state.jsonl and events.jsonl. Replay = seed + params hash + inputs.jsonl.
## Instantiated only when OS.is_debug_build(); public builds carry no logger.

const ROOT := "user://analytics"

var dir: String
var _inputs: FileAccess
var _state: FileAccess
var _events: FileAccess
var _last_input := {}


func start(seed_value: int) -> void:
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
	dir = "%s/%s" % [ROOT, stamp]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write_meta(seed_value)
	_inputs = FileAccess.open(dir + "/inputs.jsonl", FileAccess.WRITE)
	_state = FileAccess.open(dir + "/state.jsonl", FileAccess.WRITE)
	_events = FileAccess.open(dir + "/events.jsonl", FileAccess.WRITE)


func _write_meta(seed_value: int) -> void:
	var meta := {
		"build": Engine.get_version_info()["string"],
		"engine": "godot",
		"params_hash": Params.registry_hash(),
		"seed": seed_value,
		"device":
		{
			"os": OS.get_name(),
			"cpu": OS.get_processor_name(),
			"gpu": RenderingServer.get_video_adapter_name(),
		},
	}
	var f := FileAccess.open(dir + "/meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()


## One line per action whose held state changed this tick.
func log_input(tick: int, input: Dictionary) -> void:
	for action: String in input:
		if _last_input.get(action) != input[action]:
			_line(_inputs, {"t": tick, "a": action, "v": int(input[action])})
	_last_input = input.duplicate()


func log_events(tick: int, events: Array[Dictionary]) -> void:
	for e in events:
		var row := e.duplicate()
		row["t"] = tick
		_line(_events, row)


## Caller samples every `state_log_every` ticks; the snapshot is not cheap.
func log_state(snapshot: Dictionary) -> void:
	_line(_state, snapshot)


static func _line(f: FileAccess, row: Dictionary) -> void:
	if f == null:
		return
	f.store_line(JSON.stringify(row))
	f.flush()
