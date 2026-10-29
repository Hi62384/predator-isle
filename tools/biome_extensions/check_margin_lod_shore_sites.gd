extends "res://tools/biome_extensions/check_all.gd"
const Controller=preload("res://scripts/lod_biome_extension_structures.gd")
func locate(b,landmark:Vector2)->Dictionary:
	var field=b._extras[7];var span:float=4096*field.settings.feature_scale;var center:=Vector2i(floori(landmark.x/span),floori(landmark.y/span))
	for z in range(-24,25):
		for x in range(-24,25):
			var cell:=center+Vector2i(x,z);var p:Vector2=field.hive_node(cell);var d:Dictionary=field.descriptor(cell,span)
			if d.chance>field.settings.structure_density or b._island_mask(p.x,p.y)<.03:continue
			var ground:float=b._get_height(p.x,p.y);var coast_amount:float=b._last_coast.x
			if coast_amount<.12 or ground<=b.get_water_surface_height(p.x,p.y)+4:continue
			b.chunk_size=256;var owner:=Vector2i(floori(p.x/256),floori(p.y/256));var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var portals:Callable=mesher.portal_sites;mesher.builder=b
			var actual:Array=Controller.new().build(b,owner,Structures.support_grids(),portals)
			if actual[2]==null:continue
			var full:Array=Structures.new().build(b,owner,Structures.support_grids(),portals)
			check(actual==full,"Actual complete shore-root near producer remains exact original full detail")
			return {"seed":b.world_seed,"position":[p.x,p.y],"hive_cell":[cell.x,cell.y],"feature_scale":field.settings.feature_scale,"canonical_ground_m":ground,"actual_coastal_overlay_amount":coast_amount,"normal_descriptor_chance":d.chance,"normal_structure_density":field.settings.structure_density,"near_structure_vertices":actual[2][Mesh.ARRAY_VERTEX].size(),"forced_rarity":false,"near_arrays_exact":actual==full}
	return {}
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_settings.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/check_margin_lod_shore_sites.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admitted=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));check(admitted.passed,"Seed-specific actual land landmarks")
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var landmark:=Vector2.INF
		for site:Dictionary in admitted.cases:
			if int(site.seed)==seed_id:landmark=Vector2(site.position[0],site.position[1])
		check(landmark.is_finite(),"Declared seeded land landmark")
		var b=make_builder(7,seed_id);b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true;b._configure_noise()
		var site:Dictionary=locate(b,landmark);check(not site.is_empty(),"Actual dry normal-rarity root in active coastal deformation, not merely a shore-enabled inland host")
		if not site.is_empty():cases.append(site)
	check(cases.size()==3,"All three actual shore cases, no missing-site skip")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable actual-shore admission source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_margin_lod_shore_sites.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Three real normal-rarity dry hive roots with actual coastal overlay at least 0.12 and exact full original near producer arrays. Coast and beach stay enabled at production settings, full Alien owner, default feature scale. Admission/near numerical proof only: actual threaded native views, farther reduced geometry, arbitrary shores and traversal remain separate."},"  "))
	print("MARGIN_LOD_ACTUAL_SHORES ",checks," cases=",cases," failures=",failures);quit(0 if failures.is_empty() else 1)
