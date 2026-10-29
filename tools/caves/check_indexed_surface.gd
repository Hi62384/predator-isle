extends "res://tools/biome_extensions/check_all.gd"
const Context=preload("res://scripts/caves/surface_context.gd")
const Indexed=preload("res://tools/caves/indexed_surface_context_candidate.gd")
const SurfaceRenderer=preload("res://scripts/caves/surface_renderer.gd")
const Palette=preload("res://scripts/caves/material_palette.gd")
var captures:Dictionary={}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_indexed_surface_"+label+".png";check(image.save_png(path)==OK,"Saved actual indexed transport image "+label);captures[path]=FileAccess.get_sha256(path);return image
func diagnostic_shader()->Shader:
	var shader:=Shader.new();var code:String="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform sampler2D cave_surface_payload:filter_nearest,repeat_disable;varying vec3 verification;void vertex(){int base=VERTEX_ID*17;vec3 sum=vec3(0);"
	for i in range(68):code+="sum[%d]+=texelFetch(cave_surface_payload,ivec2((base+%d)%%1024,(base+%d)/1024),0)[%d]*%.9f;"%[i%3,i/4,i/4,i%4,1.0/(i+1)]
	shader.code=code+"verification=fract(sum*.173); }void fragment(){ALBEDO=verification;}";return shader
