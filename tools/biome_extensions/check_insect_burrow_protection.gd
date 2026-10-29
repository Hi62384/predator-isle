extends "res://tools/biome_extensions/check_insect_domes.gd"
const DISCOVERY="res://tools/biome_extensions/artifacts/revisions/experiment_find_insect_burrow_conflicts_wide_24a12b15e1b3/evidence/tools/biome_extensions/artifacts/find_insect_burrow_conflicts_wide.json"
class Counter:
	extends RefCounted
	var calls:int=0
	func sites(_bounds:Rect2)->Array:calls+=1;return []
func run()->void:
	var hashes:Dictionary={}
	for path:String in [DISCOVERY,"res://tools/biome_extensions/check_insect_burrow_protection.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/insect_colony_sampler.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var discovery=JSON.parse_string(FileAccess.get_file_as_string(DISCOVERY));check(discovery.passed and discovery.candidates.size()==2,"Frozen real overlap candidates")
	var records:Array=[]
	for site:Dictionary in discovery.candidates:
		var b=make_builder(6,int(site.seed));var p:=Vector2(site.mound_position[0],site.mound_position[1]);var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
		var cell:=Vector2i(floori(p.x/256),floori(p.y/256));var protected_mesh:Array=Structures.new().build(b,cell,PackedFloat64Array(),guard.portal_sites)
		check(protected_mesh[1]==null,"Whole obstructing primary/satellite complex excluded at its unchanged root")
		b.settings.insect_colony.nest_protect_burrows=false
		var legacy:Array=Structures.new().build(b,cell,PackedFloat64Array(),guard.portal_sites)
		check(legacy[1]!=null and legacy[1][Mesh.ARRAY_VERTEX].size()==site.structure_vertices,"Explicit disabled mode restores the exact obstructing vertex count")
		check(legacy==Structures.new().build(b,cell),"Unprotected complete arrays are unchanged by supplying the provider")
		b.settings.insect_colony.nest_protect_burrows=true;b.chunk_size=512
		var parent_cell:=Vector2i(floori(p.x/512),floori(p.y/512));var parent:Array=Structures.new().build(b,parent_cell,PackedFloat64Array(),guard.portal_sites)
		var expected:Array[String]=world_vertices(parent,Vector3(parent_cell.x*512,0,parent_cell.y*512));var children:Array[String]=[]
		b.chunk_size=256
		for z in range(2):
			for x in range(2):
				var child:Vector2i=parent_cell*2+Vector2i(x,z);children.append_array(world_vertices(Structures.new().build(b,child,PackedFloat64Array(),guard.portal_sites),Vector3(child.x*256,0,child.y*256)))
		expected.sort();children.sort();check(expected==children,"Protection is independent of parent/four-child root ownership")
		var counter:=Counter.new();var no_sites:Array=Structures.new().build(b,cell,PackedFloat64Array(),counter.sites)
		check(counter.calls==1 and no_sites==legacy,"At most one current-policy query and exact full geometry when no entrances exist")
		var field=b._extras[6];var descriptor:Dictionary=field.descriptor(Vector2i(site.mound_id.split(":")[1].to_int(),site.mound_id.split(":")[2].to_int()),2100)
		var scale:float=field.settings.nest_height*(.45+descriptor.age);var clearance:float=scale*.8+320
		for offset:float in [-.5,.5]:
			var artificial:Vector2=p+Vector2(clearance+offset,0);var actual:Array=Structures.new().build(b,cell,PackedFloat64Array(),reserved.bind(artificial))
			check((actual[1]==null)==(offset<0),"Conservative whole-complex clearance boundary, without moving the real portal")
		records.append({"seed":site.seed,"portal_id":site.portal_id,"mound_id":site.mound_id,"legacy_vertices":legacy[1][Mesh.ARRAY_VERTEX].size(),"protected_vertices":0,"default_cave_frequency":field.settings.cave_frequency})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable burrow-protection source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_burrow_protection.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"records":records,"source_sha256":hashes,"production_registration":true,"scope":"Two frozen real default-rarity overlap sites verify whole primary/satellite exclusion with unchanged root/portal identity, independent unsafe-placement mode, exact full unprotected arrays, stable parent/child ownership, actual one-query budget, empty-site equality and clearance-boundary controls. Fixed-site capsule returns and actual streamed worker proof remain separate. No terrain/cave engine/route or capsule changes."},"  "))
	print("INSECT_BURROW_PROTECTION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
