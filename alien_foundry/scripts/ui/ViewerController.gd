class_name ViewerController
extends SubViewportContainer
## Camera navigation never rebuilds the organism. Bounds include all appendages.

var viewport_3d: SubViewport
var world: Node3D
var camera: Camera3D
var creature_holder: Node3D
var ground: MeshInstance3D
var key_light: DirectionalLight3D
var current_creature: Node3D
var target := Vector3(0.0, 1.0, 0.0)
var yaw := -0.48
var pitch := 0.24
var distance := 8.0
var radius := 2.0
var auto_rotate := false
var creature_bounds := AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
var _framed_target := Vector3.ZERO
var _framed_distance := 8.0
var _dragging_orbit := false
var _dragging_pan := false
var _initial_frame := false
var _last_aspect := 1.0
var _fit_on_orbit := true
const DEFAULT_YAW := -0.48
const DEFAULT_PITCH := 0.24
const FRAME_MARGIN := 1.08

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Left-drag: orbit · Middle-drag or Shift + left-drag: pan · Wheel: zoom · F: frame"
	viewport_3d = SubViewport.new()
	viewport_3d.name = "CreatureViewport"
	viewport_3d.own_world_3d = true
	viewport_3d.transparent_bg = false
	viewport_3d.msaa_3d = Viewport.MSAA_2X
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_3d.handle_input_locally = false
	add_child(viewport_3d)
	world = Node3D.new()
	world.name = "Studio"
	viewport_3d.add_child(world)
	creature_holder = Node3D.new()
	creature_holder.name = "Organism"
	world.add_child(creature_holder)
	_build_studio()
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera.fov = 42.0
	camera.current = true
	world.add_child(camera)
	_update_camera()
	resized.connect(_on_resized)

func _build_studio() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("4b4b4b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8cace")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# The wider white point retains detail in pale wet tissue instead of
	# clipping it. Calibrated in actual front/rear Compatibility captures.
	environment.tonemap_white = 6.0
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)
	var key := DirectionalLight3D.new()
	key_light = key
	key.name = "WarmKey"
	key.light_color = Color("fff8ee")
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-42, -32, -12)
	key.shadow_enabled = true
	# One tightly fitted PCF shadow map avoids distant, low-detail cascades.
	# PCSS/area-light softness is not supported by the Compatibility renderer.
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 16.0
	key.directional_shadow_fade_start = 1.0
	# Same-instance clay/textured ON/OFF controls exposed regular self-shadow
	# bands at .035/.6. This bounded pair removes them without detaching the
	# observed foot contacts; range and camera framing are unchanged.
	key.shadow_bias = 0.15
	key.shadow_normal_bias = 2.0
	key.shadow_blur = 1.25
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolFill"
	fill.light_color = Color("d8dee3")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-15, 140, 0)
	world.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.name = "SoftRim"
	rim.light_color = Color("f0f3f4")
	rim.light_energy = 0.35
	rim.rotation_degrees = Vector3(-65, 20, 0)
	world.add_child(rim)
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2, 2)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.18, 0.18)
	# Inspection floor stays matte so grazing specular does not create a bright
	# artificial horizon or compete with the creature's wet tissue highlights.
	material.roughness = 1.0
	material.metallic_specular = 0.0
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.scale = Vector3(15, 1, 15)
	world.add_child(ground)

func display_creature(root: Node3D, bounds: AABB) -> void:
	if is_instance_valid(current_creature):
		creature_holder.remove_child(current_creature)
		current_creature.queue_free()
	current_creature = root
	creature_holder.add_child(root)
	frame_bounds(bounds)

func frame_bounds(bounds: AABB) -> void:
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x < 0.0 or bounds.size.y < 0.0 or bounds.size.z < 0.0:
		return
	creature_bounds = bounds
	radius = maxf(bounds.size.length() * 0.5, 0.1)
	_framed_target = bounds.get_center()
	_last_aspect = _viewport_aspect()
	_framed_distance = _required_distance(_framed_target, DEFAULT_YAW, DEFAULT_PITCH, _last_aspect)
	var floor_y: float = bounds.position.y - maxf(0.002, radius * 0.0015)
	if is_instance_valid(current_creature) and current_creature.has_meta("asset_placement"):
		# Explicit placed assets use the asset datum, never a bounds-relative floor.
		floor_y = 0.0
	ground.position = Vector3(bounds.get_center().x, floor_y, bounds.get_center().z)
	var ground_span := maxf(80.0, radius * 60.0)
	ground.scale = Vector3(ground_span, 1, ground_span)
	camera.near = maxf(0.005, radius * 0.003)
	camera.far = maxf(100.0, radius * 100.0)
	_initial_frame = true
	reset_camera()

