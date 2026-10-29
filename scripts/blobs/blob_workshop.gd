extends Node3D
## B places a fresh organism on the terrain under the camera. Heavy field work
## runs on a cancellable worker; scene/mesh resources are created on main thread.
const Pipeline = preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Blueprint = preload("res://scripts/blobs/blob_blueprint.gd")
const Cache = preload("res://scripts/blobs/blob_mesh_cache.gd")
const Organism = preload("res://scripts/blobs/blob_organism.gd")
@export var laboratory := false
@export var seed_value := 22
@export_range(0, 2) var quality := 1
var last_pass := 7
var options: Dictionary = {}
var creature: Node3D
var worker := Thread.new()
var job: BuildControls
var status: Label
var pending_position := Vector3.ZERO
var terrain: Node
var camera: Camera3D
var elapsed := 0.0
var requested_mode := "auto"
var build_widgets: Array[BaseButton] = []
var control_widgets: Dictionary = {}
var runtime_widgets:Dictionary={}
var runtime_mode_selector:OptionButton
var lighting_preset:=0

class BuildControls extends RefCounted:
	var mutex := Mutex.new()
	var cancelled := false
	var progress := 0.0
	var message := "Planning anatomy"
	func is_cancelled() -> bool:
		mutex.lock()
		var result := cancelled
		mutex.unlock()
		return result
	func cancel() -> void:
		mutex.lock()
		cancelled = true
		mutex.unlock()
	func set_progress(value: float, detail: String) -> void:
		mutex.lock()
		progress = value
		message = detail
		mutex.unlock()
	func snapshot() -> Dictionary:
		mutex.lock()
		var result := {"progress": progress, "message": message}
		mutex.unlock()
		return result

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	terrain = get_parent().get_node_or_null("Terrain")
	var ui := CanvasLayer.new()
	if not laboratory:
		ui.add_to_group("terrain_debug_overlay")
		ui.visible = false
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(16, -115 if laboratory else -65)
	ui.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	status = Label.new()
	status.text = "B: grow blob at view  |  Shift+B: next seed  |  M: roll/creep  |  X: remove"
	stack.add_child(status)
	if not laboratory:
		for control:Control in [panel,stack,status]:control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if laboratory:
		var buttons := HBoxContainer.new()
		stack.add_child(buttons)
		_button(buttons, "Previous seed", func(): seed_value -= 1; generate())
		_button(buttons, "Next seed", func(): seed_value += 1; generate())
		_button(buttons, "Next gait", _toggle_mode)
		var passes := OptionButton.new()
		for label in Pipeline.PASS_NAMES.slice(1): passes.add_item(label)
		passes.selected = 6
		passes.item_selected.connect(func(index: int): last_pass=index+1; generate())
		buttons.add_child(passes)
		build_widgets.append(passes)
		var mode := OptionButton.new()
		for label in ["DNA movement"]+Blueprint.MODES: mode.add_item(label.capitalize())
		mode.item_selected.connect(func(index: int): requested_mode=(["auto"]+Blueprint.MODES)[index]; generate())
		buttons.add_child(mode)
		build_widgets.append(mode)
		_button(buttons,"Surface markers",func():
			if is_instance_valid(creature): creature.debug_circulation=not creature.debug_circulation)
		_lighting(0)
		_inspection_controls(ui)
		_controls(ui)
		generate()

func _controls(ui: CanvasLayer) -> void:
	var panel:=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position=Vector2(-310,105)
	panel.custom_minimum_size=Vector2(294,465)
	ui.add_child(panel)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(294,465)
	panel.add_child(scroll)
	var rows:=VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	_select(rows,"Biology",["auto"]+Blueprint.PROFILES,"profile")
	_select(rows,"Body plan",["auto"]+Blueprint.PLANS,"body_plan")
	_select(rows,"Quality",["Draft","Detailed","High"],"quality")
	for group in [
		["Body",["width","height","length","asymmetry","mass_count","mass_variation","fusion","contact","stiffness"]],
		["Biology",["diversity","sacs","lattice","faces","limbs","tentacles","branches","membranes","cavities","stalks","fibers","folds","detail","combinations"]],
		["Materials",["wetness","roughness","veins","translucency","microdetail"]],
		["Movement",["circulation","softness","gravity"]]]:
		var heading:=Label.new()
		heading.text=group[0]
		rows.add_child(heading)
		for key: String in group[1]: _slider(rows,key)
	_select(rows,"Palette",["DNA palette","Ochre","Gray flesh","Muted olive","Sickly flesh","Bruised"],"palette")
	_button(rows,"Grow with these settings",generate)
	_button(rows,"Reset settings",_reset_settings)

