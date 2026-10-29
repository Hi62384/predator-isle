extends "res://tools/caves/check_frozen_phase_gpu.gd"
const Blend=preload("res://scripts/caves/biome_blend.gd")
const Binding=preload("res://scripts/caves/surface_biomes.gd")
class Weights extends RefCounted:
	func biome_ids_for_cell(_key):return ["a","b","c","d"]
	func biome_weights_at(p,ids):
		var t:float=clampf((p.x+32)/64,0,1);var s:float=clampf((p.y+16)/32,0,1);var w:=Vector4(.05+.4*t,.05+.3*s,.05+.1*(1-t),.05+.1*(1-s))
		for i in range(ids.size(),4):w[i]=0
		return w
func material(count:int,mode:String)->ShaderMaterial:
	var code:String="shader_type spatial;render_mode unshaded,fog_disabled,cull_disabled;void vertex(){UV=vec2(0.0);UV2=vec2(0.0);}void fragment(){vec3 result=vec3(.11,.13,.17);vec3 colors[4]={vec3(.8,.1,.12),vec3(.1,.8,.15),vec3(.12,.18,.8),vec3(.8,.7,.15)};BODY ALBEDO=result;}"
	code=Blend.source(code,count);var body:String=""
	if mode=="reference":
		body="float total=0.0;for(int i=0;i<"+str(count)+";i++)total+=cave_biome_raw_weights[i];result*=1.0-total;for(int i=0;i<"+str(count)+";i++)result+=colors[i]*cave_biome_raw_weights[i];"
	elif mode=="vertex_division":
		code=code.replace("cave_biome_raw_weights=vec4(UV,UV2);","vec4 raw=vec4(UV,UV2);cave_biome_raw_weights=raw;for(int i=0;i<"+str(count)+";i++){float later=0.0;for(int j=0;j<4;j++){if(j>i&&j<"+str(count)+")later+=raw[j];}cave_biome_raw_weights[i]=clamp(raw[i]/max(1.0-later,.000001),0.0,1.0);}")
		body="for(int i=0;i<"+str(count)+";i++)result=mix(result,colors[i],cave_biome_raw_weights[i]);"
	else:body="for(int i=0;i<"+str(count)+";i++)result=mix(result,colors[i],"+("cave_biome_control(cave_biome_raw_weights[i],i)" if mode=="current" else "cave_biome_raw_weights[i]")+");"
	var result:=ShaderMaterial.new();var shader:=Shader.new();shader.code=code.replace("BODY",body);result.shader=shader;return result
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_phase_gpu.gd","res://scripts/caves/biome_blend.gd","res://scripts/caves/surface_biomes.gd","res://scripts/caves/biome_materials.gd","res://scripts/caves/frozen_surface.gd","res://scripts/caves/crystal_surface.gd"]:guards[path]=FileAccess.get_sha256(path)
	var view:=SubViewport.new();view.size=Vector2i(512,256);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);var world:=Node3D.new();view.add_child(world);var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=32;camera.position=Vector3(0,0,100);camera.far=50000;world.add_child(camera)
	var node:MeshInstance3D=panel(-32,32,0,material(2,"current"));world.add_child(node);var raw:Array=node.mesh.surface_get_arrays(0);var records:Array=[]
	for count in range(2,5):
		var ids:Array=["a","b","c","d"].slice(0,count);var bound:Dictionary=Binding.bind(raw,Weights.new(),Vector3i.ZERO,ids);check(bound.valid and var_to_bytes(bound.arrays[Mesh.ARRAY_VERTEX])==var_to_bytes(raw[Mesh.ARRAY_VERTEX]) and var_to_bytes(bound.arrays[Mesh.ARRAY_NORMAL])==var_to_bytes(raw[Mesh.ARRAY_NORMAL]),"Actual UV/UV2 binding preserves physical vertices/normals")
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,bound.arrays);node.mesh=mesh;node.material_override=material(count,"reference");var reference:Image=await picture(view,"blend_"+str(count)+"_reference");node.material_override=material(count,"current");var current:Image=await picture(view,"blend_"+str(count)+"_current");var error:int=maximum_error(reference,current);check(error<=2,"Actual per-fragment conditional weighted sum matches raw barycentric reference under predeclared2RGB-byte bound")
		node.material_override=material(count,"raw_sequential");var old:Image=await picture(view,"blend_"+str(count)+"_raw_sequential_negative");var old_error:int=maximum_error(reference,old);check(old_error>2,"Uncorrected sequential mixing is a live wrong-weight positive negative control")
		node.material_override=material(count,"vertex_division");var divided:Image=await picture(view,"blend_"+str(count)+"_vertex_division_negative");var divided_error:int=maximum_error(reference,divided);check(divided_error>2,"Dividing at vertices instead of fragment visibly changes triangle interior,so raw UV transport is retained")
		node.material_override=material(count,"current");var restored:Image=await picture(view,"blend_"+str(count)+"_return");check(current.get_data()==restored.get_data(),"Exact same native GPU weighted-composition image return");records.append({"slots":count,"current_maximum_rgb_byte_error":error,"raw_sequential_error":old_error,"premature_vertex_division_error":divided_error})
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable GPU blend source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_biome_blend_gpu.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"scope":"Actual production UV/UV2 numeric binding and generated multi-biome helper compiled/rendered on native GPU with2/3/4overlapping interpolated raw weights,capture before deliberate parent UV decode,weighted reference/wrong raw sequential/wrong early vertex division/exact-return controls. Flat diagnostic colors isolate compositing,not Crystal art,world streaming or FPS."},"  "));print("CAVE_BLEND_GPU ",checks," ",records," failures=",failures);view.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
