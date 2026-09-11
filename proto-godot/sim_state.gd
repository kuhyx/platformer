class_name SimState
extends RefCounted
## Snapshot = { room_id, checkpoint_id, player_state, rng_seed, params_hash }
## (spec/DOCS-dev-principles.md §3). Feeds saves, replays and the F6 dump;
## restore() puts a Sim back exactly where a snapshot left it.


## spec/DOCS-dev-principles.md §3: feeds saves, replays, the F6 dump.
static func snapshot(sim: Sim) -> Dictionary:
	return {
		"room_id": sim.room_id,
		"checkpoint_id": sim.room_id,
		"player_state":
		{
			"x": sim.pos.x,
			"y": sim.pos.y,
			"vx": sim.vel.x,
			"vy": sim.vel.y,
			"on_ground": sim.on_ground,
			"coyote_left": sim.coyote_left,
			"buffer_left": sim.buffer_left,
			"jump_cut_pending": sim.jump_cut_pending,
			"state": sim.state,
			"state_t": sim.state_t,
			"blade_x": sim.blade_pos.x,
			"blade_y": sim.blade_pos.y,
			"blade_dir": sim.blade_dir,
		},
		"rng_seed": sim.seed_value,
		"rng_state": sim.rng.state,
		"params_hash": Params.registry_hash(),
		"tick": sim.tick_count,
	}


static func restore(sim: Sim, snap: Dictionary) -> void:
	var p: Dictionary = snap["player_state"]
	sim.room_id = int(snap["room_id"])
	sim.pos = Vector2(float(p["x"]), float(p["y"]))
	sim.vel = Vector2(float(p["vx"]), float(p["vy"]))
	sim.on_ground = bool(p["on_ground"])
	sim.coyote_left = float(p["coyote_left"])
	sim.buffer_left = float(p["buffer_left"])
	sim.jump_cut_pending = bool(p["jump_cut_pending"])
	sim.state = int(p["state"]) as Sim.State
	sim.state_t = float(p["state_t"])
	sim.blade_pos = Vector2(float(p["blade_x"]), float(p["blade_y"]))
	sim.blade_dir = float(p["blade_dir"])
	sim.seed_value = int(snap["rng_seed"])
	sim.rng.seed = sim.seed_value
	sim.rng.state = int(snap["rng_state"])
	sim.tick_count = int(snap["tick"])
