extends RefCounted
## A real mixed-owner fixture. Does not change the user's saved world preset.
static func builder(seed_id:int=73921):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id
	b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false
	b.settings.tropical_coverage=50;b.settings.volcanic_coverage=50
	b.settings.tropical_region_size=14000;b.settings.volcanic_region_size=14000
	b._configure_noise();return b
static func locate(b)->Vector2:
	for i in range(12000):
		var p:=Vector2(i*7919%180000-90000,i*11939%180000-90000)
		b._biome_weights(p.x,p.y)
		if b._tropical_weight>.25 and b._tropical_weight<.75 and b._extra_weights[2]>.25 and b._island_mask(p.x,p.y)>.15:return p
	return Vector2.INF
static func sources()->Dictionary:
	var result:Dictionary={}
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_settings.gd","res://scripts/tropical_sampler.gd","res://scripts/tropical_settings.gd","res://scripts/volcanic_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_collision.gd","res://shaders/terrain_biomes.gdshader","res://shaders/tropical_material.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://config/world/terrain_settings.tres","res://config/biomes/tropical_settings.tres","res://config/biomes/volcanic_settings.tres","res://scenes/main.tscn","res://project.godot","res://tools/tropical/volcanic_transition_fixture.gd"]:result[path]=FileAccess.get_sha256(path)
	return result
