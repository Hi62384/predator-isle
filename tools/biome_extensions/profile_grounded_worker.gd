extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/profile_ground_union_worker.gd")
	var constructor:String="var prototype:GDScript=Candidate.script_for();";assert(code.count(constructor)==1);code=code.replace(constructor,"")
	var generator:String='var generator=prototype.new() if enabled else preload("res://scripts/lod_biome_extension_structures.gd").new();';assert(code.count(generator)==1);code=code.replace(generator,'var generator=preload("res://scripts/lod_biome_extension_structures.gd").new();')
	var settings:String="builder.settings.alien_infected.emission_strength=0;";assert(code.count(settings)==1);code=code.replace(settings,settings+"builder.settings.alien_infected.hive_grounded_shoulders=enabled;")
	var marker:String="var records:Array=[];";assert(code.count(marker)==1);code=code.replace(marker,'guards["res://tools/biome_extensions/profile_grounded_worker.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/profile_grounded_worker.gd");'+marker)
	code=code.replace("profile_ground_union_worker.json","profile_grounded_worker.json")
	code=code.replace('"scope":"PRIVATE nine alternating','"scope":"REGISTERED actual production producer/settings flag false/true,nine alternating').replace("Proposed change must alter","Actual registered setting must alter").replace("production acceptance.","all-world production performance acceptance.")
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("_initialize")