func run()->void:
	check(DisplayServer.get_name()!="headless","Actual native GPU required");var guards:Dictionary={}
	for name:String in ["surface_context","surface_payload","surface_shader","surface_renderer","material_palette"]:
		var path:String="res://scripts/caves/"+name+".gd";guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/caves/check_indexed_surface.gd","res://tools/caves/indexed_surface_context_candidate.gd","res://scripts/terrain_shader_variants.gd","res://shaders/terrain_biomes.gdshader","res://shaders/cave_entry_rock.gdshaderinc","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var parents:Array=[];var sources:Dictionary={}
	for cell:Vector2i in [Vector2i(58,-18),Vector2i(59,-18)]:
		var id:String=str(cell);var origin:=Vector3(cell.x*256,0,cell.y*256);var parent:Array=b.build(cell,128);parents.append({"id":id,"origin":origin,"span":256.0,"resolution":128,"arrays":parent,"extension_normalization":true});var material:ShaderMaterial=load("res://materials/terrain.tres").duplicate();material.shader=preload("res://scripts/terrain_shader_variants.gd").select(material.shader,b.settings,true);material.set_shader_parameter("extension_payload_enabled",true);sources[id]={"origin":origin,"material":material}
	var original=Context.new();var candidate=Indexed.new();check(original.configure(parents,b._get_height) and candidate.configure(parents,b._get_height),"Two actual fine original parents admitted");var source:Array=[];source.resize(Mesh.ARRAY_MAX);source[Mesh.ARRAY_VERTEX]=PackedVector3Array();source[Mesh.ARRAY_NORMAL]=PackedVector3Array();source[Mesh.ARRAY_COLOR]=PackedColorArray();var chunk_origin:=Vector3(15040,64,-4480)
	# Shared grid crosses two original parent-material owners and the physical
	# 12m entry/interior split. Deliberate normal/color seams must stay split.
	for z in range(24):
		for x in range(32):
			for offset:Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var q:=Vector2(15072+x*2+offset.x*2,-4456+z*2+offset.y*2);var depth:float=(q.y+4456)*.4;source[Mesh.ARRAY_VERTEX].append(Vector3(q.x,original.height_at(q.x,q.y)-depth,q.y)-chunk_origin);source[Mesh.ARRAY_NORMAL].append(Vector3(.02,1,0).normalized() if x==10 else Vector3.UP);source[Mesh.ARRAY_COLOR].append(Color(.37,.35,.3,.5) if x==20 else Color(.38,.35,.3,1))
	var before:int=Time.get_ticks_usec();var reference:Dictionary=original.surfaces(source,chunk_origin);var reference_usec:int=Time.get_ticks_usec()-before;before=Time.get_ticks_usec();var indexed:Dictionary=original.surfaces_indexed(source,chunk_origin,true);var indexed_usec:int=Time.get_ticks_usec()-before;check(var_to_bytes(indexed)==var_to_bytes(candidate.surfaces(source,chunk_origin)),"Promoted production complete payload matches accepted private prototype exactly");var compact:Dictionary=original.surfaces_indexed(source,chunk_origin)
	check(reference.valid and indexed.valid and reference.groups.keys()==indexed.groups.keys() and indexed.groups.size()==3,"Both parent owners plus interior group retained");check(reference.collision_faces.to_byte_array()==indexed.collision_faces.to_byte_array(),"Every native collision face remains byte-identical,including order/winding");var old_vertices:int=0;var unique_vertices:int=0;var old_atlas_bytes:int=0;var new_atlas_bytes:int=0
	for id:String in reference.groups:
		var a:Dictionary=reference.groups[id];var c:Dictionary=indexed.groups[id];var indices:PackedInt32Array=c.arrays[Mesh.ARRAY_INDEX];old_vertices+=a.vertices.size();unique_vertices+=c.vertices.size();check(indices.size()==a.vertices.size(),"Complete ordered triangle indices "+id)
		var expanded_positions:=PackedVector3Array();var expanded_normals:=PackedVector3Array();var expanded_colors:=PackedColorArray();var expanded_values:=PackedFloat32Array();var atlas_values:PackedFloat32Array=c.atlas.bytes.to_float32_array() if id!="__interior__" else PackedFloat32Array()
		for index:int in indices:
			expanded_positions.append(c.vertices[index]);expanded_normals.append(c.normals[index]);expanded_colors.append(c.colors[index])
			if id!="__interior__":
				for k in range(68):expanded_values.append(atlas_values[index*68+k])
		check(expanded_positions.to_byte_array()==a.vertices.to_byte_array(),"Complete expanded vertex bytes exact "+id);check(expanded_normals.to_byte_array()==a.normals.to_byte_array(),"Complete expanded normal bytes exact "+id);check(expanded_colors.to_byte_array()==a.colors.to_byte_array(),"Complete expanded color bytes exact "+id)
		if id!="__interior__":check(expanded_values.to_byte_array()==a.payload.to_byte_array(),"Every expanded68-float material/depth atlas record exact "+id);old_atlas_bytes+=a.atlas.bytes.size();new_atlas_bytes+=c.atlas.bytes.size()
		check(var_to_bytes(compact.groups[id].arrays)==var_to_bytes(c.arrays) and not compact.groups[id].has("payload") and not compact.groups[id].has("vertices"),"Worker payload drops only redundant material/array staging fields "+id)
		if id!="__interior__":
			var padded:PackedFloat32Array=a.payload.duplicate();padded.resize(a.atlas.width*a.atlas.height*4);check(padded.to_byte_array()==a.atlas.bytes,"Direct byte-padding optimization exact against original padded float implementation "+id)
	check(unique_vertices<old_vertices*.25 and new_atlas_bytes<old_atlas_bytes*.3,"Positive sharing without approximate position/normal/color merging");print("INDEXED_SURFACE_CPU corners=",old_vertices," unique=",unique_vertices," atlas=",old_atlas_bytes,"→",new_atlas_bytes," usec=",reference_usec,"→",indexed_usec)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var interior:=ShaderMaterial.new();interior.shader=load("res://shaders/default_cave_rock.gdshader");Palette.bind(interior,6);var nodes:Array=[]
	for data:Dictionary in [reference,indexed]:
		data["key"]=Vector3i(235,1,-70);var built:Dictionary=SurfaceRenderer.node(data,sources,interior,6,true,true);check(built.valid and built.node!=null,"Actual multi-surface renderer accepts complete data");root.add_child(built.node);nodes.append(built.node)
	# Data key must match the chunk-local input origin used above.
	check(nodes[0].position==chunk_origin and nodes[1].position==chunk_origin,"Original world/parent coordinate frames unchanged");var middle:=Vector3(15104,original.height_at(15104,-4432)-9.6,-4432);var poses:Array=[middle+Vector3(0,60,35),middle+Vector3(-30,40,40),middle+Vector3(30,30,-40)];var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=2;root.add_child(light);var diagnostic:Shader=diagnostic_shader();var image_count:int=0
	for role:int in [0,1]:
		for node:MeshInstance3D in nodes:
			if role==0:continue
			for surface in range(node.mesh.get_surface_count()):
				var old:ShaderMaterial=node.mesh.surface_get_material(surface);var material:=ShaderMaterial.new();material.shader=diagnostic;var texture=old.get_shader_parameter("cave_surface_payload")
				if texture==null:
					var empty:=Image.create(1024,ceili(node.mesh.surface_get_array_len(surface)*17.0/1024),false,Image.FORMAT_RGBAF);empty.fill(Color(.1,.2,.3,.4));texture=ImageTexture.create_from_image(empty)
				material.set_shader_parameter("cave_surface_payload",texture);node.mesh.surface_set_material(surface,material)
		for pose in range(poses.size()):
			camera.position=poses[pose];camera.look_at(middle);light.position=camera.position;var first:Image
			for phase in range(3):
				nodes[0].visible=phase!=1;nodes[1].visible=phase==1;var result:Image=await picture("role%d_pose%d_%s"%[role,pose,["unindexed","indexed","unindexed_return"][phase]]);image_count+=1
				if phase==0:first=result
				else:check(first.get_data()==result.get_data(),"Complete same-view GPU pixels identical,role%d/pose%d/phase%d"%[role,pose,phase])
	var native_mesh:Array=[]
	for surface in range(nodes[1].mesh.get_surface_count()):native_mesh.append(nodes[1].mesh.surface_get_arrays(surface))
	var native_faces:PackedVector3Array=nodes[1].get_node("CaveCollision").get_child(0).shape.get_faces();var mesh_before:PackedByteArray=var_to_bytes(native_mesh);SurfaceRenderer.release_uploaded_data(indexed);check(indexed.keys()==["valid","key"],"Uploaded cell retains only atomic adoption identity,not duplicate geometry/atlas/water");native_mesh=[]
	for surface in range(nodes[1].mesh.get_surface_count()):native_mesh.append(nodes[1].mesh.surface_get_arrays(surface))
	check(var_to_bytes(native_mesh)==mesh_before and nodes[1].get_node("CaveCollision").get_child(0).shape.get_faces().to_byte_array()==native_faces.to_byte_array(),"Actual native mesh arrays and collision shape survive CPU result release unchanged")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable indexed proof source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_indexed_surface.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"native_images":image_count,"triangle_corners":old_vertices,"unique_render_vertices":unique_vertices,"original_atlas_bytes":old_atlas_bytes,"indexed_atlas_bytes":new_atlas_bytes,"reference_usec":reference_usec,"indexed_usec":indexed_usec,"scope":"Promoted exact render-index transport equals accepted private prototype on actual original two-parent decoded terrain attributes,shared grid with sharp normal/color seams and entry/interior group boundary. Full ordered expanded vertex/normal/color/68-float atlas and unmodified collision-face byte comparison;actual SurfaceRenderer multi-surface PBR and68-channel VERTEX_ID weighted diagnostics,three views unindexed/indexed/unindexed full images. Original float padding versus byte padding exact;actual native resources survive CPU staging release. Not an actual entrance extraction,whole live walk or process-memory saving certificate. Single ordered timings are diagnostics,not benchmark. Initial monolithic-shader fixture exceeded1536MiB before images;current fixture uses the actual existing configured-owner shader selection,not a changed production shader policy."},"  "));print("CAVE_INDEXED_SURFACE ",checks," failures=",failures);for node:Node in nodes:node.queue_free()
	scene.queue_free();light.queue_free();quit(0 if failures.is_empty() else 1)
