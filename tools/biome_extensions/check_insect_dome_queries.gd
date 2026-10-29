extends "res://tools/biome_extensions/check_insect_domes.gd"
class PortalCounter:
	extends RefCounted
	var calls:int=0
	func sites(_bounds:Rect2)->Array:
		calls+=1;return []
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_insect_dome_queries.gd","res://tools/biome_extensions/check_insect_domes.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/artifacts/check_insect_domes.json","res://tools/biome_extensions/artifacts/check_insect_vents.json"]:hashes[path]=FileAccess.get_sha256(path)
	var dome_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_insect_domes.json"));check(dome_manifest.passed,"Real dome manifest")
	var vent_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_insect_vents.json"));check(vent_manifest.passed,"Real non-dome manifest")
	var b=make_builder(6);b.settings.insect_colony.structure_density=0
	var counter:=PortalCounter.new();Structures.new().build(b,Vector2i(-186,-233),PackedFloat64Array(),counter.sites)
	check(counter.calls==0,"Empty structure tile does not query reserved entrances")
	var sites:Array=[]
	for site:Dictionary in dome_manifest.sites:
		b=make_builder(6,int(site.seed));b.settings.insect_colony.nest_vent_frequency=0;b.settings.insect_colony.nest_protect_burrows=false;b.chunk_size=8192
		var cell:=Vector2i(floori(site.position[0]/8192),floori(site.position[1]/8192));counter=PortalCounter.new()
		var current:Array=Structures.new().build(b,cell,PackedFloat64Array(),counter.sites)
		check(counter.calls==1,"All dome roots in a coarse tile share one lazy portal query")
		check(current==Structures.new().build(b,cell),"Empty protected-site result preserves complete geometry")
		b.settings.insect_colony.nest_broad_domes=false;counter=PortalCounter.new();Structures.new().build(b,cell,PackedFloat64Array(),counter.sites)
		check(counter.calls==0,"Independent disabled mode performs no new portal query")
		sites.append({"seed":site.seed,"span_m":8192,"enabled_calls":1,"disabled_calls":0})
	for site:Dictionary in vent_manifest.cases:
		if site.archetype!=0:continue
		b=make_builder(6,int(site.seed));b.settings.insect_colony.nest_protect_burrows=false;var cell:=Vector2i(floori(site.position[0]/256),floori(site.position[1]/256));counter=PortalCounter.new()
		Structures.new().build(b,cell,PackedFloat64Array(),counter.sites)
		check(counter.calls==0,"Admitted cathedral-only tile performs no dome-protection query")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable query-policy source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_dome_queries.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"sites":sites,"source_sha256":hashes,"production_registration":true,"scope":"Actual empty, cathedral-only, independent-disabled and three seeded coarse multi-root tiles verify zero or one lazy protected-entrance query and exact complete geometry for empty site results. Numeric query counts, not runtime speed or general performance acceptance."},"  "))
	print("INSECT_DOME_QUERIES ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
