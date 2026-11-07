extends SceneTree
## Cross-engine replay fixture (shared/replay/slice_trace.json).
##   godot --headless --path . -s tests/replay.gd             # verify: last line "replay: ok"
##   godot --headless --path . -s tests/replay.gd -- --write  # regenerate from the policy below
## A closed-loop policy plays the whole slice once (die in each room, clear
## both, touch the goal, loop) and its per-tick input is written open-loop.
## Every other prototype replays those inputs and must emit the same events
## on the same ticks: that is what "mirrors sim.gd" means, checkably.

const TRACE := "res://../shared/replay/slice_trace.json"
const SEED := 7
const MAX_TICKS := 60 * 60  # one minute of sim time, D12
const SAFE_BEHIND := 10.0  # px the blade must be behind the take-off point [design guess]
const SAFE_AHEAD := 140.0  # px the blade must be ahead: outruns the jump arc [design guess]


func _init() -> void:
	Params.load_registry("res://params.json")
	var rooms := Rooms.new()
	rooms.load_file("res://rooms.json")
	var path := ProjectSettings.globalize_path(TRACE)
	if "--write" in OS.get_cmdline_user_args():
		_write(path, _play(rooms))
		quit(0)
		return
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var got := _replay(rooms, want["inputs"])
	# Round-trip through JSON so ints and parsed floats compare as equal.
	var ok := (
		JSON.stringify(JSON.parse_string(JSON.stringify(got))) == JSON.stringify(want["events"])
	)
	print("replay: %s (%d events)" % ["ok" if ok else "MISMATCH", got.size()])
	quit(0 if ok else 1)


func _fresh(rooms: Rooms) -> Sim:
	var sim := Sim.new(rooms, SEED)
	sim.enter_room(0)
	return sim


func _log(sim: Sim, out: Array) -> void:
	for e in sim.events:
		out.append([sim.tick_count, e["e"], sim.room_id])


## Policy phases: 0 die in room 1's pit, 1 clear room 1, 2 die in room 2,
## 3 clear room 2 timing the blade, 4 ride the goal loop back to room 1.
func _play(rooms: Rooms) -> Dictionary:
	var sim := _fresh(rooms)
	var events: Array = []
	_log(sim, events)
	var inputs: Array = []
	var phase := 0
	while phase < 5 and sim.tick_count < MAX_TICKS:
		var input := _policy(sim, phase)
		sim.tick(input)
		_log(sim, events)
		inputs.append([int(input["left"]), int(input["right"]), int(input["jump"])])
		for e in sim.events:
			if e["e"] in ["respawn", "goal"] or (e["e"] == "room_enter" and phase == 1):
				phase += 1
			elif e["e"] == "room_enter" and phase == 4:
				phase = 5
	return {"inputs": _segments(inputs), "events": events}


func _policy(sim: Sim, phase: int) -> Dictionary:
	var input := {"left": false, "right": sim.state == Sim.State.ALIVE, "jump": false}
	if phase in [0, 2] or sim.state != Sim.State.ALIVE:
		return input
	var w := sim.size().x
	var gap_x := float(sim.room()["gaps"][0][0])
	var near_gap := sim.pos.x + 2.0 * w >= gap_x and sim.pos.x < gap_x
	if phase == 1:
		var ledge_x: float = sim.room()["solids"][2].position.x
		var near_ledge := sim.pos.x + 2.0 * w >= ledge_x and sim.pos.x < ledge_x
		input["jump"] = near_gap or near_ledge
	elif phase == 3 and near_gap:
		var blade := sim.blade_rect()
		var behind := sim.blade_dir < 0.0 and blade.end.x < sim.pos.x - SAFE_BEHIND
		var ahead := blade.position.x > sim.pos.x + SAFE_AHEAD
		input["jump"] = behind or ahead
		input["right"] = behind or ahead or sim.pos.x + w < gap_x - w
	return input


## Run-length encode [left, right, jump] per tick as [ticks, left, right, jump].
static func _segments(inputs: Array) -> Array:
	var out: Array = []
	for i in inputs:
		if not out.is_empty() and out[-1].slice(1) == i:
			out[-1][0] += 1
		else:
			out.append([1] + i)
	return out


func _replay(rooms: Rooms, segments: Array) -> Array:
	var sim := _fresh(rooms)
	var events: Array = []
	_log(sim, events)
	for seg: Array in segments:
		var input := {"left": seg[1] == 1, "right": seg[2] == 1, "jump": seg[3] == 1}
		for _i in int(seg[0]):
			sim.tick(input)
			_log(sim, events)
	return events


func _write(path: String, trace: Dictionary) -> void:
	var doc := {
		"_comment":
		(
			"Replay fixture (D24). inputs: [ticks, left, right, jump] run-length segments "
			+ "at 60 Hz from enter_room(0), seed 7, shipped registry values. "
			+ "events: [tick, name, room] each engine must reproduce. Regenerate in "
			+ "proto-godot: godot --headless --path . -s tests/replay.gd -- --write"
		),
		"seed": SEED,
		"inputs": trace["inputs"],
		"events": trace["events"],
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ") + "\n")
	print("replay: wrote %s (%d events)" % [path, trace["events"].size()])