func _select(parent: Control, title: String, values: Array, key: String) -> void:
	var label:=Label.new()
	label.text=title
	parent.add_child(label)
	var select:=OptionButton.new()
	for value in values: select.add_item(str(value).capitalize())
	if key=="quality": select.selected=quality
	select.item_selected.connect(func(index: int):
		if key=="quality": quality=index
		elif key=="palette": options[key]=index-1
		else: options[key]=values[index])
	parent.add_child(select)
	build_widgets.append(select)
	control_widgets[key]=select

func _slider(parent: Control, key: String) -> void:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	var label:=Label.new()
	label.text=key.replace("_"," ").capitalize()
	label.custom_minimum_size.x=150
	row.add_child(label)
	var slider:=HSlider.new()
	slider.custom_minimum_size.x=85
	slider.min_value=.0
	slider.max_value=12.0 if key=="mass_count" else 2.0
	slider.step=1.0 if key=="mass_count" else .05
	slider.value=Blueprint.CONTROL_DEFAULTS[key]
	slider.tooltip_text="%.2f" % slider.value
	slider.value_changed.connect(func(value: float): options[key]=value; slider.tooltip_text="%.2f" % value)
	row.add_child(slider)
	control_widgets[key]=slider

func _reset_settings() -> void:
	for key in control_widgets:
		var widget: Control=control_widgets[key]
		if widget is HSlider: widget.value=Blueprint.CONTROL_DEFAULTS[key]
		elif widget is OptionButton: widget.selected=1 if key=="quality" else 0
	options.clear()
	quality=1
	generate()

