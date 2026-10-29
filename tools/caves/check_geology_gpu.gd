extends "res://tools/biome_extensions/check_all.gd"
const Config=preload("res://scripts/caves/cave_settings.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
const WaterRenderer=preload("res://scripts/caves/water_renderer.gd")
const Palette=preload("res://scripts/caves/material_palette.gd")
var captures:Dictionary={}
func image_prefix()->String:return "cave_geology"
func report_name()->String:return "check_cave_geology_gpu"
func target_pool(region:Dictionary)->Dictionary:return region.get("pools",[])[0] if not region.get("pools",[]).is_empty() else {}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var result:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/"+image_prefix()+"_"+label+".png";check(result.save_png(path)==OK,"Native cave geological image "+label);captures[path]=FileAccess.get_sha256(path);return result
func run()->void:
	var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scenes/main.tscn","res://tools/caves/check_geology_gpu.gd",get_script().resource_path,"res://data/cave_material_sources.json",Palette.COLORS,Palette.NORMALS]:guards[path]=FileAccess.get_sha256(path)
	var colors:Texture2DArray=load(Palette.COLORS);var normals:Texture2DArray=load(Palette.NORMALS);check(colors!=null and normals!=null and colors.get_layers()==8 and normals.get_layers()==8,"Actual eight distinct PBR image pairs load into shared cave arrays")
	check(colors.get_width()==2048 and colors.get_height()==2048 and normals.get_width()==2048 and normals.get_height()==2048 and colors.has_mipmaps() and normals.has_mipmaps(),"Actual native2K texture arrays retain full mip chains")
	var sources:Array=[];var bytes:int=0
	for index in range(Palette.RECORDS.size()):
		var source:Array=Palette.RECORDS[index];var records=JSON.parse_string(FileAccess.get_file_as_string(source[1]));var record:Dictionary={};guards[source[1]]=FileAccess.get_sha256(source[1])
		for candidate:Dictionary in records:
			if candidate.id==source[0]:record=candidate;break
		check(not record.is_empty() and record.license=="CC0-1.0","Actual existing source and recorded license "+str(source[0]))
		if record.is_empty():continue
		record["color_resource"]="res://materials/"+source[3]+".res";record["normal_resource"]="res://materials/cave_normal_"+source[0]+".res"
		var original_color:Image=load(record.color_resource);var original_normal:Image=load(record.normal_resource);var packed_color:Image=colors.get_layer_data(index);var packed_normal:Image=normals.get_layer_data(index)
		check(FileAccess.get_file_as_string(Palette.COLORS).contains(record.color_resource) and FileAccess.get_file_as_string(Palette.NORMALS).contains(record.normal_resource),"Array descriptors reference the exact unchanged photographed source pair")
		check(original_color.get_size()==Vector2i(2048,2048) and original_normal.get_size()==Vector2i(2048,2048) and original_color.has_mipmaps() and original_normal.has_mipmaps(),"Actual native2K photographed source pair retains complete mipmaps")
		var readback_error:float=0
		for pair:Array in [[original_color,packed_color],[original_normal,packed_normal]]:
			var expected:Image=pair[0].duplicate();var actual:Image=pair[1].duplicate()
			if expected.is_compressed():check(expected.decompress()==OK,"Decompress original source for pixel-domain comparison")
			if actual.is_compressed():check(actual.decompress()==OK,"Decompress GPU readback for pixel-domain comparison")
			check(actual.get_size()==expected.get_size(),"GPU readback preserves original source dimensions")
			for y in range(16,2048,64):
				for x in range(16,2048,64):
					var a:Color=actual.get_pixel(x,y);var bv:Color=expected.get_pixel(x,y);readback_error=maxf(readback_error,maxf(absf(a.r-bv.r),maxf(absf(a.g-bv.g),maxf(absf(a.b-bv.b),absf(a.a-bv.a)))))
		check(readback_error<.02,"Actual GPU color/roughness and OpenGL normal pixels match decompressed originals within2percent")
		for image:Image in [original_color,original_normal]:bytes+=image.get_data().size()
		guards[record.color_resource]=FileAccess.get_sha256(record.color_resource);guards[record.normal_resource]=FileAccess.get_sha256(record.normal_resource)
		for map:Dictionary in record.maps:check(FileAccess.get_sha256(map.path)==map.sha256,"Original PBR source-map identity "+str(source[0]))
		sources.append({"id":source[0],"source":record.source,"license":record.license,"role":source[2],"manifest":source[1],"gpu_readback_max_rgba_error":readback_error,"readback_pixels_per_map":1024})
	var b=make_builder(3,73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual geological worker configured")
	var result:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(9,-3));var own:Dictionary={}
		for region:Dictionary in bundle.regions:
			if region.id==Vector2i(9,-3):own=region;break
		var pocket:Dictionary=own.get("pockets",[])[0] if not own.get("pockets",[]).is_empty() else {};var pool:Dictionary=target_pool(own);var keys:Dictionary={}
		for target:Dictionary in [pocket,pool]:
			if target.is_empty():continue
			var point:Vector3=target.point if target.has("point") else target.center;var low:Vector3i=work.field.cell(point-Vector3(40,6,40));var high:Vector3i=work.field.cell(point+Vector3(40,36,40))
			for z in range(low.z,high.z+1):
				for y in range(low.y,high.y+1):
					for x in range(low.x,high.x+1):keys[Vector3i(x,y,z)]=true
		var cells:Array=[]
		for key:Vector3i in keys:cells.append(work.build_cell(key))
		result.append({"bundle":bundle,"region":own,"pocket":pocket,"pool":pool,"cells":cells})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(result.size()==1,"Actual native geometry worker returns")
	if result.is_empty():quit(1);return
	var data:Dictionary=result[0];check(not data.pocket.is_empty() and not data.pool.is_empty(),"Original actual region retains positive joined chamber and pool without new site search")
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var stream=Streamer.new();stream._bundle=data.bundle;var materials:Array=[];var waters:Array=[];var nodes:Array=[]
	for cell:Dictionary in data.cells:
		if cell.arrays.is_empty():continue
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);var material:ShaderMaterial=stream.material_for(cell.key);mesh.surface_set_material(0,material)
		if not materials.has(material):materials.append(material)
		var node:=MeshInstance3D.new();node.position=Vector3(cell.key)*64;node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;root.add_child(node);nodes.append(node);var water_node:MeshInstance3D=WaterRenderer.attach(node,cell.water)
		if water_node!=null:waters.append(water_node)
	stream.free();check(waters.size()>0 and materials.size()>0,"Actual cave-only water and rock materials installed on extracted native meshes")
	var debug_light:=OmniLight3D.new();debug_light.name="TestOnlyTemporaryDebugLight";debug_light.omni_range=36;debug_light.light_energy=3;debug_light.visible=false;root.add_child(debug_light)
	if not data.pool.is_empty():
		var pool:Dictionary=data.pool;var parent:Dictionary={}
		for room:Dictionary in data.region.nodes+data.region.get("pockets",[]):
			if pool.id==str(room.id)+":seepage":parent=room;break
		var inward:Vector3=(parent.point-pool.center).normalized() if not parent.is_empty() else Vector3.BACK;camera.position=pool.center+inward*7+Vector3(0,3,0);camera.look_at(Vector3(pool.center.x,pool.water_y,pool.center.z));await picture("pool_natural")
		debug_light.position=camera.position+Vector3(0,1,0);debug_light.visible=true;var positive:Image=await picture("pool_debug_light_water_on")
		for node:MeshInstance3D in waters:node.visible=false
		var negative:Image=await picture("pool_debug_light_water_off");var difference:float=0;var changed:int=0
		for y in range(positive.get_height()/4,positive.get_height()*3/4,2):
			for x in range(positive.get_width()/4,positive.get_width()*3/4,2):
				var a:Color=positive.get_pixel(x,y);var bv:Color=negative.get_pixel(x,y);var error:float=maxf(absf(a.r-bv.r),maxf(absf(a.g-bv.g),absf(a.b-bv.b)));difference=maxf(difference,error)
				if error>2.0/255:changed+=1
		check(changed>10 and difference>.02,"Independent water-off negative exposes native bed;actual water is visibly rendered,not metadata only")
		for node:MeshInstance3D in waters:node.visible=true
		await picture("pool_debug_light_water_return")
	if not data.pocket.is_empty():
		var pocket:Dictionary=data.pocket;camera.position=pocket.point+Vector3(0,4,0);camera.look_at(pocket.point+Vector3(12,4,-14));debug_light.visible=false;await picture("chamber_natural");debug_light.position=camera.position+Vector3(0,2,0);debug_light.visible=true;await picture("chamber_debug_light")
		for style in range(6):
			for material:ShaderMaterial in materials:material.set_shader_parameter("geological_style",style)
			await picture("palette_style_"+str(style)+"_debug_light")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable GPU geology source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"sources":sources,"shared_palette_compressed_bytes":bytes,"native_cells":nodes.size(),"native_water_nodes":waters.size(),"target_pool_id":data.pool.get("id",""),"target_has_feeder_channel":data.pool.has("stream_points"),"scope":"Actual original Spore seed73921/cell(9,-3) geological room/pool field extracted on real worker,rendered with actual main-scene sky/sun/fog and50kmfar. Natural plus separately labelled TEST-ONLY debug light;water-off negative isolates visible water/real bed. Six palette overrides are controlled shader-role views,not six independently sampled geological regions. Eight distinct photographed nominal2Ksource PBR pairs,existing colors unchanged and cave-only2Knormal packing with recorded rectangular-source interpolation. Full array/source mips and source-map hashes/licenses checked;GPU BASE-LEVEL decompressed readbacks sampled1024pixels/map within existing2percent policy,NOT compressed-byte/mipmap-readback identity. Earlier invalid compressed-vs-decompressed byte comparison remains a preserved failed diagnostic. No main-scene lighting changes,gameplay torch,global water mutation,all-world art or streaming-performance certificate."},"  "));print("CAVE_GEOLOGY_GPU ",checks," cells=",nodes.size()," waters=",waters.size()," channel=",data.pool.has("stream_points")," failures=",failures);for node:Node in nodes:node.queue_free()
	scene.queue_free();debug_light.queue_free();quit(0 if failures.is_empty() else 1)
