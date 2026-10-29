extends "res://tools/biome_extensions/check_game_startup.gd"
var held_boot:GDScript
func report_basename()->String:return "check_balanced_startup_queue_candidate"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"near_ring_first_m":1024,"distant_priority":"Largest estimated sampling work first,then distance"}
func run()->void:
	held_boot=load("res://scripts/world_startup.gd")
	var source:String=held_boot.source_code;var needle:String='\tget_tree().change_scene_to_file('
	assert(source.count(needle)==1);held_boot.source_code=source.replace(needle,'\tpreload("res://tools/biome_extensions/startup_queue_patch_candidate.gd").apply()\n'+needle);assert(held_boot.reload()==OK)
	if OS.get_cmdline_user_args().has("validate-only"):
		print("BALANCED_QUEUE candidate compiled;no timing acceptance");quit();return
	await super.run()
