extends SceneTree
const Cache=preload("res://scripts/blobs/blob_mesh_cache.gd")
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const INPUT="res://.godot/blob_validation_v2_release"
const OUTPUT="res://data/blobs_v4"
var active_organisms: Array[Node3D]=[]
var performance_rows: Array=[]
func _initialize() -> void: call_deferred("_run")
func _run()->void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var models:Array[Dictionary]=[]
	for i in 24:
		var file:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%i,FileAccess.READ);models.append(file.get_var(false));file.close()
	await _sheet(models,6,Vector2i(480,450),"clay_24.png",true)
	var final:Array[Dictionary]=[]
	for i in 12:final.append(models[i])
	await _sheet(final,4,Vector2i(640,600),"biology_12.png",false)
	var detail:Array[Dictionary]=[]
	for i in [0,3,4,8,10,2]:
		var path:String="res://.godot/blob_validation_v4_release/detailed_%02d_%s.bin"%[i,Cache.key(5100+i,1,"roll" if i==0 else "auto",7,{"profile":models[i].dna.profile,"body_plan":models[i].dna.body_plan}).left(10)]
		var data:Dictionary
		if FileAccess.file_exists(path):
			var file:=FileAccess.open(path,FileAccess.READ);data=file.get_var(false);file.close()
		else:
			data=Pipeline.new().build(5100+i,1,"roll" if i==0 else "auto",7,null,{"profile":models[i].dna.profile,"body_plan":models[i].dna.body_plan})
			if data.has("error"):push_error(str(data));quit(1);return
			var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(data);file.close()
		detail.append(data);print("V4_DETAIL ",i)
	await _sheet(detail,3,Vector2i(800,760),"detail_6.png",false)
	var comparison:Array[Dictionary]=[]
	for index in [0,3,8,10]:
		var path:String="res://.godot/blob_validation_v4_release/base_%02d_%s.bin"%[index,Cache.key(5100+index,1,"roll" if index==0 else "auto",4,{"profile":models[index].dna.profile,"body_plan":models[index].dna.body_plan}).left(10)]
		var base:Dictionary
		if FileAccess.file_exists(path):
			var file:=FileAccess.open(path,FileAccess.READ);base=file.get_var(false);file.close()
		else:
			base=Pipeline.new().build(5100+index,1,"roll" if index==0 else "auto",4,null,{"profile":models[index].dna.profile,"body_plan":models[index].dna.body_plan})
			var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(base);file.close()
		var after:Dictionary=detail[[0,3,4,8,10,2].find(index)]
		base["comparison_label"]="STAGE 4 / base";after["comparison_label"]="STAGE 7 / integrated detail"
		comparison.append(base);comparison.append(after)
	await _sheet(comparison,2,Vector2i(800,700),"clay_before_after.png",true)
	var file:=FileAccess.open(OUTPUT.path_join("render_performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(performance_rows,"\t"));file.close()
	print("V4_RENDERS_COMPLETE");quit()

func _sheet(models: Array[Dictionary], columns: int, tile_size: Vector2i, filename: String, clay: bool) -> void:
	active_organisms.clear()
	var rows:=ceili(float(models.size())/float(columns))
	var sheet:=SubViewport.new()
	sheet.size=Vector2i(columns*tile_size.x,rows*tile_size.y)
	sheet.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	for i in models.size():
		var container:=SubViewportContainer.new()
		container.position=Vector2((i%columns)*tile_size.x,floori(float(i)/float(columns))*tile_size.y)
		container.size=tile_size
		sheet.add_child(container)
		var viewport:=SubViewport.new()
		viewport.size=tile_size
		viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		_tile(viewport,models[i],clay)
		var label:=Label.new()
		label.position=container.position+Vector2(16,tile_size.y-54)
		label.text="%d / %s\n%s · %s" % [models[i].dna.seed,str(models[i].dna.profile).capitalize(),str(models[i].dna.body_plan).capitalize(),str(models[i].get("effective_mode",models[i].dna.locomotion)).capitalize()]
		label.add_theme_font_size_override("font_size",18)
		if models[i].has("comparison_label"):label.text+= "\n"+models[i].comparison_label
		sheet.add_child(label)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var error:=sheet.get_texture().get_image().save_png(OUTPUT.path_join(filename))
	print("BLOB_SHEET_SAVED ",filename," error=",error)
	# Warm shaders first, then measure a simultaneous moving batch. It renders
	# the real meshes, LODs and membrane surfaces, not a dummy headless renderer.
	for organism in active_organisms:
		organism.speed=.55
		organism.set_locomotion("roll")
	var started:=Time.get_ticks_usec()
	for frame in 30:
		for organism in active_organisms: organism.simulate(1.0/60.0)
		await process_frame
	var frame_ms:=float(Time.get_ticks_usec()-started)/30000.0
	performance_rows.append({"sheet":filename,"simultaneous_blobs":models.size(),"frame_ms_including_viewports_and_vsync":frame_ms,"static_memory_bytes":OS.get_static_memory_usage(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	sheet.queue_free()
	await process_frame
	active_organisms.clear()

func _tile(viewport: SubViewport, data: Dictionary, clay: bool) -> void:
	var world:=Node3D.new()
	viewport.add_child(world)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.17,.18,.18)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.72,.76,.8)
	env.environment.ambient_light_energy=.55
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment.sky=Sky.new(); env.environment.sky.sky_material=ProceduralSkyMaterial.new()
	env.environment.sky.sky_material.energy_multiplier=.4
	env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	world.add_child(env)
	var key:=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-42,-35,0)
	key.light_color=Color(1.0,.91,.8)
	key.light_energy=1.35
	key.shadow_enabled=true
	world.add_child(key)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-25,130,0)
	fill.light_color=Color(.65,.75,.95)
	fill.light_energy=.65
	world.add_child(fill)
	var ground:=MeshInstance3D.new()
	ground.mesh=PlaneMesh.new()
	ground.mesh.size=Vector2(80,80)
	var floor_material:=ShaderMaterial.new()
	floor_material.shader=load("res://shaders/blob_lab_floor.gdshader")
	ground.material_override=floor_material
	world.add_child(ground)
	var organism:=Organism.new()
	world.add_child(organism)
	organism.configure(data)
	data["effective_mode"]=organism.locomotion
	organism.simulation_enabled=false
	for mat in organism.materials: mat.set_shader_parameter("tissue_enabled",not clay)
	var diagnostic: String=data.get("render_diagnostic","")
	if diagnostic=="no_lod": viewport.mesh_lod_threshold=0.0
	if diagnostic=="no_microdetail":
		for mat in organism.materials: mat.set_shader_parameter("microdetail",0.0)
	if diagnostic=="standard":
		var material:=StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.roughness=.7
		for instance in organism.render_instances: instance.material_override=material
	active_organisms.append(organism)
	var bounds:=AABB(Vector3.ZERO,Vector3.ONE*.001)
	for p: Vector3 in data.body.vertices: bounds=bounds.expand(organism.solver.map_point(p)+Vector3.UP*organism.solver.height)
	for item: Dictionary in data.appendages:
		for p: Vector3 in item.mesh.vertices: bounds=bounds.expand(organism.solver.map_point(p)+Vector3.UP*organism.solver.height)
	var camera:=Camera3D.new()
	world.add_child(camera)
	var center:=bounds.get_center()
	var view_direction:=Vector3(.7,.34,1.0)
	for feature: Dictionary in data.features:
		if feature.feature_type=="embedded_face":
			view_direction=Vector3(feature.direction.x,.28,feature.direction.z)
			break
	camera.position=center+view_direction.normalized()*20.0
	camera.look_at(center)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var width:=.0
	var height:=.0
	for i in 8:
		var corner:=bounds.position+Vector3(bounds.size.x if i&1 else 0,bounds.size.y if i&2 else 0,bounds.size.z if i&4 else 0)
		var relative:=corner-center
		width=maxf(width,absf(relative.dot(camera.basis.x))*2.0)
		height=maxf(height,absf(relative.dot(camera.basis.y))*2.0)
	camera.size=maxf(height,width*float(viewport.size.y)/float(viewport.size.x))*1.17
	camera.position+=camera.basis.y*camera.size*.03
	camera.current=true