func _button(parent: Control, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	build_widgets.append(button)

func generate() -> void:
	if worker.is_started(): return
	if not laboratory:
		camera = get_viewport().get_camera_3d()
		if camera == null or terrain == null: return
		var ray := -camera.global_basis.z
		var distance := 0.0
		var found := false
		for i in range(1, 513):
			var point := camera.global_position + ray * float(i) * 4.0
			if point.y <= terrain.get_height_at(point):
				var lo := distance
				var hi := float(i) * 4.0
				for j in range(12):
					var mid := (lo + hi) * 0.5
					var sample := camera.global_position + ray * mid
					if sample.y > terrain.get_height_at(sample): lo = mid
					else: hi = mid
				pending_position = camera.global_position + ray * hi
				found = true
				break
			distance = float(i) * 4.0
		if not found:
			pending_position = camera.global_position + Vector3(ray.x, 0, ray.z).normalized() * 10.0
		pending_position.y = terrain.get_height_at(pending_position)
	job = BuildControls.new()
	for widget in build_widgets: widget.disabled = true
	elapsed = 0.0
	var settings := options.duplicate(true)
	var task := func() -> Dictionary: return Cache.build(seed_value, quality, requested_mode, last_pass, job, settings)
	var error := worker.start(task)
	if error != OK:
		status.text = "Blob worker could not start (%s)" % error
		for widget in build_widgets: widget.disabled = false

func _process(delta: float) -> void:
	if not worker.is_started():
		if laboratory and is_instance_valid(creature) and not creature.gait_fallback_reason.is_empty():
			status.text="Seed %d / %s / %s"%[seed_value,creature.locomotion,creature.gait_fallback_reason]
			runtime_mode_selector.selected=Blueprint.MODES.find(creature.locomotion)
		return
	elapsed += delta
	if worker.is_alive():
		var progress := job.snapshot()
		status.text = "Seed %d · %s · %.1f s" % [seed_value, progress.message, elapsed]
		return
	var result: Dictionary = worker.wait_to_finish()
	for widget in build_widgets: widget.disabled = false
	if result.has("error") or result.get("cancelled", false):
		status.text = "Blob build cancelled" if result.get("cancelled", false) else str(result.error)
		return
	if is_instance_valid(creature): creature.queue_free()
	creature = Organism.new()
	creature.name = "Blob_%d" % seed_value
	add_child(creature)
	creature.global_position=pending_position
	creature.terrain=terrain
	creature.ground_height=pending_position.y
	creature.configure(result)
	creature.global_position = pending_position
	creature.speed = float(runtime_widgets["Travel speed"].value) if laboratory else .65
	if laboratory:
		creature.playback_rate=float(runtime_widgets["Playback rate"].value)
		creature.solver.idle_enabled=runtime_widgets["Idle tissue"].button_pressed
		creature.solver.secondary_enabled=runtime_widgets["Secondary chains"].button_pressed
		creature.gait_enabled=runtime_widgets["Contact gait"].button_pressed
		creature.debug_features=runtime_widgets["Feature colors"].button_pressed
		creature.debug_contacts=runtime_widgets["Contact / cage debug"].button_pressed
		runtime_mode_selector.selected=Blueprint.MODES.find(creature.locomotion)
		_lighting(lighting_preset)
	creature.terrain = terrain
	creature.ground_height = pending_position.y
	# Lab rolls in place to inspect tissue coupling; game moves on terrain.
	creature.travel_enabled = true
	if laboratory and camera!=null and camera.has_method("frame_creature"):
		camera.frame_creature(result,creature.solver.height)
		camera.follow_actor(creature)
	status.text = "Seed %d · %s · %d features · %.1f s  |  B: grow  Shift+B: seed  M: mode  X: clear" % [seed_value, creature.locomotion+" / "+result.dna.profile+" / "+result.dna.body_plan, result.features.size(), elapsed]

func _toggle_mode() -> void:
	if is_instance_valid(creature):
		var original:String=creature.locomotion
		var modes:Array=["roll","vine","limb","contractile","peristaltic","drag","pulse","multicontact"]
		var start:int=modes.find(original)
		for offset in range(1,modes.size()+1):
			creature.set_locomotion(modes[posmod(start+offset,modes.size())])
			if creature.locomotion!=original:break
		status.text = "Seed %d · %s  |  B: grow  Shift+B: seed  M: mode  X: clear" % [seed_value, creature.locomotion]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_B:
			if worker.is_started(): return
			if event.shift_pressed: seed_value += 1
			generate()
		KEY_M: _toggle_mode()
		KEY_X:
			if job != null: job.cancel()
			if is_instance_valid(creature): creature.queue_free()
		KEY_ESCAPE:
			if worker.is_started(): job.cancel()

func _exit_tree() -> void:
	if worker.is_started():
		job.cancel()
		worker.wait_to_finish()

func _inspection_controls(ui: CanvasLayer) -> void:
	var panel:=PanelContainer.new(); panel.position=Vector2(16,112); ui.add_child(panel)
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(215,480); panel.add_child(scroll)
	var rows:=VBoxContainer.new(); rows.custom_minimum_size.x=195; scroll.add_child(rows)
	var light:=OptionButton.new()
	for title in ["Studio","Daylight","Overcast","Low sun","Dark / rim","Clay"]: light.add_item(title)
	light.item_selected.connect(_lighting); rows.add_child(light)
	var exposure_label:=Label.new(); exposure_label.text="Exposure"; rows.add_child(exposure_label)
	var exposure:=HSlider.new(); exposure.min_value=.25; exposure.max_value=2; exposure.step=.05; exposure.value=1; exposure.tooltip_text="Exposure"
	exposure.value_changed.connect(func(v: float): get_parent().get_node("Environment").environment.tonemap_exposure=v); rows.add_child(exposure)
	var background:=ColorPickerButton.new(); background.color=Color(.13,.145,.15); background.text="Background"; background.tooltip_text="Background color"
	background.color_changed.connect(func(v: Color): get_parent().get_node("Environment").environment.background_color=v); rows.add_child(background)
	var play:=Button.new(); play.text="Play / pause"
	play.pressed.connect(func():
		if is_instance_valid(creature): creature.simulation_enabled=not creature.simulation_enabled)
	rows.add_child(play)
	var step:=Button.new(); step.text="Step 1/60 s"
	step.pressed.connect(func():
		if is_instance_valid(creature):
			creature.simulation_enabled=false
			runtime_widgets["Exact rest mesh"].button_pressed=false
			var rate:float=creature.playback_rate
			creature.playback_rate=1.0; creature.simulate(1.0/60.0); creature.playback_rate=rate)
	rows.add_child(step)
	for field in ["Playback rate","Travel speed"]:
		var label:=Label.new(); label.text=field; rows.add_child(label)
		var slider:=HSlider.new(); slider.min_value=0 if field=="Playback rate" else -1; slider.max_value=2; slider.step=.05; slider.value=1 if field=="Playback rate" else .65
		slider.value_changed.connect(func(v: float):
			if is_instance_valid(creature):
				if field=="Playback rate": creature.playback_rate=v
				else: creature.speed=v)
		rows.add_child(slider); runtime_widgets[field]=slider
	var live_mode:=OptionButton.new()
	for mode in Blueprint.MODES: live_mode.add_item(mode.capitalize())
	live_mode.item_selected.connect(func(i: int):
		if is_instance_valid(creature): creature.set_locomotion(Blueprint.MODES[i]))
	rows.add_child(live_mode); runtime_mode_selector=live_mode
	for field in ["Idle tissue","Secondary chains","Contact gait","Feature colors","Contact / cage debug","Exact rest mesh","Strain colors"]:
		var toggle:=CheckButton.new(); toggle.text=field; toggle.button_pressed=field not in ["Feature colors","Contact / cage debug","Exact rest mesh","Strain colors"]
		toggle.toggled.connect(func(on: bool):
			if not is_instance_valid(creature): return
			if field=="Idle tissue": creature.solver.idle_enabled=on
			elif field=="Secondary chains": creature.solver.secondary_enabled=on
			elif field=="Contact gait": creature.gait_enabled=on
			elif field=="Feature colors": creature.debug_features=on
			elif field=="Contact / cage debug": creature.debug_contacts=on
			elif field=="Strain colors": creature.debug_strain=on
			else:
				creature.rest_pose_enabled=on
				if on:creature.simulation_enabled=false
			creature._update_uniforms())
		rows.add_child(toggle); runtime_widgets[field]=toggle
	var timeline_label:=Label.new();timeline_label.text="Scrub replay (seconds)";rows.add_child(timeline_label)
	var timeline:=HSlider.new();timeline.min_value=0;timeline.max_value=12;timeline.step=.1;rows.add_child(timeline)
	timeline.drag_ended.connect(func(_changed:bool):
		if is_instance_valid(creature):
			runtime_widgets["Exact rest mesh"].button_pressed=false
			await creature.seek(timeline.value))
	var follow:=CheckButton.new();follow.text="Follow creature";follow.button_pressed=true
	follow.toggled.connect(func(on:bool):camera.follow_enabled=on);rows.add_child(follow)
	_environment_slider(rows,"Travel heading",-180,180,0,func(v:float):
		if is_instance_valid(creature):creature.direction=Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(v)))
	var feature:=SpinBox.new(); feature.min_value=0; feature.max_value=1000; feature.prefix="Feature "; rows.add_child(feature)
	var focus_button:=Button.new(); focus_button.text="Focus feature"
	focus_button.pressed.connect(func():
		if is_instance_valid(creature): camera.focus_feature(creature,clampi(int(feature.value),0,creature.anatomy.features.size()-1)))
	rows.add_child(focus_button)
	var metadata:=Label.new();metadata.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;metadata.custom_minimum_size=Vector2(185,90);rows.add_child(metadata)
	feature.value_changed.connect(func(value:float):
		if not is_instance_valid(creature):return
		var f:Dictionary=creature.anatomy.features[clampi(int(value),0,creature.anatomy.features.size()-1)]
		metadata.text="%s\nTissue: %s · parent %d\n%s\n%s"%[f.feature_type,f.tissue,f.parent,f.get("animation_role",f.locomotion_relevance),f.get("omission_reason","Integrated" if f.get("fused_path",false) else "Surface/curve attached")])
	var views:=OptionButton.new()
	for title in ["Front","Back","Left","Right","Top","Bottom","Three-quarter"]: views.add_item(title)
	views.selected=6; views.item_selected.connect(func(i:int): camera.quick_view(i)); rows.add_child(views)
	var floor_toggle:=CheckButton.new(); floor_toggle.text="Show ground"; floor_toggle.button_pressed=true
	floor_toggle.toggled.connect(func(on:bool): get_parent().get_node("Floor").visible=on); rows.add_child(floor_toggle)
	var key:DirectionalLight3D=get_parent().get_node("Key")
	var env:Environment=get_parent().get_node("Environment").environment
	_environment_slider(rows,"Light intensity",0,4,1.5,func(v:float): key.light_energy=v)
	_environment_slider(rows,"Light azimuth",-180,180,-35,func(v:float): key.rotation_degrees.y=v)
	_environment_slider(rows,"Light elevation",-85,5,-45,func(v:float): key.rotation_degrees.x=v)
	_environment_slider(rows,"Warm / cool light",0,1,.5,func(v:float): key.light_color=Color(1,.65,.38).lerp(Color(.65,.8,1),v))
	_environment_slider(rows,"Ambient light",0,2,.6,func(v:float): env.ambient_light_energy=v)
	_environment_slider(rows,"Sky reflections",0,2,.4,func(v:float): env.sky.sky_material.energy_multiplier=v)
	_environment_slider(rows,"Shadow softness",0,4,.5,func(v:float): key.light_angular_distance=v)
	var ground_color:=ColorPickerButton.new(); ground_color.color=Color(.21,.225,.22); ground_color.tooltip_text="Ground color"
	ground_color.color_changed.connect(func(v:Color): get_parent().get_node("Floor").material_override.set_shader_parameter("base_color",v)); rows.add_child(ground_color)
	var tone:=OptionButton.new()
	for title in ["Linear","Reinhard","Filmic","ACES"]: tone.add_item(title)
	tone.selected=2; tone.item_selected.connect(func(i:int): env.tonemap_mode=i); rows.add_child(tone)

