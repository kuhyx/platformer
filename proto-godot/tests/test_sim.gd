extends SceneTree
## Headless slice check (M10): drives Sim with scripted input, no window.
##   godot --headless --path . -s tests/test_sim.gd
## Exit code 0 = every check passed. Each check names what it proves.

const IDLE := {"left": false, "right": false, "jump": false}
const RIGHT := {"left": false, "right": true, "jump": false}
const RIGHT_JUMP := {"left": false, "right": true, "jump": true}
const JUMP := {"left": false, "right": false, "jump": true}
const SEED := 7
const SECONDS := 60  # ticks per second, D12

var failures := 0


func _init() -> void:
	Params.load_registry("res://params.json")
	var rooms := Rooms.new()
	rooms.load_file("res://rooms.json")
	_check_landing(rooms)
	_check_pit_kills(rooms)
	_check_run_reaches_room_2(rooms)
	_check_room_2_hazards(rooms)
	_check_goal_loops(rooms)
	_check_coyote(rooms)
	_check_buffer(rooms)
	_check_determinism(rooms)
	print("test_sim: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _fresh(rooms: Rooms, room: int = 0) -> Sim:
	var sim := Sim.new(rooms, SEED)
	sim.enter_room(room)
	return sim


func _run(sim: Sim, ticks: int, input: Dictionary) -> Array:
	var seen: Array = []
	for _i in ticks:
		sim.tick(input)
		for e in sim.events:
			seen.append(e["e"])
	return seen


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
	print("%s %s" % ["ok  " if cond else "FAIL", what])


func _check_landing(rooms: Rooms) -> void:
	var sim := _fresh(rooms)
	_run(sim, SECONDS, IDLE)
	var floor_top: float = rooms.room(0)["solids"][0].position.y
	_expect(
		sim.on_ground and sim.pos.y == floor_top - sim.size().y, "idle avatar rests on the floor"
	)


func _check_pit_kills(rooms: Rooms) -> void:
	var sim := _fresh(rooms)
	var seen := _run(sim, 5 * SECONDS, RIGHT)
	_expect("death" in seen, "walking into room 1's spike pit kills")
	_expect("respawn" in seen and sim.room_id == 0, "respawn returns to room 1's checkpoint")


## Hold right, jump when the pit or the ledge is next. Ends in room 2.
func _run_room_1(sim: Sim) -> Array:
	var seen: Array = []
	var pit_x: float = rooms_gap_start(sim)
	var ledge_x: float = sim.room()["solids"][2].position.x
	for _i in 8 * SECONDS:
		var near_pit := sim.pos.x + sim.size().x >= pit_x - sim.size().x and sim.pos.x < pit_x
		var near_ledge := sim.pos.x + sim.size().x >= ledge_x - sim.size().x and sim.pos.x < ledge_x
		sim.tick(RIGHT_JUMP if near_pit or near_ledge else RIGHT)
		for e in sim.events:
			seen.append(e["e"])
		if sim.room_id == 1:
			break
	return seen


static func rooms_gap_start(sim: Sim) -> float:
	return float(sim.room()["gaps"][0][0])


func _check_run_reaches_room_2(rooms: Rooms) -> void:
	var sim := _fresh(rooms)
	var seen := _run_room_1(sim)
	_expect(
		"death" not in seen and sim.room_id == 1, "jumping the pit and the ledge reaches room 2"
	)
	_expect("checkpoint" in seen, "entering room 2 raises a checkpoint (autosave)")


func _check_room_2_hazards(rooms: Rooms) -> void:
	var sim := _fresh(rooms, 1)
	var seen := _run(sim, 5 * SECONDS, RIGHT)
	_expect(
		"death" in seen and sim.room_id == 1, "room 2's gap or blade kills; respawn stays in room 2"
	)
	sim = _fresh(rooms, 1)
	var blade: Dictionary = sim.room()["blade"]
	var start_x: float = sim.blade_pos.x
	_run(sim, SECONDS, IDLE)
	var track: Vector2 = blade["track"]
	var moved := sim.blade_pos.x != start_x
	var within := sim.blade_pos.x >= track.x and sim.blade_pos.x <= track.y
	_expect(moved and within, "blade patrols inside its track")


func _check_goal_loops(rooms: Rooms) -> void:
	var sim := _fresh(rooms, 1)
	var goal: Rect2 = sim.room()["goal"]
	sim.pos = Vector2(goal.position.x - sim.size().x - 1.0, goal.position.y)
	var seen := _run(sim, 2 * SECONDS, RIGHT)
	_expect("goal" in seen, "touching the goal pillar fires goal")
	_expect(
		sim.room_id == 0 and sim.state == Sim.State.ALIVE,
		"after the flash the loop restarts in room 1"
	)


## Walk off the ledge, then press jump a few ticks later.
func _late_jump_after_ledge(rooms: Rooms, coyote: float) -> bool:
	Params.set_value("coyote_time", coyote)
	var sim := _fresh(rooms)
	var ledge: Rect2 = sim.room()["solids"][2]
	sim.pos = Vector2(ledge.end.x - sim.size().x - 1.0, ledge.position.y - sim.size().y)
	_run(sim, 2, IDLE)  # settle onto the ledge
	sim.pos.x = rooms.width - sim.size().x  # stand on the ledge's last pixel
	_run(sim, 1, IDLE)
	sim.pos.x = ledge.end.x  # airborne past the edge, still in room 1
	_run(sim, 2, IDLE)
	var seen := _run(sim, 1, JUMP)
	Params.set_value("coyote_time", 0.08)
	return "jump" in seen


func _check_coyote(rooms: Rooms) -> void:
	_expect(
		not _late_jump_after_ledge(rooms, 0.0), "coyote_time 0: no jump after leaving the ledge"
	)
	_expect(_late_jump_after_ledge(rooms, 0.08), "coyote_time 0.08: jump still fires shortly after")


## Tap jump while falling, a few ticks before landing.
func _early_jump_before_landing(rooms: Rooms, buffer: float) -> bool:
	Params.set_value("jump_buffer", buffer)
	var sim := _fresh(rooms)
	sim.pos.y -= 2.0 * sim.size().y  # drop from above the floor
	_run(sim, 9, IDLE)  # most of the way down
	_run(sim, 1, JUMP)
	var seen := _run(sim, SECONDS, IDLE)
	Params.set_value("jump_buffer", 0.1)
	return "jump" in seen


func _check_buffer(rooms: Rooms) -> void:
	_expect(not _early_jump_before_landing(rooms, 0.0), "jump_buffer 0: early tap is lost")
	_expect(_early_jump_before_landing(rooms, 0.1), "jump_buffer 0.1: early tap fires on landing")


func _check_determinism(rooms: Rooms) -> void:
	var a := _fresh(rooms)
	var b := _fresh(rooms)
	_run_room_1(a)
	_run_room_1(b)
	_run(a, SECONDS, RIGHT)
	_run(b, SECONDS, RIGHT)
	_expect(
		SimState.snapshot(a) == SimState.snapshot(b),
		"same seed + inputs → identical snapshot (D12)"
	)
