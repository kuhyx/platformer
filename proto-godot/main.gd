extends Node2D
## Scene glue for the slice (spec/DOCS-slice.md): polls input, ticks the sim
## at 60 Hz, draws the world, owns the web start gate and the debug hooks.
## Every rule lives in sim.gd; this file only renders and forwards.

const REGISTRY_PATH := "res://params.json"
const ROOMS_PATH := "res://rooms.json"
const SNAPSHOT_PATH := "user://snapshot.json"
const ARG_RESTORE := "--restore"  # user arg: load SNAPSHOT_PATH at boot
const ARG_SEED := "--seed="  # user arg: fix the RNG seed (replays)

# Palette fixed by the slice spec: no sprites, one colour per element.
const COLOR_PLAYER := Color.WHITE
const COLOR_HAZARD := Color.RED
const COLOR_CHECKPOINT := Color.GREEN
const COLOR_GOAL := Color.YELLOW
const COLOR_FLOOR := Color.GRAY
const COLOR_FLASH := Color.WHITE
const COLOR_DIM := Color.BLACK

var rooms := Rooms.new()
var sim: Sim
var fx := Fx.new()
var analytics: Analytics  # debug builds only (D09)
var overlay: Overlay  # debug builds only
var paused := false
var gate_active := false  # web start gate (D02); absent on desktop
var gate_phase := 0.0
var ready_signalled := false


func _ready() -> void:
	Params.load_registry(REGISTRY_PATH)
	rooms.load_file(ROOMS_PATH)
	sim = Sim.new(rooms, _seed_from_args())
	sim.enter_room(SaveFile.read_room(rooms.count()))
	if OS.is_debug_build():
		analytics = Analytics.new()
		analytics.start(sim.seed_value)
		overlay = Overlay.new()
		add_child(overlay)
		if ARG_RESTORE in OS.get_cmdline_user_args():
			_restore_snapshot()
	_after_tick()
	gate_active = OS.has_feature("web")
	RenderingServer.frame_post_draw.connect(_on_first_frame, CONNECT_ONE_SHOT)


func _seed_from_args() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARG_SEED):
			return int(arg.trim_prefix(ARG_SEED))
	return int(Time.get_unix_time_from_system())


## Web contract (DOCS-tech-reqs.md): __gameReady on the first rendered frame,
## and only then the start gate.
func _on_first_frame() -> void:
	ready_signalled = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__gameReady = performance.now()")


func _physics_process(_delta: float) -> void:
	if paused or gate_active:
		return
	var input := {
		"left": Input.is_action_pressed("move_left"),
		"right": Input.is_action_pressed("move_right"),
		"jump": Input.is_action_pressed("jump"),
	}
	if analytics:
		analytics.log_input(sim.tick_count + 1, input)
	sim.tick(input)
	_after_tick()
	if not sim.frozen():
		fx.tick(sim.rng)


## Reacts to whatever the sim emitted: effects, autosave, logs.
func _after_tick() -> void:
	fx.on_events(sim.events, sim.rng, sim.rect())
	for e in sim.events:
		if e["e"] == "checkpoint":
			SaveFile.write(e["room"])
	if analytics:
		analytics.log_events(sim.tick_count, sim.events)
		if sim.tick_count % int(Params.get_value("state_log_every")) == 0:
			analytics.log_state(SimState.snapshot(sim))


func _process(delta: float) -> void:
	gate_phase += delta
	if overlay and overlay.visible:
		overlay.set_status(sim.room_id, Engine.get_frames_per_second())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if gate_active:
		if ready_signalled and _is_press(event):
			gate_active = false
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		paused = not paused
	elif overlay == null:
		return
	elif event.is_action_pressed("debug_overlay"):
		overlay.visible = not overlay.visible
	elif event.is_action_pressed("debug_reload"):
		Params.load_registry(REGISTRY_PATH)
		overlay.refresh()
	elif event.is_action_pressed("debug_snapshot"):
		_dump_snapshot()


static func _is_press(event: InputEvent) -> bool:
	var kind := event is InputEventKey or event is InputEventMouseButton
	kind = kind or event is InputEventJoypadButton
	return kind and event.is_pressed() and not event.is_echo()


func _dump_snapshot() -> void:
	var f := FileAccess.open(SNAPSHOT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(SimState.snapshot(sim), "  "))
		f.close()
		print("snapshot: ", ProjectSettings.globalize_path(SNAPSHOT_PATH))


func _restore_snapshot() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_PATH))
	if parsed is Dictionary:
		SimState.restore(sim, parsed)
		print("snapshot: restored room ", sim.room_id)


func _draw() -> void:
	var rm := sim.room()
	draw_set_transform(fx.shake_offset)
	for s: Rect2 in rm["solids"]:
		draw_rect(s, COLOR_FLOOR)
	for h: Rect2 in rm["hazards"]:
		draw_rect(h, COLOR_HAZARD)
	draw_rect(rm["checkpoint"], COLOR_CHECKPOINT)
	if rm["goal"] != null:
		draw_rect(rm["goal"], COLOR_GOAL)
	if rm["blade"] != null:
		draw_rect(sim.blade_rect(), COLOR_HAZARD)
	if sim.state != Sim.State.DEAD:
		draw_rect(sim.rect(), COLOR_PLAYER)
	fx.draw(self, COLOR_PLAYER)
	draw_set_transform(Vector2.ZERO)
	var screen := Rect2(Vector2.ZERO, Vector2(rooms.width, rooms.height))
	if fx.flash_alpha() > 0.0:
		draw_rect(screen, Color(COLOR_FLASH, fx.flash_alpha()))
	if paused:
		draw_rect(screen, Color(COLOR_DIM, Params.get_value("pause_dim")))
	if gate_active and ready_signalled:
		_draw_gate(screen)


## Pulsing icon, no text (D02/D04): a circle breathing between
## radius × (1 − depth) and radius.
func _draw_gate(screen: Rect2) -> void:
	var period := Params.get_value("gate_pulse_period")
	var depth := Params.get_value("gate_pulse_depth")
	var wave := (1.0 + sin(gate_phase / period * TAU)) / 2.0
	var radius := Params.get_value("gate_icon_radius") * (1.0 - depth * (1.0 - wave))
	draw_rect(screen, Color(COLOR_DIM, Params.get_value("pause_dim")))
	draw_circle(screen.get_center(), radius, COLOR_PLAYER)
