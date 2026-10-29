extends Control
## Keep main.tscn and its game content intact. Only the order of preparation
## changes:the configured shader precedes the large texture banks.
func _ready()->void:
	await get_tree().process_frame
	await preload("res://scripts/terrain_shader_preparation.gd").prepare(get_tree(),load("res://config/world/terrain_settings.tres"))
	get_tree().change_scene_to_file("res://scenes/main.tscn")
