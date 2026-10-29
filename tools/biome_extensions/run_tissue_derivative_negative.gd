extends SceneTree
const OLD="res://tools/biome_extensions/artifacts/revisions/experiment_diagnose_tissue_flow_contacts_b32998144334/sources/shaders/alien_tissue_flow.gdshaderinc.txt"
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var negative:String=FileAccess.get_file_as_string(OLD)
	assert(negative.count("vec3 alien_flow_color(vec3 base,vec3 n){")==1 and negative.contains("dFdx(uv),dFdy(uv)"))
	negative=negative.replace("vec3 alien_flow_color(vec3 base,vec3 n){","vec3 alien_flow_color(vec3 base,vec3 n,vec3 position_dx,vec3 position_dy){")
	var include:Resource=load("res://shaders/alien_tissue_flow.gdshaderinc");assert(include.get_class()=="ShaderInclude")
	var supports_code:bool=false
	for property:Dictionary in include.get_property_list():
		if property.name=="code":supports_code=true
	assert(supports_code);include.set("code",negative);assert(include.get("code")==negative)
	# ResourceLoader's path cache is weak. Keep the include alive through the
	# generated script change and scene load,or the negative silently reloads
	# the corrected file instead of exercising the declared old arithmetic.
	set_meta("held_negative_shader_include",include)
	var generated:String="res://tools/biome_extensions/artifacts/tissue_derivative_negative_source.txt";FileAccess.open(generated,FileAccess.WRITE).store_string(negative)
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/diagnose_tissue_flow_contacts.gd")
	code=code.replace("tissue_contacts_%d_%s.png","tissue_derivative_negative_%d_%s.png").replace("diagnose_tissue_flow_contacts.json","tissue_derivative_negative.json")
	var marker:String="var frozen=JSON.parse_string"
	assert(code.count(marker)==1)
	code=code.replace(marker,'for path:String in ["res://tools/biome_extensions/run_tissue_derivative_negative.gd","'+OLD+'","'+generated+'"]:hashes[path]=FileAccess.get_sha256(path)\n\t'+marker)
	var ready_marker:String="assert(await settle());camera.look_at(focus)"
	assert(code.count(ready_marker)==1)
	code=code.replace(ready_marker,ready_marker+';assert(get_meta("held_negative_shader_include").get("code")==FileAccess.get_file_as_string("'+generated+'"))')
	code=code.replace('"scope":"Diagnostic at the exact frozen', '"scope":"INTENTIONAL prior reconstructed-UV derivative negative. Resource-only ShaderInclude override,old helper source with only its signature adapted to accept the current caller arguments;new bounds,debug lifecycle,geometry and project files unchanged. Actual derivative override text is separately hashed. Diagnostic at the exact frozen')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
