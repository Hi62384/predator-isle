extends RefCounted
static func configure(node:Node,enabled:bool)->void:
	node.set_script(preload("res://tools/biome_extensions/ground_union_worker_fixture.gd").controller_script())
	node.set("_study_structure_script",preload("res://tools/biome_extensions/grounded_earth_crystal_candidate.gd").script_for() if enabled else load("res://scripts/lod_biome_extension_structures.gd"))
	assert(node is ChunkTerrain)
