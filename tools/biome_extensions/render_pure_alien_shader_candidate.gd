extends "res://tools/biome_extensions/render_alien_memory_baseline.gd"
## Private specialization, admitted only for entirely pure non-coastal tiles.
## Vertex logic, portal clipping, derivatives, tissue shading and final debug
## guard are retained from the production source. No production registration.
var checked_tiles:int=0
func output_basename()->String:return "render_pure_alien_shader_candidate"
func prepare_shader()->void:
	hashes["res://tools/biome_extensions/render_pure_alien_shader_candidate.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/render_pure_alien_shader_candidate.gd")
	var shader:Shader=load("res://shaders/terrain_biomes.gdshader");var original:String=shader.code
	var start:int=original.find("void fragment() {");var shading:int=original.find(" if(coast_control.x>.999)",start);var guard:int=original.rfind(" // Overlay blending must not restore physical lighting")
	assert(start>0 and shading>start and guard>shading)
	# Retain all declarations/functions and the actual vertex/fragment prelude;
	# unreachable old-owner shading is omitted from this PRIVATE fragment only.
	var body:String="""
 vec3 color,gradient,emission;float rough;
 shade_extension(7,extension_control(7),n,forest_dx,forest_dy,projection,fine,color,rough,gradient,emission);
 vec3 mapped=normalize(n+gradient);
 ALBEDO=color;ROUGHNESS=rough;SPECULAR=.2;EMISSION=emission;
 NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0)).xyz);
 if(debug_view==3){ALBEDO=vec3(0);EMISSION=color;}
 if(debug_view==4 || debug_view==8){ALBEDO=vec3(0);EMISSION=(debug_view==4?n:mapped)*.5+.5;}
"""
	shader.code=original.substr(0,shading)+body+original.substr(guard)
	private_shader_override=true;print("PURE_ALIEN_SHADER_PRIVATE_READY")
func settle()->bool:
	var result:bool=await super.settle()
	if not result:return false
	assert(not terrain._settings_snapshot.rocky_coast_enabled and not terrain._settings_snapshot.beaches_enabled)
	var rejected:Array=[];var observed:Array=[]
	for node:MeshInstance3D in terrain._active_chunks.values():
		var material:ShaderMaterial=node.mesh.surface_get_material(0)
		assert(material.get_shader_parameter("extension_payload_enabled") and int(material.get_shader_parameter("extension_active_mask"))==128,"Specialization must not silently shade mixed/empty tiles")
		var atlas:Image=material.get_shader_parameter("extension_payload").get_image();assert(atlas!=null and atlas.get_format()==Image.FORMAT_RGBA8)
		var rows:int=atlas.get_height();assert(atlas.get_width()==rows*8);var data:PackedByteArray=atlas.get_data()
		var lowest:int=255;var highest:int=0;var partial:int=0
		for z in range(rows):
			for x in range(rows):
				var weight:int=data[(z*rows*8+7*rows+x)*4];lowest=mini(lowest,weight);highest=maxi(highest,weight)
				if weight!=255:partial+=1
		observed.append({"position":node.position,"rows":rows,"minimum_alien_weight_byte":lowest,"maximum_alien_weight_byte":highest,"nonfull_samples":partial})
		if partial>0:rejected.append(observed[-1])
		checked_tiles+=1
	if not rejected.is_empty():
		for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
		FileAccess.open("res://tools/biome_extensions/artifacts/render_preloaded_pure_alien_domain_details.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"failures":["Strict all-sample pure-owner predicate rejected actual committed tiles; the private specialization is not accepted for these nodes."],"source_sha256":hashes,"production_registration":false,"actual_rendering_context":true,"committed":terrain.committed_revision==terrain.partition_revision,"tiles":observed,"rejected_tiles":rejected,"scope":"Actual first-cut GPU atlas readback after early private shader registration, preserving every partial owner sample as a rejection, not loosening the predicate. This is a failed domain diagnostic, not full-frame correctness or memory acceptance."},"  "))
		print("PURE_ALIEN_DOMAIN_REJECTED tiles=",rejected.size()," of ",observed.size());quit(1);return false
	print("PURE_ALIEN_DOMAIN_CHECKED tiles=",checked_tiles)
	return true
