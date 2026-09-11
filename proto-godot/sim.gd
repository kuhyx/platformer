class_name Sim
extends RefCounted
## The slice's pure fixed-step simulation (D12): movement, collision, rooms,
## hazards, death and goal. No nodes, no SceneTree, so it can be driven by a
## test or a replay without the engine running (M10). Every number comes from
## the registry or rooms.json. Rendering reads its state; nothing else does.

enum State { ALIVE, DEAD, GOAL }

const TICK_HZ := 60  # D12 non-tunable
const TICK := 1.0 / TICK_HZ

var rooms: Rooms
var rng := RandomNumberGenerator.new()
var seed_value: int
var tick_count := 0
var room_id := 0
var pos := Vector2.ZERO  # avatar top-left
var vel := Vector2.ZERO
var on_ground := false
var coyote_left := 0.0
var buffer_left := 0.0
var jump_cut_pending := false  # takeoff until release or apex (variable height)
var prev_jump := false
var state := State.ALIVE
var state_t := 0.0  # seconds spent in DEAD / GOAL
var blade_pos := Vector2.ZERO
var blade_dir := 1.0
var events: Array[Dictionary] = []  # emitted during the last tick


func _init(loaded_rooms: Rooms, seed_v: int) -> void:
	rooms = loaded_rooms
	seed_value = seed_v
	rng.seed = seed_v


func size() -> Vector2:
	return Vector2(Params.get_value("player_w"), Params.get_value("player_h"))


func rect() -> Rect2:
	return Rect2(pos, size())


func room() -> Dictionary:
	return rooms.room(room_id)


func blade_rect() -> Rect2:
	var blade: Variant = room()["blade"]
	return Rect2(blade_pos, blade["rect"].size) if blade != null else Rect2()


## True during hitstop: the whole world, effects included, holds still.
func frozen() -> bool:
	return state == State.DEAD and state_t < Params.get_value("hitstop")


## Fresh entry into a room: spawn point, blade reset, checkpoint saved.
func enter_room(id: int, keep_motion: bool = false) -> void:
	room_id = id
	var blade: Variant = room()["blade"]
	if blade != null:
		blade_pos = blade["rect"].position
		blade_dir = 1.0
	if not keep_motion:
		_spawn()
	state = State.ALIVE
	state_t = 0.0
	_emit("room_enter", {"room": id})
	_emit("checkpoint", {"room": id})


func _spawn() -> void:
	pos = room()["spawn"]
	vel = Vector2.ZERO
	on_ground = false
	coyote_left = 0.0
	buffer_left = 0.0
	jump_cut_pending = false


func tick(input: Dictionary) -> void:
	events.clear()
	tick_count += 1
	match state:
		State.ALIVE:
			_tick_alive(input)
		State.DEAD:
			state_t += TICK
			if state_t >= Params.get_value("hitstop") + Params.get_value("respawn_delay"):
				_spawn()
				state = State.ALIVE
				_emit("respawn", {"room": room_id})
		State.GOAL:
			state_t += TICK
			if state_t >= Params.get_value("goal_flash_duration"):
				enter_room(0)
	prev_jump = input["jump"]


func _tick_alive(input: Dictionary) -> void:
	vel.x = (float(input["right"]) - float(input["left"])) * Params.get_value("move_speed")
	var jump_pressed: bool = input["jump"] and not prev_jump
	buffer_left = Params.get_value("jump_buffer") if jump_pressed else maxf(buffer_left - TICK, 0.0)
	coyote_left = Params.get_value("coyote_time") if on_ground else maxf(coyote_left - TICK, 0.0)
	if buffer_left > 0.0 and (on_ground or coyote_left > 0.0):
		vel.y = -Params.get_value("jump_velocity")
		buffer_left = 0.0
		coyote_left = 0.0
		on_ground = false
		jump_cut_pending = true
		_emit("jump", {})
	if jump_cut_pending and not input["jump"]:
		if vel.y < 0.0:
			vel.y *= Params.get_value("jump_cut_multiplier")
		jump_cut_pending = false
	if vel.y >= 0.0:
		jump_cut_pending = false
	vel.y = minf(vel.y + Params.get_value("gravity") * TICK, Params.get_value("max_fall_speed"))
	_move()
	_edges()
	_move_blade()
	_touch()


## Axis-separated AABB sweep against the room's solids.
func _move() -> void:
	var solids: Array[Rect2] = room()["solids"]
	pos.x += vel.x * TICK
	for s in solids:
		if rect().intersects(s):
			pos.x = s.position.x - size().x if vel.x > 0.0 else s.end.x
	pos.y += vel.y * TICK
	on_ground = false
	for s in solids:
		if rect().intersects(s):
			if vel.y > 0.0:
				pos.y = s.position.y - size().y
				on_ground = true
			else:
				pos.y = s.end.y
			vel.y = 0.0


## Room edges: hard cut to the neighbour (D16), clamp at the ends of the slice.
func _edges() -> void:
	var w := size().x
	if pos.x < 0.0:
		if room_id > 0:
			enter_room(room_id - 1, true)
			pos.x = rooms.width - w
		else:
			pos.x = 0.0
	elif pos.x + w > rooms.width:
		if room_id < rooms.count() - 1:
			enter_room(room_id + 1, true)
			pos.x = 0.0
		else:
			pos.x = rooms.width - w


func _move_blade() -> void:
	var blade: Variant = room()["blade"]
	if blade == null:
		return
	var track: Vector2 = blade["track"]
	blade_pos.x += blade_dir * Params.get_value("blade_speed") * TICK
	if blade_pos.x >= track.y:
		blade_pos.x = track.y
		blade_dir = -1.0
	elif blade_pos.x <= track.x:
		blade_pos.x = track.x
		blade_dir = 1.0


func _touch() -> void:
	var me := rect()
	var hazards: Array[Rect2] = room()["hazards"]
	for h in hazards:
		if me.intersects(h):
			_die()
			return
	if room()["blade"] != null and me.intersects(blade_rect()):
		_die()
		return
	var goal: Variant = room()["goal"]
	if goal != null and me.intersects(goal):
		state = State.GOAL
		state_t = 0.0
		_emit("goal", {"room": room_id})


func _die() -> void:
	state = State.DEAD
	state_t = 0.0
	_emit("death", {"room": room_id, "x": pos.x, "y": pos.y})


func _emit(name: String, data: Dictionary) -> void:
	data["e"] = name
	events.append(data)
