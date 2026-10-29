extends "res://tools/biome_extensions/check_all.gd"
const ORIGINAL="res://tools/biome_extensions/artifacts/revisions/experiment_coastal_height_cache_adoption_60547d2bad62/sources/scripts/biome_extension_structures.gd.txt"
func run()->void:
	var hashes:Dictionary={}
	for path:String in [ORIGINAL,"res://tools/biome_extensions/profile_insect_vents.gd","res://tools/biome_extensions/run_test.ps1","res://tools/biome_extensions/artifacts/check_insect_vents.json","res://scripts/insect_vent_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/insect_colony_sampler.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var original:=GDScript.new();original.source_code=FileAccess.get_file_as_string(ORIGINAL);check(original.reload()==OK,"Frozen complete original emitter loads")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_insect_vents.json"));check(manifest.passed,"Real default-rarity geometry cases")
	var records:Array=[]
	for repeat in range(4):
		for site:Dictionary in manifest.cases:
			var pair:Dictionary={};var fields:Array=[]
			for variant:String in (["original","vents"] if repeat%2==0 else ["vents","original"]):
				var b=make_builder(6,int(site.seed));b.chunk_size=256;var coordinate:=Vector2i(floori(site.position[0]/256),floori(site.position[1]/256));var terrain_arrays:Array=b.build(coordinate,16)
				if fields.is_empty():fields=terrain_arrays
				else:check(fields==terrain_arrays,"Ventilation does not alter any canonical terrain array")
				var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.build(b,coordinate)
				var g=original.new() if variant=="original" else Structures.new()
				var started:int=Time.get_ticks_usec();var geometry:Array=g.build(b,coordinate,Structures.support_grids(),features.portal_sites);var ms:float=(Time.get_ticks_usec()-started)/1000.0
				check(geometry[1]!=null,"Actual nonempty mound complex")
				pair[variant]={"ms":ms,"vertices":geometry[1][Mesh.ARRAY_VERTEX].size(),"serialized_array_bytes":var_to_bytes(geometry).size()}
				if variant=="original":
					b.settings.insect_colony.nest_vent_frequency=0
					b.settings.insect_colony.nest_broad_domes=false
					b.settings.insect_colony.nest_protect_burrows=false
					check(Structures.new().build(b,coordinate,Structures.support_grids(),features.portal_sites)==geometry,"Entire original emitter exact with both controls disabled")
			check(pair.vents.vertices==pair.original.vertices+504,"One complete original summit replaced by thick lined recess")
			records.append({"seed":site.seed,"repeat":repeat,"original":pair.original,"vents":pair.vents,"added_ms":pair.vents.ms-pair.original.ms,"ratio":pair.vents.ms/maxf(pair.original.ms,.001)})
	var added:Array=[];var ratios:Array=[]
	for pair:Dictionary in records:added.append(pair.added_ms);ratios.append(pair.ratio)
	added.sort();ratios.sort()
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable generation-cost source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_insect_vents.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"production_registration":true,"source_sha256":hashes,"pairs":records,"median_added_ms":(added[5]+added[6])*.5,"median_ratio":(ratios[5]+ratios[6])*.5,"scope":"Twelve serial alternating fresh-builder original/new supplemental-generation pairs at three actual default-rarity near mounds, including vents, broad domes and whole-complex burrow protection with actual portal callbacks. Canonical terrain/feature prepass is outside timed structure generation. Original is the frozen complete pre-vent emitter, not a current emitter paying new admission costs. Disabling ALL THREE new controls equals the original; each admitted vent adds504 vertices, broad morphology adds none, protected complexes may be excluded. CPU addition and numeric serialized-array size, not shader, upload, frame-time, far-LOD, arbitrary-density or general performance acceptance."},"  "))
	print("INSECT_VENT_COST ",records.size()," pairs; median added ms=",(added[5]+added[6])*.5," failures=",failures);quit(0 if failures.is_empty() else 1)
