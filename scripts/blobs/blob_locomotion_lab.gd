extends Node3D
const Cache=preload("res://scripts/blobs/blob_mesh_cache.gd")
const Organism=preload("res://scripts/blobs/blob_organism.gd")
var organisms: Array[Node3D]=[]
var elapsed:=.0
var automatic:=true
var readout: Label
class Ground extends Node3D:
	func get_height_at(p: Vector3) -> float:
		if p.x<0: return 0.0
		return .12*p.z+.17*sin(p.z*1.8)+.09*sin(p.x*1.3)

func _ready() -> void:
	var ground:=Ground.new()
	ground.name="ContactSurface"
	add_child(ground)
	_build_ground(ground)
	var camera:=Camera3D.new()
	camera.position=Vector3(12,9,15)
	add_child(camera)
	camera.look_at(Vector3(0,1,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=17
	camera.current=true
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.12,.14,.15)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.7,.75,.8)
	env.environment.ambient_light_energy=.6
	add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-30,0)
	light.light_energy=1.6
	light.shadow_enabled=true
	add_child(light)
	for lane in 2:
		var organism:=Organism.new()
		add_child(organism)
		var options: Dictionary={"profile":"swollen" if lane==0 else "mimic","body_plan":"multilobe" if lane==0 else "lopsided"}
		organism.position=Vector3(-4.5 if lane==0 else 4.5,0,2)
		organism.position.y=ground.get_height_at(organism.position)
		organism.terrain=ground
		organism.ground_height=organism.position.y
		organism.configure(Cache.build(6200+lane,1,"roll",7,null,options))
		organism.travel_enabled=true
		organism.speed=.9
		organism.debug_circulation=true
		organism.simulation_enabled=false
		organisms.append(organism)
		var label:=Label3D.new()
		label.text="FLAT CONTACT" if lane==0 else "SLOPE + UNEVEN CONTACT"
		label.position=Vector3(organism.position.x,0,-5.5)
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size=.008
		label.font_size=40
		add_child(label)
	var ui:=CanvasLayer.new()
	add_child(ui)
	var box:=VBoxContainer.new()
	box.position=Vector2(24,20)
	ui.add_child(box)
	readout=Label.new()
	readout.add_theme_font_size_override("font_size",22)
	box.add_child(readout)
	var help:=Label.new()
	help.text="MATERIAL-COORDINATE CIRCULATION / stationary body frame\nSpace: pause  |  D: tissue/markers  |  R: reverse  |  M: movement profile"
	box.add_child(help)

func _physics_process(delta: float) -> void:
	if automatic: advance(delta)

func advance(delta: float) -> void:
	elapsed+=delta
	var cycle:=fmod(elapsed,10.0)
	var speed:=.9 if cycle<4.0 else (.0 if cycle<5.0 else (-.9 if cycle<9.0 else .0))
	for organism in organisms:
		organism.speed=speed
		organism.simulate(delta)
	readout.text="PREDATOR ISLE / SOFT TREAD TEST · %.2f s · %s" % [elapsed,"FORWARD" if speed>0 else ("REVERSE" if speed<0 else "SETTLING")]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_SPACE: automatic=not automatic
		KEY_D:
			for organism in organisms: organism.debug_circulation=not organism.debug_circulation
		KEY_R:
			for organism in organisms: organism.direction=-organism.direction
		KEY_M:
			for organism in organisms:
				var modes: Array=["roll","drag","undulate","limb","hybrid"]
				organism.set_locomotion(modes[(modes.find(organism.locomotion)+1)%modes.size()])

func _build_ground(provider: Ground) -> void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in 48:
		for x in 48:
			var points: Array[Vector3]=[]
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var p:=Vector3((float(x)+corner.x)/48.0*24.0-12.0,0,(float(z)+corner.y)/48.0*24.0-12.0)
				p.y=provider.get_height_at(p)
				points.append(p)
			for i in [0,1,2,1,3,2]:
				surface.set_color(Color(.18,.2,.19) if x<24 else Color(.23,.22,.19))
				surface.add_vertex(points[i])
	surface.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=surface.commit()
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=.9
	mesh.material_override=material
	add_child(mesh)
	mesh.create_trimesh_collision()
