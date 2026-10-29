extends "res://tools/biome_extensions/check_all.gd"
const References=preload("res://tools/biome_extensions/insect_mound_references.gd")
const Candidate=preload("res://tools/biome_extensions/insect_sculpted_mound_candidate.gd")
const Lod=preload("res://scripts/lod_biome_extension_structures.gd")
func arrays(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func run()->void:
	var guards:Dictionary={};var records:Array=[];var original: GDScript=References.original();var stages:Array=[]
	for path:String in [References.SOURCE,"res://tools/biome_extensions/insect_mound_references.gd","res://tools/biome_extensions/insect_mound_profile_candidate.gd","res://tools/biome_extensions/insect_sculpted_mound_candidate.gd","res://tools/biome_extensions/check_insect_profile_registration.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/insect_mound_profiles.gd","res://scripts/biome_extension_settings.gd","res://scripts/insect_vent_geometry.gd","res://scripts/terrain_mesh_builder.gd"]:guards[path]=FileAccess.get_sha256(path)
	check(load("res://config/biomes/insect_colony_settings.tres").nest_construction_profiles,"Actual saved/default profile control enabled")
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(6,seed_id);var field=b._extras[6];var descriptor:Dictionary=field.descriptor(Vector2i(5,-2),2100);var p:Vector2=descriptor.position;var anchor:=Vector3(p.x,b._get_height(p.x,p.y)-8,p.y)
		for kind in range(6):
			for enabled:bool in [false,true]:
				var actual=Structures.new();actual.origin=Vector3(floorf(p.x/256)*256,0,floorf(p.y/256)*256);actual.nest_construction_profiles=enabled;var expected=(Candidate if enabled else original).new();expected.origin=actual.origin;var vent:float=12 if kind in [0,3,5] else 0
				for g in [actual,expected]:g.mound(b,anchor,42,120,kind,descriptor.angle,Color(.44,.27,.14),vent,kind==3)
				check(var_to_bytes(arrays(actual))==var_to_bytes(arrays(expected)),"Complete registered primitive equals frozen original/private accepted profile");records.append({"seed":seed_id,"kind":kind,"enabled":enabled,"vertices":actual.vertices.size()})
		# Original fixed geographic root per seed,without searching/rerolling.
		b.chunk_size=2048;var coordinate:=Vector2i(floori(p.x/2048),floori(p.y/2048));var prior:Array=[]
		for enabled:bool in [false,true,false]:
			b.settings.insect_colony.nest_construction_profiles=enabled;var before:int=Time.get_ticks_usec();var actual:Array=Lod.new().build(b,coordinate);var usec:int=Time.get_ticks_usec()-before;var expected:Array=(Candidate if enabled else original).new().build(b,coordinate);check(var_to_bytes(actual)==var_to_bytes(expected),"Complete actual configured whole root equals frozen/accepted reference")
			if prior.is_empty():prior=actual
			elif not enabled:check(var_to_bytes(actual)==var_to_bytes(prior),"Saved false restores every complete original array")
			stages.append({"seed":seed_id,"enabled":enabled,"root":str(coordinate),"ordered_worker_usec":usec,"positive_vertices":actual[1][Mesh.ARRAY_VERTEX].size() if actual[1]!=null else 0})
	for family:int in [5,7]:
		var b=make_builder(family,17);b.chunk_size=2048;var actual:Array=Lod.new().build(b,Vector2i(-10,-10));var expected:Array=original.new().build(b,Vector2i(-10,-10));check(var_to_bytes(actual)==var_to_bytes(expected),"Unrelated complete Crystal/Alien geometry remains exact")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable registration source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_profile_registration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"primitive_cases":records,"whole_root_stages":stages,"scope":"Registered default-on independent nest_construction_profiles.36complete three-seed/six-archetype/off-on primitive comparisons versus frozen original and private accepted profile;three fixed whole-root off/on/off triplets and unrelated complete Crystal/Alien controls. Direct primitives retain original unless explicitly enabled. Original footers/elevations/summits/vents/domes preserved by accepted shape controls. Ordered worker observations not isolated benchmark;full registered native rendering/collision and broad artistic acceptance separate."},"  "));print("INSECT_PROFILE_REGISTRATION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
