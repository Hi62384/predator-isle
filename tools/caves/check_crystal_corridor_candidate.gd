extends "res://tools/caves/check_crystal_world_cohort.gd"
const Candidate=preload("res://tools/caves/crystal_corridor_candidate.gd")
const Previous:String="res://tools/biome_extensions/artifacts/revisions/experiment_render_cave_crystal_indexed_family_2_c62a0e2a8836/sources/scripts/caves/crystal_features.gd.txt"
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/crystal_corridor_candidate.gd","res://tools/caves/check_crystal_world_cohort.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	guards[Previous]=FileAccess.get_sha256(Previous);var previous:=GDScript.new();previous.source_code=FileAccess.get_file_as_string(Previous);check(previous.reload()==OK,"Independent frozen pre-corridor production generator compiles");check(FileAccess.get_sha256("res://scripts/caves/crystal_corridor_features.gd")==FileAccess.get_sha256("res://tools/caves/crystal_corridor_candidate.gd"),"Adopted worker module is the exact tested numeric candidate")
	var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var baseline:Dictionary=definition.feature_configuration.duplicate();baseline.corridor_growth=false;baseline.luminous_minerals=false;baseline.shallow_chambers=false;baseline.lake_chambers=false;var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var records:Array=[]
		for target:Dictionary in [{"host":"crystal_wastes","site":Vector2i(6,-2),"id":"6:-2:2:0:crystal:geode:1"},{"host":"crystal_wastes","site":Vector2i(8,-4),"id":"8:-4:2:2:crystal:ravine:0"},{"host":"quarry","site":Vector2i(8,-4),"id":"8:-4:2:0:lobe:0"}]:
			var b=owner(target.host,73921);var work=Workload.new();work.configure(b.settings,config,73921,0);var bundle:Dictionary=work.discover(target.site);var room:Dictionary={}
			for region:Dictionary in bundle.get("regions",[]):
				for item:Dictionary in region.get("pockets",[]):
					if item.id==target.id:room=item
			var record:Dictionary={"host":target.host,"site":str(target.site),"room":target.id,"found":not room.is_empty(),"cells":0,"new_forms":0,"off_mismatches":0,"frozen_off_mismatches":0,"production_geometry_mismatches":0,"lost_old_placements":0,"invalid_roots":0,"invalid_routes":0,"invalid_owner":0,"invalid_bounds":0,"cold_mismatches":0,"samples":[]}
			if not room.is_empty():
				var center:Vector3i=work.field.cell(room.point+Vector3.UP*2)
				for dz in range(-1,2):
					for dy in range(-1,2):
						for dx in range(-1,2):
							var key:Vector3i=center+Vector3i(dx,dy,dz);var generator=Crystal.new();var disabled:Dictionary=generator.build(work.field,key,73921,bundle.regions,baseline,{});record.frozen_off_mismatches+=int(var_to_bytes(disabled)!=var_to_bytes(previous.new().build(work.field,key,73921,bundle.regions,baseline,{})));var original:PackedByteArray=var_to_bytes({"batches":generator.batches,"placements":generator.placements,"rejections":generator.rejections});var old_placements:Array=generator.placements.duplicate(true);var off:Dictionary=baseline.duplicate();Candidate.append(generator,work.field,bundle.regions,73921,off);record.off_mismatches+=int(original!=var_to_bytes({"batches":generator.batches,"placements":generator.placements,"rejections":generator.rejections}));var on:Dictionary=off.duplicate();on.corridor_growth=true;var count:int=Candidate.append(generator,work.field,bundle.regions,73921,on);record.new_forms+=count;record.cells+=1
							var production:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,on,{});record.production_geometry_mismatches+=int(var_to_bytes(production.placements)!=var_to_bytes(generator.placements) or not production.valid)
							for batch:Dictionary in production.batches:
								var expected:Dictionary=generator.batches[batch.kind];var actual:Array=batch.arrays;record.production_geometry_mismatches+=int(var_to_bytes([actual[Mesh.ARRAY_VERTEX],actual[Mesh.ARRAY_NORMAL],actual[Mesh.ARRAY_COLOR],actual[Mesh.ARRAY_TEX_UV],actual[Mesh.ARRAY_TEX_UV2],batch.collision_faces])!=var_to_bytes([expected.vertices,expected.normals,expected.colors,expected.uvs,expected.growth_uvs,expected.collision_faces]))
							for index in range(old_placements.size()):record.lost_old_placements+=int(var_to_bytes(old_placements[index])!=var_to_bytes(generator.placements[index]))
							for item:Dictionary in generator.placements:
								if not item.get("corridor_crystal",false):continue
								var bounds:AABB=item.bounds;record.invalid_owner+=int(item.owner!=key or work.field.cell(item.root)!=key);record.invalid_routes+=int(generator.shapes.protected(work.field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,bounds.position.y,bounds.end.y))
								for foot:Vector3 in item.attachments:record.invalid_roots+=int(work.field.sample(foot)<.15)
								if record.samples.size()<4:record.samples.append({"id":item.id,"root":item.root,"height":item.height,"family":item.family,"theme":item.region_theme})
							var vertices:int=0
							for batch:Dictionary in generator.batches.values():vertices+=batch.vertices.size()
							record.invalid_bounds+=int(count>24 or vertices>60000);var repeated=Crystal.new();repeated.build(work.field,key,73921,bundle.regions,baseline,{});Candidate.append(repeated,work.field,bundle.regions,73921,on);record.cold_mismatches+=int(var_to_bytes({"batches":repeated.batches,"placements":repeated.placements})!=var_to_bytes({"batches":generator.batches,"placements":generator.placements}))
			records.append(record)
		output.append(records)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var records:Array=output[0] if not output.is_empty() else [];var count:int=0;check(records.size()==3,"All three predeclared original normal room neighborhoods retained")
	for record:Dictionary in records:
		check(record.found and record.cells==27,"All original81cells checked without site substitution");check(record.off_mismatches==0 and record.lost_old_placements==0 and record.cold_mismatches==0,"Independent corridor OFF exact,no earlier major/minor placement displaced,and cold-repeat payload exact");check(record.invalid_roots==0 and record.invalid_routes==0 and record.invalid_owner==0 and record.invalid_bounds==0,"Actual measured corridor minerals retain whole buried roots,original FULL passage exclusion,one owner and unchanged numeric limits");count+=record.new_forms
		check(record.frozen_off_mismatches==0 and record.production_geometry_mismatches==0,"Complete frozen OFF production payloads exact,and adopted ON vertices/normals/colors/UVs/native collision/placements match tested candidate exactly")
	check(count>0,"Real original normal corridor joins support positive additional3Dmineral growth,not only shader or room labels")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private corridor candidate "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_corridor_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"forms":count,"records":records,"scope":"PRIVATE numeric candidate in original81normal cells across first geode/ravine/Quarry lobe. Existing graph/implicit field untouched,no new widened cave volume. Only actual measured wide corridor joins can accept forms OUTSIDE original whole8x8m protected passage+margin. Exact earlier placements/off/cold returns,24subcap inside existing160form/60000vertex bounds;normal narrow tunnels correctly may be negative. Not adoption/native imagery/traversal/FPS/all-user completion."},"  "));print("CRYSTAL_CORRIDOR_CANDIDATE ",checks," forms=",count," records=",records," failures=",failures);quit(0 if failures.is_empty() else 1)
