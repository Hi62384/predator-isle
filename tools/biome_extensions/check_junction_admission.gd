extends "res://tools/biome_extensions/check_integration.gd"
const BeforeJunctions=preload("res://tools/biome_extensions/reference_pre_junction_structures.gd")
func locate(b)->Dictionary:
	var field=b._extras[7]
	for z in range(-24,25):
		for x in range(-24,25):
			var cell:=Vector2i(x,z);var d:Dictionary=field.descriptor(cell,4096*field.settings.feature_scale)
			if d.chance>field.settings.structure_density or field.random(x,z,246)>=field.settings.hive_junction_frequency:continue
			var p:Vector2=field.hive_node(cell)
			if b._island_mask(p.x,p.y)<.1:continue
			var h:float=b._get_height(p.x,p.y)
			if h<=maxf(b.water_level,b.get_water_surface_height(p.x,p.y))+2:continue
			return {"cell":cell,"position":p,"ground":h,"height":field.settings.hive_junction_height*(.65+d.age*.7)*field.settings.relief*maxf(b.settings.height_multiplier,.01),"width":field.settings.hive_junction_width*field.settings.feature_scale}
	return {}
func guarded_sites(_bounds:Rect2,p:Vector2)->Array:return [{"position":p,"half":96.0}]
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/reference_pre_junction_structures.gd","res://tools/biome_extensions/check_junction_admission.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(7,seed_id);b.settings.alien_infected.caves_enabled=false;b.settings.alien_infected.hive_carapace_frequency=0;b._configure_noise()
		var site:Dictionary=locate(b);check(not site.is_empty(),"Real dry junction under default rarity/settings")
		if site.is_empty():continue
		var p:Vector2=site.position;b.chunk_size=256;var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256))
		var actual:Array=build_structures(b,coordinate)
		b.settings.alien_infected.hive_junction_frequency=0
		var old:Array=build_structures(b,coordinate)
		# The separate shoulder correction intentionally changes old conduits.
		# Its reference switch isolates the original pre-junction baseline.
		var legacy=Structures.new();legacy.conduit_shoulders=false
		check(legacy.build(b,coordinate)==BeforeJunctions.new().build(b,coordinate),"Legacy shoulder switch preserves every pre-junction array")
		b.settings.alien_infected.hive_junction_frequency=.12
		check(actual[2]!=null and old[2]!=null,"Actual admitted organic network")
		if actual[2]==null or old[2]==null:continue
		var extra_vertices:int=actual[2][Mesh.ARRAY_VERTEX].size()-old[2][Mesh.ARRAY_VERTEX].size()
		var membrane_chance:float=b._extras[7].random(site.cell.x,site.cell.y,248);var membrane_present:bool=membrane_chance<b.settings.alien_infected.hive_membrane_frequency
		check(extra_vertices==9168+(5136 if membrane_present else 0),"Exactly one complete junction and independently admitted closed membrane")
		b.settings.alien_infected.hive_junction_frequency=0
		check(build_structures(b,coordinate)==old,"Zero rarity restores every current network-only structure array")
		b.settings.alien_infected.hive_junction_frequency=.12
		var provider:Callable=guarded_sites.bind(p)
		var protected:Array=Structures.new().build(b,coordinate,PackedFloat64Array(),provider)
		b.settings.alien_infected.hive_junction_frequency=0
		var protected_disabled:Array=Structures.new().build(b,coordinate,PackedFloat64Array(),provider)
		check(protected==protected_disabled,"Reserved portal/spiral/gallery suppresses the complete junction")
		b.settings.alien_infected.hive_junction_frequency=.12
		b.chunk_size=4096;var parent_cell:=Vector2i(floori(p.x/4096),floori(p.y/4096))
		var parent:Array=build_structures(b,parent_cell);var expected:Array[String]=world_vertices(parent,Vector3(parent_cell.x*4096,0,parent_cell.y*4096));var children:Array[String]=[]
		b.chunk_size=2048
		for dz in range(2):
			for dx in range(2):
				var child:Vector2i=parent_cell*2+Vector2i(dx,dz);children.append_array(world_vertices(build_structures(b,child),Vector3(child.x*2048,0,child.y*2048)))
		expected.sort();children.sort();check(expected==children,"Exactly one stable junction/network owner across parent/four children")
		cases.append({"seed":seed_id,"position":[p.x,p.y],"cell":str(site.cell),"ground":site.ground,"junction_height":site.height,"width":site.width,"additional_vertices":extra_vertices,"membrane_present":membrane_present,"membrane_chance":membrane_chance})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_junction_admission.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Three actually admitted dry network intersections at default rarity; complete zero-rarity equality, reserved-portal suppression and stable parent/four-child world geometry. Cavities disabled only for the default-site locator; reserved-site exclusion is separately forced."},"  "))
	print("JUNCTION_ADMISSION ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
