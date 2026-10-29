extends "res://tools/biome_extensions/check_integration.gd"
const BeforeCarapace=preload("res://tools/biome_extensions/reference_pre_carapace_structures.gd")
func protected_at(_bounds:Rect2,p:Vector2)->Array:return [{"position":p,"half":96.0}]
func locate(b,habit:int)->Dictionary:
	var field=b._extras[7];var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
	for z in range(-32,33):
		for x in range(-32,33):
			var cell:=Vector2i(x,z);var d:Dictionary=field.descriptor(cell,4096*field.settings.feature_scale)
			if d.chance>field.settings.structure_density or field.random(x,z,247)>=field.settings.hive_carapace_frequency:continue
			if field.random(x,z,246)<field.settings.hive_junction_frequency:continue
			var p:Vector2=field.hive_node(cell)
			if roundi(field.region(p))!=habit:continue
			var width:float=field.settings.hive_carapace_width*field.settings.feature_scale*(.75+d.age*.5)
			var height:float=field.settings.hive_carapace_height*(.7+d.age*.6)*field.settings.relief*maxf(b.settings.height_multiplier,.01)
			var g=Structures.new();g._protected_sites=guard.portal_sites(Rect2(p-Vector2.ONE*(width*2+512),Vector2.ONE*(width*4+1024)))
			if not g.can_place_carapace(b,p,width,height):continue
			return {"cell":cell,"position":p,"width":width,"height":height,"habit":habit,"ground":b._get_height(p.x,p.y)}
	return {}
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_feature_meshes.gd","res://tools/biome_extensions/reference_pre_carapace_structures.gd","res://tools/biome_extensions/check_carapace_admission.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for habit:int in [2,5]:
			var b=make_builder(7,seed_id);var site:Dictionary=locate(b,habit);check(not site.is_empty(),"Actual dry default-rarity plate site "+str([seed_id,habit]))
			if site.is_empty():continue
			var p:Vector2=site.position;b.chunk_size=256;var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256))
			var enabled:Array=build_structures(b,coordinate);b.settings.alien_infected.hive_carapace_frequency=0
			var disabled:Array=build_structures(b,coordinate)
			check(enabled[2]!=null and disabled[2]!=null,"Actual network and plate output")
			if enabled[2]==null or disabled[2]==null:continue
			check(enabled[2][Mesh.ARRAY_VERTEX].size()-disabled[2][Mesh.ARRAY_VERTEX].size()==18000,"Exactly one complete three-plate addition")
			var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
			check(disabled==BeforeCarapace.new().build(b,coordinate,PackedFloat64Array(),guard.portal_sites),"Zero frequency preserves every previous structure array")
			b.settings.alien_infected.hive_carapace_frequency=.18
			var provider:Callable=protected_at.bind(p);var protected:Array=Structures.new().build(b,coordinate,PackedFloat64Array(),provider)
			b.settings.alien_infected.hive_carapace_frequency=0
			check(protected==Structures.new().build(b,coordinate,PackedFloat64Array(),provider),"Reserved finite-cavity approach suppresses the entire plate complex")
			b.settings.alien_infected.hive_carapace_frequency=.18;b.chunk_size=4096;var parent_cell:=Vector2i(floori(p.x/4096),floori(p.y/4096))
			var parent:Array=build_structures(b,parent_cell);var expected:Array[String]=world_vertices(parent,Vector3(parent_cell.x*4096,0,parent_cell.y*4096));var children:Array[String]=[]
			b.chunk_size=2048
			for dz in range(2):
				for dx in range(2):
					var child:Vector2i=parent_cell*2+Vector2i(dx,dz);children.append_array(world_vertices(build_structures(b,child),Vector3(child.x*2048,0,child.y*2048)))
			expected.sort();children.sort();check(expected==children,"Exactly one stable plate/network owner across LOD")
			cases.append({"seed":seed_id,"habit":habit,"position":[p.x,p.y],"width":site.width,"height":site.height,"ground":site.ground,"additional_vertices":18000})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable admission source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_carapace_admission.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Six actual default-rarity hardened/dormant hive-node sites over three seeds, dry/low-relief nine-point admission, current finite-cavity guards, complete zero-frequency preservation, forced reserved-site exclusion and exact parent/four-child ownership. Nine placement probes are not a whole-footprint hydrological certificate."},"  "))
	print("CARAPACE_ADMISSION ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
