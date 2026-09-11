class_name Fx
extends RefCounted
## Juice (D06): death particles, screen shake, goal flash. Ticked in lockstep
## with the sim and fed its RNG, so a replay reproduces every particle.

var particles: Array[Dictionary] = []  # pos, vel, life
var shake_left := 0.0
var shake_offset := Vector2.ZERO
var flash_left := 0.0


func on_events(events: Array[Dictionary], rng: RandomNumberGenerator, avatar: Rect2) -> void:
	for e in events:
		match e["e"]:
			"death":
				_burst(rng, avatar.get_center())
				shake_left = Params.get_value("shake_duration")
			"goal":
				flash_left = Params.get_value("goal_flash_duration")


func _burst(rng: RandomNumberGenerator, center: Vector2) -> void:
	var speed := Params.get_value("particle_speed")
	var life := Params.get_value("particle_lifetime")
	for _i in int(Params.get_value("death_particles")):
		var angle := rng.randf_range(0.0, TAU)
		var mag := rng.randf_range(0.0, speed)
		particles.append({"pos": center, "vel": Vector2.from_angle(angle) * mag, "life": life})


func tick(rng: RandomNumberGenerator) -> void:
	var gravity := Params.get_value("gravity")
	var i := particles.size() - 1
	while i >= 0:
		var p := particles[i]
		p["life"] -= Sim.TICK
		if p["life"] <= 0.0:
			particles.remove_at(i)
		else:
			p["vel"] = p["vel"] + Vector2(0.0, gravity * Sim.TICK)
			p["pos"] = p["pos"] + p["vel"] * Sim.TICK
		i -= 1
	shake_left = maxf(shake_left - Sim.TICK, 0.0)
	if shake_left > 0.0:
		var amp := Params.get_value("shake_amplitude")
		shake_offset = Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp))
	else:
		shake_offset = Vector2.ZERO
	flash_left = maxf(flash_left - Sim.TICK, 0.0)


func flash_alpha() -> float:
	var total := Params.get_value("goal_flash_duration")
	return flash_left / total if total > 0.0 else 0.0


func draw(canvas: CanvasItem, color: Color) -> void:
	var side := Params.get_value("particle_size")
	for p in particles:
		canvas.draw_rect(Rect2(p["pos"], Vector2(side, side)), color)