func reset_camera() -> void:
	target = _framed_target
	yaw = DEFAULT_YAW
	pitch = DEFAULT_PITCH
	_framed_distance = _required_distance(target, yaw, pitch, _viewport_aspect())
	distance = _framed_distance
	_fit_on_orbit = true
	_update_camera()

func _viewport_aspect() -> float:
	return maxf(size.x / maxf(size.y, 1.0), 0.05)

func _required_distance(for_target: Vector3, for_yaw: float, for_pitch: float, aspect: float) -> float:
	# Project all eight actual AABB corners into this viewing basis. Unlike a
	# bounding sphere, this does not waste vertical space on long thin bodies.
	var outward := Vector3(sin(for_yaw) * cos(for_pitch), sin(for_pitch), -cos(for_yaw) * cos(for_pitch))
	var right := Vector3.UP.cross(outward).normalized()
	var up := outward.cross(right).normalized()
	var tangent_y := tan(deg_to_rad(camera.fov * 0.5))
	var tangent_x := tangent_y * maxf(aspect, 0.05)
	var result := radius * 0.2
	for i in 8:
		var offset := creature_bounds.get_endpoint(i) - for_target
		var projection := maxf(absf(offset.dot(right)) / tangent_x, absf(offset.dot(up)) / tangent_y)
		result = maxf(result, offset.dot(outward) + projection * FRAME_MARGIN + radius * 0.01)
	return result

func orbit(delta: Vector2) -> void:
	yaw -= delta.x * 0.008
	pitch = clampf(pitch + delta.y * 0.008, -1.35, 1.35)
	_update_camera()

func pan(delta: Vector2) -> void:
	_fit_on_orbit = false
	var units_per_pixel := 2.0 * distance * tan(deg_to_rad(camera.fov * 0.5)) / maxf(size.y, 1.0)
	target += (-camera.global_basis.x * delta.x + camera.global_basis.y * delta.y) * units_per_pixel
	_update_camera()

func zoom(factor: float) -> void:
	_fit_on_orbit = false
	distance = clampf(distance * factor, radius * 0.12, radius * 40.0)
	_update_camera()

func set_auto_rotate(enabled: bool) -> void:
	auto_rotate = enabled

func _process(delta: float) -> void:
	if auto_rotate and not _dragging_orbit and not _dragging_pan:
		yaw += delta * 0.16
		_update_camera()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom(0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom(1.0 / 0.88)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging_orbit = event.pressed and not event.shift_pressed
			_dragging_pan = event.pressed and event.shift_pressed
			if event.pressed:
				grab_focus()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging_pan = event.pressed
		accept_event()
	elif event is InputEventMouseMotion:
		if _dragging_pan:
			pan(event.relative)
		elif _dragging_orbit:
			orbit(event.relative)
		if _dragging_pan or _dragging_orbit:
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging_orbit = false
		_dragging_pan = false

func _on_resized() -> void:
	if _initial_frame and is_instance_valid(camera):
		# Keep orbit, pan, and the user's relative zoom. Recompute active distance,
		# not only the reset distance, so narrowing a window cannot crop the fit.
		var aspect := _viewport_aspect()
		var previous_fit := _required_distance(target, yaw, pitch, _last_aspect)
		var next_fit := _required_distance(target, yaw, pitch, aspect)
		distance *= next_fit / maxf(previous_fit, 0.001)
		_last_aspect = aspect
		_framed_distance = _required_distance(_framed_target, DEFAULT_YAW, DEFAULT_PITCH, aspect)
		_update_camera()

func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	if _initial_frame and _fit_on_orbit:
		# Auto-framed orbit/spin keeps long appendages in view. Intentional zoom
		# or pan disables this guard until reset, allowing genuine close inspection.
		distance = maxf(distance, _required_distance(target, yaw, pitch, _viewport_aspect()))
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * distance
	camera.position = target + offset
	camera.look_at(target, Vector3.UP)
	if is_instance_valid(key_light):
		# Bias is expressed in shadow texels; fitting coverage to organism scale
		# keeps its effective world-space offset proportional without detachment.
		var coverage := maxf(distance + target.distance_to(creature_bounds.get_center()) + radius * 4.0, radius * 6.0)
		key_light.directional_shadow_max_distance = maxf(coverage, 1.0)
		key_light.directional_shadow_pancake_size = maxf(radius * 4.0, 1.0)

func capture_png(path: String) -> Error:
	await RenderingServer.frame_post_draw
	var image := viewport_3d.get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(path)
