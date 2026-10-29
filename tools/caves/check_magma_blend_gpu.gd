extends "res://tools/caves/check_frozen_phase_gpu.gd"
const Materials=preload("res://scripts/caves/biome_materials.gd")
const Palette=preload("res://scripts/caves/material_palette.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
const Blend=preload("res://scripts/caves/biome_blend.gd")
func diagnostic(code:String)->String:return code.replace("render_mode diffuse_burley,specular_schlick_ggx;","render_mode unshaded,fog_disabled,cull_disabled;")
func material(code:String,registry:Resource)->ShaderMaterial:
	var result:=ShaderMaterial.new();var shader:=Shader.new();shader.code=diagnostic(code);result.shader=shader;Palette.bind(result,0,[],false);Materials.bind(result,["crystal","frozen","magma"],registry,{"pools":[{"center":Vector3.ZERO,"water_y":0.0,"radius":100.0}]});return result
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_phase_gpu.gd","res://scripts/caves/biome_materials.gd","res://scripts/caves/biome_blend.gd","res://scripts/caves/frozen_surface.gd","res://scripts/caves/crystal_surface.gd","res://scripts/caves/magma_surface.gd","res://config/caves/biomes/magma_cave_definition.tres","res://shaders/default_cave_rock.gdshader","res://shaders/cave_frozen_surface.gdshaderinc","res://shaders/cave_crystal_surface.gdshaderinc","res://materials/cave_colors.tres","res://materials/cave_normals.tres"]:guards[path]=FileAccess.get_sha256(path)
	var registry:Resource=Fixture.registry(load("res://config/caves/cave_biome_regions.tres"),load("res://config/caves/biomes/magma_cave_definition.tres"));var original:Shader=load("res://shaders/default_cave_rock.gdshader");var ids:Array=["crystal","frozen","magma"];var current:ShaderMaterial=material(Materials.shader(original,ids,registry).code,registry);var reversed:ShaderMaterial=material(Materials.shader(original,["magma","frozen","crystal"],registry).code,registry)
	# Independent oracle extracts each actual provider's complete target from
	# a non-accumulating source and weights ALL targets from the same host.
	var independent:String=Blend.source(original.code,3)
	for slot in range(3):independent=Materials.definition(registry,ids[slot]).surface_provider.new().source(independent,slot,false)
	var positions:Array[int]=[independent.find("\n float crystal_amount="),independent.find("\n vec3 frozen_p="),independent.find("\n float magma_cooled="),independent.rfind("}")];check(positions[0]>0 and positions[1]>positions[0] and positions[2]>positions[1] and positions[3]>positions[2],"Independent three-provider target blocks found before production accumulation")
	guards["res://shaders/cave_magma_surface.gdshaderinc"]=FileAccess.get_sha256("res://shaders/cave_magma_surface.gdshaderinc")
	var reference_code:String=independent.substr(0,positions[0])+"\nvec3 magma_test_base=ALBEDO;vec3 magma_test_sum=vec3(0.0);\n"
	var restore:String="ALBEDO=magma_test_base;\n"
	# Every target starts from identical host PBR, including the normal used
	# by the volcanic relief. The oracle still sums Albedo independently.
	for name:String in ["NORMAL","EMISSION","ROUGHNESS","SPECULAR","METALLIC","AO","AO_LIGHT_AFFECT"]:
		var type:String="vec3" if name in ["NORMAL","EMISSION"] else "float"
		reference_code+=type+" magma_test_base_"+name+"="+name+";\n"
		restore+=name+"=magma_test_base_"+name+";\n"
	for slot in range(3):
		var block:String=independent.substr(positions[slot],positions[slot+1]-positions[slot]);var regex:=RegEx.new();regex.compile("cave_biome_control\\(cave_"+str(ids[slot])+"_weight,[^)]*\\)");block=regex.sub(block,"1.0",true);reference_code+=restore+block+"\nmagma_test_sum+=ALBEDO*cave_biome_raw_weights["+str(slot)+"];\n"
	reference_code+="ALBEDO=magma_test_sum+magma_test_base*(1.0-cave_biome_raw_weights.x-cave_biome_raw_weights.y-cave_biome_raw_weights.z);EMISSION=vec3(0.0);\n"+independent.substr(positions[3]);var reference:ShaderMaterial=material(reference_code,registry)
	var viewport:=SubViewport.new();viewport.size=Vector2i(512,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=32;camera.position=Vector3(0,0,100);viewport.add_child(camera);var node:MeshInstance3D=panel(-32,32,0,current);viewport.add_child(node);var base_arrays:Array=node.mesh.surface_get_arrays(0);var records:Array=[]
	var cases:Array=[{"name":"magma_only","left":Vector3(0,0,1),"right":Vector3(0,0,1)},{"name":"frozen_only","left":Vector3(0,1,0),"right":Vector3(0,1,0)},{"name":"crystal_only","left":Vector3(1,0,0),"right":Vector3(1,0,0)},{"name":"equal_three","left":Vector3.ONE/3,"right":Vector3.ONE/3},{"name":"default_share","left":Vector3(.1,.2,.3),"right":Vector3(.1,.2,.3)},{"name":"gradient","left":Vector3(.1,.6,.1),"right":Vector3(.65,.1,.25)},{"name":"upward_partial","left":Vector3(.3,.2,.1),"right":Vector3(.5,.1,.4),"upward":true}]
	for item:Dictionary in cases:
		var arrays:Array=base_arrays.duplicate();var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var reverse_uv:=PackedVector2Array();var reverse_uv2:=PackedVector2Array()
		if item.get("upward",false):var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate();normals.fill(Vector3.UP);arrays[Mesh.ARRAY_NORMAL]=normals
		for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var weights:Vector3=item.left.lerp(item.right,clampf((point.x+32)/64,0,1));uv.append(Vector2(weights.x,weights.y));uv2.append(Vector2(weights.z,0));reverse_uv.append(Vector2(weights.z,weights.y));reverse_uv2.append(Vector2(weights.x,0))
		arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=uv2;var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh;node.material_override=reference;var expected:Image=await picture(viewport,"magma_blend_"+item.name+"_independent");node.material_override=current;var actual:Image=await picture(viewport,"magma_blend_"+item.name+"_production");var error:int=maximum_error(expected,actual);check(error<=2,"True partial three-biome Albedo equals independent complete-target oracle within2RGBbytes "+item.name)
		var backwards:Array=arrays.duplicate();backwards[Mesh.ARRAY_TEX_UV]=reverse_uv;backwards[Mesh.ARRAY_TEX_UV2]=reverse_uv2;var reverse_mesh:=ArrayMesh.new();reverse_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,backwards);node.mesh=reverse_mesh;node.material_override=reversed;var reverse_image:Image=await picture(viewport,"magma_blend_"+item.name+"_reversed");var reverse_error:int=maximum_error(expected,reverse_image);check(reverse_error<=2,"Three actual partially covered biome targets independent of provider/slot order")
		node.mesh=mesh;node.material_override=current;var returned:Image=await picture(viewport,"magma_blend_"+item.name+"_return");check(returned.get_data()==actual.get_data(),"Exact image return after three-provider UV/UV2 slot reversal");records.append({"case":item.name,"rgb_error":error,"reverse_rgb_error":reverse_error})
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable three-provider material source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_blend_gpu.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"scope":"Actual Crystal/Frozen/Magma production surface adapters and existing host/ice PBR;independent full-target oracle from same host versus production accumulation;singles,three-way/default-share/gradient/upward-sediment,provider reversal and exact return,predeclared2RGBbyte bound. Unshaded Albedo isolation only,not physical hot-ice admission,other PBR outputs,world art or FPS."},"  "));print("MAGMA_BLEND_GPU ",checks," records=",records," failures=",failures);viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
