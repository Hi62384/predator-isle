class_name FreeCamera
extends Camera3D

@export_category("Free Camera")
@export_range(1.0, 500.0, 1.0) var move_speed: float = 35.0
@export_range(1.0, 10.0, 0.1) var sprint_multiplier: float = 3.0
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export var terrain: ChunkTerrain
@export var debug_label: Label

var _pitch_degrees := -25.0
var _debug_refresh_left: float = 0.0
var _scale_marker: Node3D


func _ready() -> void:
	_create_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rotation_degrees.x = _pitch_degrees
	far = 50000.0
	_scale_marker = preload("res://scripts/player_scale_marker.gd").new()
	_scale_marker.name = "PlayerScaleReference"
	get_parent().add_child.call_deferred(_scale_marker)
	_scale_marker.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		_pitch_degrees = clampf(
			_pitch_degrees - event.relative.y * mouse_sensitivity,
			-89.0,
			89.0
		)
		rotation_degrees.x = _pitch_degrees
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_speed = minf(move_speed * 1.2, 500.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_speed = maxf(move_speed / 1.2, 1.0)
	elif event.is_action_pressed("freecam_release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed("scale_toggle"):
		if _scale_marker.visible:
			_scale_marker.hide()
		elif terrain != null:
			_scale_marker.place(self, terrain)
	elif event.is_action_pressed("scale_place") and terrain != null:
		_scale_marker.place(self, terrain)
	elif event.is_action_pressed("terrain_debug") and terrain != null:
		terrain.cycle_debug_view()


func _process(delta: float) -> void:
	var input_2d := Input.get_vector(
		"freecam_left",
		"freecam_right",
		"freecam_forward",
		"freecam_back"
	)
	var vertical := Input.get_axis("freecam_down", "freecam_up")
	var direction := basis * Vector3(input_2d.x, 0.0, input_2d.y)
	direction += Vector3.UP * vertical
	if direction.length_squared() > 0.0:
		direction = direction.normalized()

	var current_speed := move_speed
	if Input.is_action_pressed("freecam_sprint"):
		current_speed *= sprint_multiplier
	global_position += direction * current_speed * delta

	_debug_refresh_left -= delta
	if debug_label != null and _debug_refresh_left <= 0.0:
		_debug_refresh_left = 0.2
		_update_debug_label(current_speed)


func _update_debug_label(current_speed: float) -> void:
	var chunk_text := "n/a"
	var biome_text := "n/a"
	var temperature := 0.0
	var climate_text := ""
	var loaded_count := 0
	if terrain != null:
		chunk_text = str(terrain.get_target_chunk())
		loaded_count = terrain.get_loaded_chunk_count()
		biome_text = terrain.get_biome_name_at(global_position)
		temperature = terrain.get_temperature_at(global_position)
		climate_text = terrain.get_climate_description(global_position)

	debug_label.text = (
		("PREDATOR ISLE  |  TERRAIN STREAMING TEST  |  FPS: %d\n" % Engine.get_frames_per_second())
		+ "WASD move   Q/E down/up   Shift boost   Mouse look   Wheel speed   F11 fullscreen   Esc release\n"
		+ "Position: (%.1f, %.1f, %.1f)   Chunk: %s   Biome below camera: %s   Loaded: %d   Speed: %.0f"
		% [global_position.x, global_position.y, global_position.z, chunk_text, biome_text, loaded_count, current_speed]
		+ ("\n%.1f C (%s)   |   F7 scale on/off   P place   Reference: 1.80 m" % [temperature,climate_text])
		+ ("\nF5 view: %s   %s" % [terrain.get_debug_view_name(),"GRASS PREVIEW (biomes overridden)" if terrain.grass_preview else "Normal biome world"] if terrain != null else "")
		+ ("\n"+terrain.get_partition_debug() if terrain != null else "")
	)


func _create_input_actions() -> void:
	_add_key_action("freecam_forward", KEY_W)
	_add_key_action("freecam_back", KEY_S)
	_add_key_action("freecam_left", KEY_A)
	_add_key_action("freecam_right", KEY_D)
	_add_key_action("freecam_down", KEY_Q)
	_add_key_action("freecam_up", KEY_E)
	_add_key_action("freecam_sprint", KEY_SHIFT)
	_add_key_action("freecam_release_mouse", KEY_ESCAPE)
	_add_key_action("toggle_fullscreen", KEY_F11)
	_add_key_action("scale_toggle", KEY_F7)
	_add_key_action("scale_place", KEY_P)
	_add_key_action("terrain_debug", KEY_F5)
	_add_alt_key_action("toggle_fullscreen", KEY_ENTER)


func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, input_event):
		InputMap.action_add_event(action_name, input_event)


func _add_alt_key_action(action_name: StringName, keycode: Key) -> void:
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	input_event.alt_pressed = true
	if not InputMap.action_has_event(action_name, input_event):
		InputMap.action_add_event(action_name, input_event)


func _toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
	or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
