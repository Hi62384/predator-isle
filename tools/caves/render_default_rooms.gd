extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const Water=preload("res://scripts/caves/water_renderer.gd")
const CaveProjection=preload("res://tools/caves/common_projection_candidate.gd")
var captures:Dictionary={}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_default_rooms_"+label+".png";check(image.save_png(path)==OK,"Actual Default room inspection "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/common_projection_candidate.gd","res://scenes/main.tscn","res://config/caves/biomes/default_cave_definition.tres","res://config/caves/cave_biome_regions.tres"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original Default room worker configured");var output:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(9,-3));var selected:Dictionary={}
		for region:Dictionary in bundle.get("regions",[]):
			if not region.get("valid",false) or region.get("cave_family",-1) in [6,7] or selected.has(region.geology):continue
			selected[region.geology]=region
		var studies:Array=[];var styles:Array=selected.keys();styles.sort()
		for style:int in styles:
			var region:Dictionary=selected[style];var room:Dictionary=region.nodes[1];var center:Vector3=room.point
			# Include all actual joined lobes around this parent,not a private
			# isolated room that omits protected neighbouring routes/formations.
			var low:Vector3=center-Vector3(room.chamber_radius+8,4,room.chamber_radius+8);var high:Vector3=center+Vector3(room.chamber_radius+8,room.chamber_height+8,room.chamber_radius+8)
			for pocket:Dictionary in region.get("pockets",[]):
				if pocket.parent!=room.id:continue
				low=low.min(pocket.point-Vector3(pocket.chamber_radius+4,4,pocket.chamber_radius+4));high=high.max(pocket.point+Vector3(pocket.chamber_radius+4,pocket.chamber_height+4,pocket.chamber_radius+4))
			var first:Vector3i=work.field.cell(low);var last:Vector3i=work.field.cell(high);var cells:Array=[]
			for z in range(first.z,last.z+1):
				for y in range(first.y,last.y+1):
					for x in range(first.x,last.x+1):cells.append(work.build_cell(Vector3i(x,y,z)))
			studies.append({"tag":"style"+str(style),"style":style,"region":region.id,"center":center,"radius":room.chamber_radius,"cells":cells})
		for region:Dictionary in bundle.get("regions",[]):
			if region.id!=Vector2i(9,-3):continue
			var targets:Array=[]
			if not region.get("pockets",[]).is_empty():targets.append({"tag":"original_first_lobe","point":region.pockets[0].point,"radius":region.pockets[0].chamber_radius})
			if not region.get("pools",[]).is_empty():targets.append({"tag":"original_first_pool","point":region.pools[0].center,"radius":region.pools[0].radius})
			for target:Dictionary in targets:
				var first:Vector3i=work.field.cell(target.point-Vector3(40,6,40));var last:Vector3i=work.field.cell(target.point+Vector3(40,36,40));var cells:Array=[]
				for z in range(first.z,last.z+1):
					for y in range(first.y,last.y+1):
						for x in range(first.x,last.x+1):cells.append(work.build_cell(Vector3i(x,y,z)))
				studies.append({"tag":target.tag,"style":region.geology,"region":region.id,"center":target.point,"radius":target.radius,"cells":cells})
		output.append({"bundle":bundle,"studies":studies})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1 and not output[0].studies.is_empty(),"Actual fixed3x3Default world retains admitted geological rooms without rerolling absent styles")
	if output.is_empty():quit(1);return
	var data:Dictionary=output[0];var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var stream=Streamer.new();stream.configuration=config;stream._bundle=data.bundle;var light:=OmniLight3D.new();light.name="TestOnlyDefaultRoomInspectionLight";light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;root.add_child(light);var records:Array=[]
	for study:Dictionary in data.studies:
		var cells:Dictionary={};var nodes:Array=[];var triangles:int=0;var minerals:int=0;var water_vertices:int=0;var mineral_focus:=Vector3.ZERO
		for cell:Dictionary in study.cells:
			var node:=MeshInstance3D.new();node.position=Vector3(cell.key)*64;var material:ShaderMaterial=stream.material_for(cell.key)
			if not cell.arrays.is_empty():
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);mesh.surface_set_material(0,material);node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;triangles+=cell.arrays[Mesh.ARRAY_VERTEX].size()/3
				for index in range(cell.arrays[Mesh.ARRAY_COLOR].size()):
					if cell.arrays[Mesh.ARRAY_COLOR][index].r>.5:minerals+=1;mineral_focus+=cell.arrays[Mesh.ARRAY_VERTEX][index]+node.position
				var body:=StaticBody3D.new();var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child);node.add_child(body)
			Frontiers.attach(node,cell.get("frontiers",{}),material,true);Water.attach(node,cell.get("water",{}));root.add_child(node);nodes.append(node);cells[cell.key]=node
			if not cell.get("water",{}).get("arrays",[]).is_empty():water_vertices+=cell.water.arrays[Mesh.ARRAY_VERTEX].size()
		Frontiers.synchronize(cells);var center:Vector3=study.center;var radius:float=study.radius;var poses:Array=[center+Vector3(-radius*.35,1.8,radius*.35),center+Vector3(radius*.25,3,-radius*.2)]
		for pose in range(poses.size()):
			var focus:Vector3=mineral_focus/maxi(1,minerals)+Vector3(0,.5,0) if minerals>0 and study.tag=="original_first_lobe" else center+Vector3(radius*.35,5,-radius*.4);camera.position=poses[pose];camera.look_at(focus);check(work.field.sample(camera.position)<0,"Default inspector camera lies in actual shared compiled air");light.position=camera.position+Vector3(0,.5,0);light.visible=false;await picture("%s_pose%d_natural"%[study.tag,pose]);light.visible=true;var lit:Image=await picture("%s_pose%d_test_only_light"%[study.tag,pose]);var repeated:Image=await picture("%s_pose%d_light_repeat"%[study.tag,pose]);check(lit.get_data()==repeated.get_data() or water_vertices>0,"Static full image repeats exactly unless actual animated water is present")
			# Distinguish geometric pinholes from highlights without replacing
			# the real scene's sky/fog/light or calling dark pixels an occluder.
			var mask:=ShaderMaterial.new();var mask_shader:=Shader.new();mask_shader.code="shader_type spatial;render_mode unshaded,fog_disabled;void fragment(){ALBEDO=vec3(.65,.02,.02);}";mask.shader=mask_shader
			for node:MeshInstance3D in nodes:
				node.material_override=mask
				if node.has_node("CaveFrontiers"):
					for face:MeshInstance3D in node.get_node("CaveFrontiers").get_children():face.material_override=mask
				if node.has_node("CaveSeepageWater"):node.get_node("CaveSeepageWater").visible=false
			var coverage:Image=await picture("%s_pose%d_opaque_geometry_mask"%[study.tag,pose]);var holes:int=0
			for y in range(coverage.get_height()):
				for x in range(coverage.get_width()):
					var pixel:Color=coverage.get_pixel(x,y)
					if pixel.r<=pixel.g*2 or pixel.r<=pixel.b*2:holes+=1
			var projected_mask:ShaderMaterial=CaveProjection.mask()
			for node:MeshInstance3D in nodes:
				node.material_override=projected_mask
				if node.has_node("CaveFrontiers"):
					for face:MeshInstance3D in node.get_node("CaveFrontiers").get_children():face.material_override=projected_mask
			var corrected:Image=await picture("%s_pose%d_common_projection_geometry_mask"%[study.tag,pose]);var corrected_holes:int=0
			for y in range(corrected.get_height()):
				for x in range(corrected.get_width()):
					var pixel:Color=corrected.get_pixel(x,y)
					if pixel.r<=pixel.g*2 or pixel.r<=pixel.b*2:corrected_holes+=1
			check(corrected_holes==0,"Private common camera-grid-relative projection covers every actual underground pixel without geometry/lighting/background/viewport changes")
			var production_mask:ShaderMaterial=CaveProjection.production_mask(true)
			for node:MeshInstance3D in nodes:
				node.material_override=production_mask
				if node.has_node("CaveFrontiers"):
					for face:MeshInstance3D in node.get_node("CaveFrontiers").get_children():face.material_override=production_mask
			var production:Image=await picture("%s_pose%d_production_projection_geometry_mask"%[study.tag,pose]);check(production.get_data()==corrected.get_data(),"Actual production projection source matches accepted private all-pixel coverage exactly")
			production_mask.set_shader_parameter("cave_common_projection",false);var disabled:Image=await picture("%s_pose%d_original_projection_restored"%[study.tag,pose]);check(disabled.get_data()==coverage.get_data(),"Independent off uniform restores complete old projection image exactly,including original defects")
			for node:MeshInstance3D in nodes:
				node.material_override=null
				if node.has_node("CaveFrontiers"):
					for face:MeshInstance3D in node.get_node("CaveFrontiers").get_children():face.material_override=null
				if node.has_node("CaveSeepageWater"):node.get_node("CaveSeepageWater").visible=true
			records.append({"tag":study.tag,"style":study.style,"region":str(study.region),"pose":pose,"position":str(camera.position),"triangles":triangles,"mineral_color_vertices":minerals,"water_vertices":water_vertices,"geometry_mask_uncovered_pixels":holes,"private_common_projection_uncovered_pixels":corrected_holes,"cells":cells.size()})
		for node:Node in nodes:node.queue_free()
		await process_frame;await physics_frame
	stream.free();scene.queue_free();light.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual Default room source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_default_rooms.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"scope":"Original seed73921/Spore(9,-3)full3x3canonical field;first admitted parent room per geological style PRESENT in that original world,no reroll of absent styles. Actual full joined/formation/water/temporary-frontier worker payloads;native original main sun/sky/fog,camera50km,terrain controller removed only for bounded preloaded inspection. Two room-air poses,natural and explicitly labelled120m4energy test-only light/repeat. Existing photographed PBR banks,no invented texture detail. Physical returns/live24.7km/depth controls separate;not whole-world reference-art or FPS acceptance."},"  "));print("DEFAULT_ROOM_INSPECTION ",checks," records=",records," failures=",failures);await process_frame;quit(0 if failures.is_empty() else 1)
