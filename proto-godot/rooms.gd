class_name Rooms
extends RefCounted
## Loads rooms.json and proves the slice is winnable at the current registry
## values: every gap must be clearable by a full jump and every step-up must
## be lower than the jump apex. A layout that fails is a bug, not a tuning job.

var width: float
var height: float
var rooms: Array = []


func load_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "rooms.json unreadable at " + path)
	width = float(parsed["width"])
	height = float(parsed["height"])
	rooms.clear()
	for raw: Dictionary in parsed["rooms"]:
		rooms.append(_parse_room(raw))
	assert_winnable()


func count() -> int:
	return rooms.size()


func room(id: int) -> Dictionary:
	return rooms[id]


static func _rect(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func _rects(list: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a: Array in list:
		out.append(_rect(a))
	return out


func _parse_room(raw: Dictionary) -> Dictionary:
	var out := {
		"spawn": Vector2(float(raw["spawn"][0]), float(raw["spawn"][1])),
		"checkpoint": _rect(raw["checkpoint"]),
		"solids": _rects(raw["solids"]),
		"hazards": _rects(raw["hazards"]),
		"gaps": raw["gaps"],
		"blade": null,
		"goal": null,
	}
	if raw["blade"] != null:
		out["blade"] = {
			"rect": _rect(raw["blade"]["rect"]),
			"track": Vector2(float(raw["blade"]["track"][0]), float(raw["blade"]["track"][1])),
		}
	if raw["goal"] != null:
		out["goal"] = _rect(raw["goal"])
	return out


## Horizontal reach of one full jump from flat ground, at the shipped values.
static func jump_reach() -> float:
	var air_time := 2.0 * Params.get_value("jump_velocity") / Params.get_value("gravity")
	return Params.get_value("move_speed") * air_time


static func jump_apex() -> float:
	var v := Params.get_value("jump_velocity")
	return v * v / (2.0 * Params.get_value("gravity"))


func assert_winnable() -> void:
	var reach := jump_reach()
	var apex := jump_apex()
	var pw := Params.get_value("player_w")
	for id in rooms.size():
		for gap: Array in rooms[id]["gaps"]:
			var span := float(gap[1]) - float(gap[0]) + pw
			assert(
				span < reach,
				"room %d: gap %s needs %.0f px, reach is %.0f" % [id, gap, span, reach]
			)
		for s: Rect2 in rooms[id]["solids"]:
			var step := height - s.position.y - _floor_thickness(id)
			assert(step < apex, "room %d: step of %.0f px exceeds apex %.0f" % [id, step, apex])


## The lowest solid top in a room is its floor level; steps are measured from it.
func _floor_thickness(id: int) -> float:
	var lowest := 0.0
	for s: Rect2 in rooms[id]["solids"]:
		lowest = maxf(lowest, height - s.position.y)
	return lowest
