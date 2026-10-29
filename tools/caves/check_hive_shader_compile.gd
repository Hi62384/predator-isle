extends "res://tools/biome_extensions/check_all.gd"
const Surface=preload("res://scripts/caves/surface_shader.gd")
const Variants=preload("res://scripts/terrain_shader_variants.gd")
func run()->void:
	check(DisplayServer.get_name()!="headless","Native graphics compiler required");var guards:Dictionary={}
	for path:String in ["res://scripts/caves/surface_shader.gd","res://scripts/terrain_shader_variants.gd","res://shaders/terrain_biomes.gdshader","res://shaders/hive_cave.gdshader","res://shaders/hive_tissue_material.gdshaderinc","res://shaders/cave_entry_hive.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://tools/caves/check_hive_shader_compile.gd"]:guards[path]=FileAccess.get_sha256(path)
	var original:String=FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader");var variants:Array=[]
	for organic:bool in [false,true]:
		var shader:=Shader.new();shader.code=Surface.code(Variants.source_for(original,1<<15),true,true,organic);var names:Dictionary={}
		for uniform:Dictionary in shader.get_shader_uniform_list():names[uniform.name]=true
		check(names.has("cave_surface_payload") and names.has("cave_hive_entry_material" if organic else "cave_entry_colors"),"Complete actual configured-owner portal shader compiles with expected transport/material controls");variants.append({"organic":organic,"uniforms":names.size()});print("HIVE_SHADER_PREFLIGHT organic=",organic," uniforms=",names.size())
	var interior:Shader=load("res://shaders/hive_cave.gdshader");var names:Dictionary={}
	for uniform:Dictionary in interior.get_shader_uniform_list():names[uniform.name]=true
	check(names.has("hive_region") and names.has("biological_colors") and names.has("normal_strength"),"Complete interior shader compiles with actual organic controls")
	for frame in range(3):await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable shader preflight source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_hive_shader_compile.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"variants":variants,"scope":"Actual native graphics shader parser/uniform compilation for original configured pure-Alien terrain portal replacement in rock and organic modes plus Hive interior. Catches full include-scope/name collisions before expensive live preload. Not native pixels,PBR equivalence,live traversal or full feature acceptance."},"  "));print("CAVE_HIVE_SHADER_COMPILE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
