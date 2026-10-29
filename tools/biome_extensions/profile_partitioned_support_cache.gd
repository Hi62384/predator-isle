extends "res://tools/biome_extensions/profile_margin_retaining_lod.gd"
const Controller=preload("res://scripts/lod_biome_extension_structures.gd")
const SupportCandidate=preload("res://tools/biome_extensions/partitioned_support_cache_candidate.gd")
class CountedBuilder:
	extends "res://scripts/terrain_mesh_builder.gd"
	var canonical_calls:int=0
	func _get_height(x:float,z:float,publish:bool=true)->float:
		canonical_calls+=1;return super._get_height(x,z,publish)
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/forest_sampler.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/partitioned_support_cache_candidate.gd","res://tools/biome_extensions/profile_partitioned_support_cache.gd","res://tools/biome_extensions/profile_margin_retaining_lod.gd","res://tools/biome_extensions/profile_far_conduit_lod.gd","res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	# Three alternating dense pairs are required before interpreting policy
	# timing, plus the same three independent normal-rarity mixed-owner tiles.
	for fixture:int in range(6):
		var dense:bool=fixture<3;var seed_id:int=92881 if dense else [73921,17,92881][fixture-3];var size:int=16384 if dense else 4096;var coordinate:=Vector2i(-5,-7)
		if not dense:
			var finder=make_builder(7,seed_id);finder.settings.alien_infected.feature_scale=.2;finder.settings.forest_coverage=100;finder.settings.alien_infected_coverage=50;finder._configure_noise();coordinate=locate_mixed_tile(finder,seed_id)
		var pair:Dictionary={};var order:Array=[false,true] if fixture%2==0 else [true,false]
		for trial:bool in order:
			var configured=make_builder(7,seed_id);var b=CountedBuilder.new();b.world_seed=seed_id;b.settings=configured.settings;b.settings.alien_infected.feature_scale=.2
			if dense:b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true
			else:b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50
			b._configure_noise();b.chunk_size=size
			var arrays:Array=b.build(coordinate,16);var features=preload("res://scripts/terrain_feature_meshes.gd").new();var detail:Dictionary=features.build(b,coordinate)
			var g=SupportCandidate.new() if trial else Controller.new();g.conduit_cache_enabled=false;b.canonical_calls=0
			check(not is_finite(g.global_floor(b)),"Both declared hosts use retained-contact topology, no analytic-bound change from counted builder")
			var started:int=Time.get_ticks_usec();var structures:Array=g.build(b,coordinate,Controller.support_grids(),features.portal_sites);var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
			check(structures[2]!=null,"Nonempty complete actual tile required, no empty speed case")
			pair[trial]={"outputs":[arrays,b.built_extension_data,b.built_extension_rows,b.built_extension_mask,detail,structures],"ms":elapsed,"canonical_calls":b.canonical_calls,"vertices":structures[2][Mesh.ARRAY_VERTEX].size() if structures[2]!=null else 0,"support_entries":g._support_heights.size(),"support_serialized_bytes":var_to_bytes(g._support_heights).size()}
			print("PARTITIONED_SUPPORT_PAIR ",fixture," trial=",trial," ms=",elapsed," canonical_calls=",b.canonical_calls," entries=",g._support_heights.size())
		check(pair[false].outputs==pair[true].outputs,"Complete canonical fields/metadata/features/all structure attributes exact")
		check(pair[true].support_entries<=16384,"Original support dictionary-entry cap retained including policy state")
		cases.append({"fixture":fixture,"mode":"coastal_dense" if dense else "mixed","seed":seed_id,"tile":coordinate,"span_m":size,"original_ms":pair[false].ms,"trial_ms":pair[true].ms,"ratio":pair[true].ms/maxf(pair[false].ms,.001),"original_canonical_calls":pair[false].canonical_calls,"trial_canonical_calls":pair[true].canonical_calls,"vertices":pair[true].vertices,"original_support_serialized_bytes":pair[false].support_serialized_bytes,"trial_support_serialized_bytes":pair[true].support_serialized_bytes,"original_support_entries":pair[false].support_entries,"trial_support_entries":pair[true].support_entries})
	check(cases.size()==6,"All three alternating dense pairs and three seeded normal mixed tile pairs")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private partitioned cache benchmark source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_partitioned_support_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":false,"scope":"Private exact support-corner eviction policy versus current registered retained-contact LOD, same 16384 total dictionary entries and unchanged complete outputs. Three alternating dense coast-enabled cold pairs plus three seeded normal mixed-owner pairs; mesh memo disabled equally, normal height memo unchanged, canonical calls counted equally. Source topology, view, rarity, worker count and budgets unchanged. Serialized cache bytes reported rather than assumed equal. Not native timing/memory, all-world performance or production adoption."},"  "))
	print("PARTITIONED_SUPPORT_PROFILE_DONE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
