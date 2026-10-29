extends "res://tools/biome_extensions/check_all.gd"
const References=preload("res://tools/biome_extensions/crystal_root_references.gd")
func digest(value)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(value));return h.finish().hex_encode()
func run()->void:
	var admission_path:String=References.ROOT+"tools/biome_extensions/artifacts/check_grounded_earth_crystal_candidate.json.txt";var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));assert(admission.passed)
	var guards:Dictionary={admission_path:FileAccess.get_sha256(admission_path)}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/check_all.gd","res://tools/biome_extensions/profile_crystal_grounded_roots.gd"]:guards[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var ratios:Array=[]
	for round_id in range(3):
		for site:Dictionary in admission.cases:
			if int(site.family)!=5:continue
			var records:Dictionary={}
			for enabled:bool in ([false,true] if round_id%2==0 else [true,false]):
				var b=make_builder(5,int(site.seed));b.settings.crystal_wastes.crystal_grounded_roots=enabled;var field=b._extras[5];var parts:PackedStringArray=site.root.trim_prefix("(").trim_suffix(")").split(",");var approximate:=Vector2(float(parts[0]),float(parts[1]));var descriptor:Dictionary=field.descriptor(Vector2i(floori(approximate.x/1700),floori(approximate.y/1700)),1700);var p:Vector2=descriptor.position;var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256));b.chunk_size=256
				var output:Dictionary={};var task:int=WorkerThreadPool.add_task(func()->void:
					var start:int=Time.get_ticks_usec();var arrays:Array=b.build(coordinate,128);var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=mesher.build(b,coordinate);var structures:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate,Structures.support_grids(),mesher.portal_sites)
					var collision:Dictionary=preload("res://scripts/terrain_collision.gd").prepare(arrays,128,true,structures,features);var water:Array=b.build_swamp_water(arrays,128);output.seconds=(Time.get_ticks_usec()-start)/1000000.0
					output.nonstructure=digest([arrays,features,water,b.built_extension_data,b.built_extension_rows,b.built_extension_mask]);var faces:PackedVector3Array=collision.structure_faces;collision.erase("structure_faces");output.other_collision=digest(collision);output.structures=digest(structures)
					var expected:=PackedVector3Array()
					for surface in structures:
						if surface!=null and not surface.is_empty():expected.append_array(surface[Mesh.ARRAY_VERTEX])
					output.collision_matches=faces==expected;output.structure_vertices=expected.size();output.coordinate=str(coordinate)
				)
				WorkerThreadPool.wait_for_task_completion(task);check(output.collision_matches,"Actual worker collider faces equal changed geometry");records[enabled]=output
			check(records[false].nonstructure==records[true].nonstructure and records[false].other_collision==records[true].other_collision,"All unrelated complete terrain/water/features/control/collision payloads exact")
			check(records[false].structures!=records[true].structures and records[false].structure_vertices==records[true].structure_vertices and records[true].structure_vertices>0,"Actual root changes with unchanged topology")
			var ratio:float=records[true].seconds/records[false].seconds;ratios.append(ratio);cases.append({"round":round_id,"seed":site.seed,"root":records[false].coordinate,"resolution":128,"off_seconds":records[false].seconds,"on_seconds":records[true].seconds,"on_off_ratio":ratio,"vertices":records[true].structure_vertices})
	ratios.sort()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable registered worker profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_crystal_grounded_roots.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"median_on_off_ratio":ratios[ratios.size()/2],"scope":"REGISTERED real cold terrain builder/full numeric feature/structure/collision/water pipeline on actual WorkerThreadPool tasks,three frozen dry native-eligible roots,three alternating rounds/nine pairs,256m128resolution. Timing excludes builder/config creation and result hashing;includes full build/support work. Not concurrent four-worker cut latency,uncapped GPU performance or universal gain. Complete unrelated payloads exact,changed collider positions correspond to real structures,no added triangles."},"  "))
	print("CRYSTAL_ROOT_WORKER_PROFILE ",checks," median=",ratios[ratios.size()/2]," failures=",failures);quit(0 if failures.is_empty() else 1)
