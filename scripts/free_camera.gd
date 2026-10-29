class_name FreeCamera
extends Camera3D

@export_category("Free Camera")
@export_range(1.0, 500.0, 1.0) var move_speed: float = 35.0
@export_range(1.0, 10.0, 0.1) var sprint_multiplier: float = 3.0
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export var terrain: ChunkTerrain
@export var debug_label: Label
@export var debug_overlay_visible: bool = false

var _pitch_degrees := -25.0
var _debug_refresh_left: float = 0.0
var _scale_marker: Node3D
var _extension_index:int=-1

func _ready() -> void:
	_create_input_actions()
	_set_debug_overlay_visible(debug_overlay_visible)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if terrain != null and (terrain._badlands_feature_active or terrain.badlands_preview or terrain.start_in_badlands or terrain._tropical_feature_active or terrain.tropical_preview or terrain.start_in_tropical or terrain._coast_feature_active or terrain.start_in_coast or terrain._mountain_feature_active or terrain.start_in_mountain or terrain._jungle_feature_active or terrain._forest_feature_active or terrain._savanna_feature_active or terrain._swamp_feature_active or terrain.start_in_swamp or terrain.start_in_jungle or terrain.start_in_forest or terrain.start_in_savanna):
		_pitch_degrees = rotation_degrees.x
	rotation_degrees.x = _pitch_degrees
	far = 50000.0
	_scale_marker = preload("res://scripts/player_scale_marker.gd").new()
	_scale_marker.name = "PlayerScaleReference"
	get_parent().add_child.call_deferred(_scale_marker)
	_scale_marker.visible = false


func _set_debug_overlay_visible(value: bool) -> void:
	debug_overlay_visible = value
	for overlay:CanvasLayer in get_tree().get_nodes_in_group("terrain_debug_overlay"):
		overlay.visible=value
	if is_instance_valid(debug_label):
		var panel := debug_label.get_parent() as Control
		debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if panel != null:
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.visible = value


func _input(event: InputEvent) -> void:
	# Captured look belongs to the camera before GUI hit-testing. Read-only
	# overlays must never consume relative mouse motion or trap Escape.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		_pitch_degrees = clampf(
			_pitch_degrees - event.relative.y * mouse_sensitivity,
			-89.0,
			89.0
		)
		rotation_degrees.x = _pitch_degrees
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("freecam_release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_debug_overlay") and not event.is_echo():
		_set_debug_overlay_visible(not debug_overlay_visible)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_speed = minf(move_speed * 1.2, 500.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_speed = maxf(move_speed / 1.2, 1.0)
	elif event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed("scale_toggle"):
		if _scale_marker.visible:
			_scale_marker.hide()
		elif terrain != null:
			_scale_marker.place(self, terrain)
	elif event.is_action_pressed("scale_place") and terrain != null:
		_scale_marker.place(self, terrain)
	elif event.is_action_pressed("terrain_debug_shaded") and terrain != null:
		terrain.set_debug_view(0)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F10 and event.shift_pressed and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=149 and terrain.terrain_debug_view<153 else 149)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F10 and event.shift_pressed and terrain!=null:
		for attempt in range(8):
			_extension_index=(_extension_index+1)%8
			if terrain.jump_to_extension(TerrainSettings.EXTENSION_KEYS[_extension_index]):break
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F12 and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=119 and terrain.terrain_debug_view<130 else 119)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F12 and terrain!=null:
		terrain.jump_to_beach()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F1 and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=99 and terrain.terrain_debug_view<118 else 99)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F1 and terrain!=null:
		terrain.jump_to_coast()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F2 and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=81 and terrain.terrain_debug_view<98 else 81)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F2 and terrain!=null:
		terrain.jump_to_mountain()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F3 and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=61 and terrain.terrain_debug_view<80 else 61)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F3 and terrain!=null:
		terrain.jump_to_swamp()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F4 and terrain!=null:
		terrain.jump_to_savanna()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F10 and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=47 and terrain.terrain_debug_view<60 else 47)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F6 and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=28 and terrain.terrain_debug_view<35 else 28)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F8 and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=131 and terrain.terrain_debug_view<140 else 131)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F8 and event.shift_pressed and terrain!=null:
		terrain.jump_to_tropical()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F8 and terrain!=null:
		terrain.jump_to_jungle()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F9 and event.ctrl_pressed and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=141 and terrain.terrain_debug_view<148 else 141)
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F9 and event.shift_pressed and terrain!=null:
		terrain.jump_to_badlands()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F9 and terrain!=null:
		terrain.jump_to_forest()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_F10 and terrain!=null:
		terrain.set_debug_view(terrain.terrain_debug_view+1 if terrain.terrain_debug_view>=36 and terrain.terrain_debug_view<46 else 36)
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
	if _debug_refresh_left <= 0.0:
		_debug_refresh_left = 0.2
		# Depth precision must follow altitude even with diagnostics hidden.
		if terrain != null:
			near = clampf((global_position.y-terrain.get_height_at(global_position))*0.01,0.1,10.0)
		if debug_label != null and debug_label.is_visible_in_tree():
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
		+ ("\nF5: %s   Ctrl+F5 shaded   F2 Mountain / Ctrl+F2 views" % terrain.get_debug_view_name() if terrain!=null else "")
		+ "\nF3 Swamp / Ctrl+F3 views   F4 Savanna / Ctrl+F10 views   F8 Jungle   F9 Forest"
		+ "\nF1 Rocky Coast / Ctrl+F1 Coast views"
		+ "\nF12 Beaches / Ctrl+F12 Sand views"
		+ "\nShift+F8 Tropical / Ctrl+F8 Tropical views"
		+ "\nShift+F9 Badlands / Ctrl+F9 Badlands views"
		+ ("\nROCKY COAST PREVIEW: %s (terrain and water only)" % terrain.coast_preview_feature if terrain!=null and terrain.coast_preview else "")
		+ ("\nMOUNTAIN TERRAIN PREVIEW: %s (terrain and water only)" % terrain.mountain_preview_feature if terrain!=null and terrain.mountain_preview else "")
		+ ("\nSWAMP TERRAIN PREVIEW: %s (terrain and water only)" % terrain.swamp_preview_feature if terrain!=null and terrain.swamp_preview else "")
		+ ("\nSAVANNA TERRAIN PREVIEW: %s (no vegetation)" % terrain.savanna_preview_feature if terrain!=null and terrain.savanna_preview else "")
		+ ("\nFOREST TERRAIN PREVIEW: %s (no vegetation)" % terrain.forest_preview_feature if terrain!=null and terrain.forest_preview else "")
		+ ("\nJUNGLE PREVIEW: %s / seed %d — F6 Jungle diagnostics; no foliage renderer" % [terrain.jungle_preview_feature,terrain.world_seed] if terrain!=null and terrain.jungle_preview else "")
		+ ("\n"+terrain.get_partition_debug() if terrain != null else "")
	)


func _create_input_actions() -> void:
	_add_key_action("toggle_debug_overlay", KEY_QUOTELEFT)
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
	_add_debug_shortcut("terrain_debug_shaded", false)
	_add_alt_key_action("toggle_fullscreen", KEY_ENTER)


func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, input_event):
		InputMap.action_add_event(action_name, input_event)


func _add_debug_shortcut(action_name: StringName, use_shift: bool) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var input_event := InputEventKey.new()
	input_event.physical_keycode = KEY_F5
	input_event.shift_pressed = use_shift
	input_event.ctrl_pressed = not use_shift
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
