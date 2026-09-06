extends Node2D
## Boot stub: loads the registry, draws the avatar placeholder, signals web
## readiness. The slice (spec/DOCS-slice.md) is not implemented yet.

const REGISTRY_PATH := "res://params.json"
const PLACEHOLDER_SPAWN := Vector2(100, 400)  # slice will read spawn from room data


func _ready() -> void:
	Params.load_registry(REGISTRY_PATH)
	queue_redraw()
	_signal_web_ready.call_deferred()


func _draw() -> void:
	var size := Vector2(Params.get_value("player_w"), Params.get_value("player_h"))
	draw_rect(Rect2(PLACEHOLDER_SPAWN, size), Color.WHITE)


func _signal_web_ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__gameReady = performance.now()")
