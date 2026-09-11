class_name Overlay
extends CanvasLayer
## Debug overlay (F1): one slider per registry entry, generated from the
## registry (D14, never hand-built), plus room id and fps. Only instantiated
## when OS.is_debug_build(), which is how its labels coexist with D04.

const PANEL_WIDTH_RATIO := 0.5  # share of the viewport the panel takes

var _status := Label.new()
var _sliders: Dictionary = {}  # key -> HSlider
var _values: Dictionary = {}  # key -> Label


func _ready() -> void:
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.anchor_right = PANEL_WIDTH_RATIO
	var scroll := ScrollContainer.new()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_status)
	for key: String in Params.keys():
		column.add_child(_row(key))
	scroll.add_child(column)
	panel.add_child(scroll)
	add_child(panel)


func _row(key: String) -> HBoxContainer:
	var e := Params.entry(key)
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "%s (%s)" % [key, e["unit"]]
	name_label.tooltip_text = e["desc"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider := HSlider.new()
	slider.min_value = float(e["min"])
	slider.max_value = float(e["max"])
	slider.step = float(e["step"])
	slider.value = float(e["value"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void: _on_slider(key, v))
	var value_label := Label.new()
	value_label.text = str(e["value"])
	row.add_child(name_label)
	row.add_child(slider)
	row.add_child(value_label)
	_sliders[key] = slider
	_values[key] = value_label
	return row


func _on_slider(key: String, value: float) -> void:
	Params.set_value(key, value)
	_values[key].text = str(Params.get_value(key))


## After F5 reloads the registry the sliders follow the file, not the other way.
func refresh() -> void:
	for key: String in _sliders:
		_sliders[key].set_value_no_signal(Params.get_value(key))
		_values[key].text = str(Params.get_value(key))


func set_status(room_id: int, fps: float) -> void:
	_status.text = "room %d   fps %d" % [room_id, int(fps)]
