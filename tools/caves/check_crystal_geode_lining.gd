extends "res://tools/caves/check_crystal_world_cohort.gd"
const OLD:String="res://tools/biome_extensions/artifacts/revisions/experiment_check_cave_crystal_vein_domains_ab86cb4d4e9a/sources/scripts/caves/crystal_features.gd.txt"
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();guards[OLD]=FileAccess.get_sha256(OLD);check(guards[OLD]=="e9bab257814d0dce3bc48f8c2aae00e57107908898bb3c54f4c1c965209204d2","Exact frozen embedded-vein/pre-lining source,not regenerated control")
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_world_cohort.gd","res://tools/caves/check_frozen_world_cohort.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var legacy:=GDScript.new();legacy.source_code=FileAccess.get_file_as_string(OLD);check(legacy.reload()==OK,"Frozen previous generator compiles independently")
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");check(definition.validation_errors().is_empty(),"Independent editable geode-lining switch validates");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var b=owner("crystal_wastes",73921);var work=Workload.new();var configured:bool=work.configure(b.settings,config,73921,0);var records:Array=[]
		for target:Dictionary in [{"profile":"geode","site":Vector2i(6,-2),"id":"6:-2:2:0:crystal:geode:1"},{"profile":"ravine","site":Vector2i(8,-4),"id":"8:-4:2:2:crystal:ravine:0"}]:
			var bundle:Dictionary=work.discover(target.site);var room:Dictionary={}
			for region:Dictionary in bundle.get("regions",[]):
				for candidate:Dictionary in region.get("pockets",[]):
					if candidate.id==target.id:room=candidate
			var record:Dictionary={"profile":target.profile,"configured":configured,"found":not room.is_empty(),"cells":0,"legacy_off_mismatches":0,"cold_mismatches":0,"old_crystals":0,"dense_crystals":0,"lining_patches":0,"maximum_cell_lining":0,"maximum_base_forms":0,"maximum_vertices":0,"invalid_roots":0,"invalid_owners":0,"invalid_triangles":0,"blocked_routes":0,"collision_count_mismatches":0,"unexpected_lining_colliders":0,"invalid_payloads":0}
			if not room.is_empty():
				var center:Vector3i=work.field.cell(room.point+Vector3.UP*2);var off:Dictionary=definition.feature_configuration.duplicate();off.geode_lining=false;off.spanning_crystals=false;off.crystal_debris=false;off.localized_veins=false;off.corridor_growth=false;off.luminous_minerals=false;off.shallow_chambers=false;off.lake_chambers=false
				for dz in range(-1,2):
					for dy in range(-1,2):
						for dx in range(-1,2):
							var key:Vector3i=center+Vector3i(dx,dy,dz);var frozen:Dictionary=legacy.new().build(work.field,key,73921,bundle.regions,off,{});var previous:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,off,{});var current:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,definition.feature_configuration,{});var repeated:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,definition.feature_configuration,{});record.cells+=1;record.legacy_off_mismatches+=int(var_to_bytes(frozen)!=var_to_bytes(previous));record.cold_mismatches+=int(var_to_bytes(current)!=var_to_bytes(repeated));record.invalid_payloads+=int(not current.valid)
							for placement:Dictionary in previous.placements:record.old_crystals+=int(placement.kind=="crystal")
							var linings:int=0;var forms:int=0;var expected_collision:int=0;var actual_collision:int=0;var vertices:int=0
							for placement:Dictionary in current.placements:
								record.dense_crystals+=int(placement.kind=="crystal")
								if placement.kind=="crystal_lining":linings+=1;record.unexpected_lining_colliders+=int(placement.collider)
								else:forms+=1
								if placement.collider:expected_collision+=placement.vertex_count
								record.invalid_owners+=int(placement.owner!=key or work.field.cell(placement.root)!=key)
								for contact:Vector3 in placement.attachments:record.invalid_roots+=int(work.field.sample(contact)<.15)
								var bounds:AABB=placement.bounds;record.blocked_routes+=int(Crystal.new().shapes.protected(work.field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,bounds.position.y,bounds.end.y))
							for batch:Dictionary in current.batches:
								var points:PackedVector3Array=batch.arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=batch.arrays[Mesh.ARRAY_NORMAL];vertices+=points.size();actual_collision+=batch.collision_faces.size()
								for index in range(0,points.size(),3):record.invalid_triangles+=int((points[index+2]-points[index]).cross(points[index+1]-points[index]).length_squared()==0 or not normals[index].is_finite() or absf(normals[index].length()-1)>.001)
							record.collision_count_mismatches+=int(actual_collision!=expected_collision);record.lining_patches+=linings;record.maximum_cell_lining=maxi(record.maximum_cell_lining,linings);record.maximum_base_forms=maxi(record.maximum_base_forms,forms);record.maximum_vertices=maxi(record.maximum_vertices,vertices)
			records.append(record)
		output.append(records)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var records:Array=output[0] if not output.is_empty() else [];check(records.size()==2,"Both original first normal profile neighborhoods retained")
	for record:Dictionary in records:
		check(record.configured and record.found and record.cells==27,"All original27cells and stable profile identities retained")
		check(record.legacy_off_mismatches==0,"Lining,spanning,debris,vein localization AND corridor growth OFF return COMPLETE frozen pre-lining payloads byte-for-byte")
		check(record.cold_mismatches==0 and record.invalid_payloads==0,"Whole dense geometry/roots/materials/LODs/metadata cold-repeat deterministic")
		check(record.maximum_base_forms<=160 and record.maximum_cell_lining<=32 and record.maximum_vertices<=60000,"Original160base forms plus separately bounded32noncolliding lining patches remain inside unchanged60000vertex ceiling")
		check(record.invalid_roots==0 and record.invalid_owners==0 and record.invalid_triangles==0 and record.blocked_routes==0,"Complete dense and mantle geometry has measured buried roots,one owner,finite real hard facets and unchanged entire route clearance")
		check(record.collision_count_mismatches==0 and record.unexpected_lining_colliders==0,"Only actual large crystal forms create colliders;shallow wall mantles never create invisible walking obstacles")
		if record.profile=="geode":check(record.dense_crystals>=record.old_crystals*2 and record.lining_patches>=10,"FIRST actual normal geode has positive substantially denser real crystals AND attached faceted mineral bases,not recolored empty stone")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable dense lining source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_geode_lining.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"scope":"FIRST original normal geode/ravine54cells,192geode patch proposal sectors with unchanged.65density and old chance/graph. Real crystal geometry plus separately bounded32attached noncolliding faceted mantle patches per cell,in existing opaque batch. Original160base forms/60000vertices retained;extra patch metadata bound explicit. Complete measured roots/ownership/protected routes/triangles/collider accounting/cold repeat and exact frozen lining-OFF payloads. Not native imagery/full live motion/FPS/normal large-lake occurrence/reference-art/all-user completion."},"  "));print("CRYSTAL_GEODE_LINING ",checks," records=",records," failures=",failures);quit(0 if failures.is_empty() else 1)