func _environment_slider(rows:Control,title:String,minimum:float,maximum:float,value:float,callback:Callable)->void:
	var label:=Label.new(); label.text=title; rows.add_child(label)
	var slider:=HSlider.new(); slider.min_value=minimum; slider.max_value=maximum; slider.step=(maximum-minimum)/100.0; slider.value=value
	slider.value_changed.connect(callback); rows.add_child(slider)


func _lighting(index: int) -> void:
	lighting_preset=index
	var env: Environment=get_parent().get_node("Environment").environment
	var key: DirectionalLight3D=get_parent().get_node("Key")
	var fill: DirectionalLight3D=get_parent().get_node("Fill")
	if env.sky==null:
		env.sky=Sky.new(); env.sky.sky_material=ProceduralSkyMaterial.new()
		env.sky.sky_material.sky_top_color=Color(.23,.31,.42)
		env.sky.sky_material.sky_horizon_color=Color(.65,.7,.72)
		env.sky.sky_material.energy_multiplier=.4
		env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	key.light_angular_distance=.5
	key.light_energy=[1.5,1.9,.65,2.0,.7,1.2][index]
	fill.light_energy=[.8,.35,.5,.25,.9,.6][index]
	env.ambient_light_energy=[.6,.55,.9,.3,.12,.65][index]
	key.light_color=Color(1,.63,.35) if index==3 else Color(1,.92,.82)
	key.rotation_degrees=Vector3(-12 if index==3 else -45,-35,0)
	fill.light_color=Color(.5,.65,1) if index==4 else Color(.75,.85,1)
	if is_instance_valid(creature):
		for mat in creature.materials: mat.set_shader_parameter("tissue_enabled",index!=5)
