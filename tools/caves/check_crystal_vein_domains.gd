extends "res://tools/caves/check_crystal_world_cohort.gd"
const OLD:String="res://tools/biome_extensions/artifacts/revisions/experiment_check_cave_crystal_features_03f675ef45ee/sources/scripts/caves/crystal_features.gd.txt"
func digest(value)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(value));return hash.finish().hex_encode()
func own_error(field,room:Dictionary,point:Vector3)->float:
	var error:float=4.0
	for feature:int in field.bins.get(field.bin_cell(point),PackedInt32Array()):
		if field.kinds[feature]!=2 or field.begins[feature]!=room.point:continue
		error=minf(error,absf(field.evaluate(point,PackedInt32Array([feature]))))
	return error
func contacts(generator,field,room:Dictionary,placement:Dictionary)->Array:
	if placement.has("surface_contacts"):return Array(placement.surface_contacts)
	var pieces:PackedStringArray=str(placement.id).split("/");var band:int=int(pieces[-2]);var segment:int=int(pieces[-1]);var a:float=segment*TAU/32;var b:float=(segment+1)*TAU/32;var wa:float=.12+.3*pow(.5+.5*sin(a*7+room.point.x*.03),2);var wb:float=.12+.3*pow(.5+.5*sin(b*7+room.point.x*.03),2)
	return [generator.vein_contact(field,room,a,band,-wa),generator.vein_contact(field,room,b,band,-wb),generator.vein_contact(field,room,b,band,wb),generator.vein_contact(field,room,a,band,wa)]
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();guards[OLD]=FileAccess.get_sha256(OLD);check(guards[OLD]=="64e6e4d91a49b7a3c792cac2a087314054d1685bb7df8f93f4221163fef34b9b","Exact independently frozen original vein generator,not a regenerated control")
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_world_cohort.gd","res://tools/caves/check_frozen_world_cohort.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var legacy:=GDScript.new();legacy.source_code=FileAccess.get_file_as_string(OLD);check(legacy.reload()==OK,"Frozen original numeric mineral generator compiles independently")
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var b=owner("crystal_wastes",73921);var work=Workload.new();var configured:bool=work.configure(b.settings,config,73921,0);var records:Array=[]
		for target:Dictionary in [{"profile":"geode","site":Vector2i(6,-2),"id":"6:-2:2:0:crystal:geode:1"},{"profile":"ravine","site":Vector2i(8,-4),"id":"8:-4:2:2:crystal:ravine:0"}]:
			var bundle:Dictionary=work.discover(target.site);var room:Dictionary={};var rooms:Dictionary={}
			for region:Dictionary in bundle.get("regions",[]):
				for candidate:Dictionary in region.nodes+region.get("pockets",[]):rooms[str(candidate.id)]=candidate
			room=rooms.get(target.id,{});var record:Dictionary={"profile":target.profile,"configured":configured,"room_found":not room.is_empty(),"old_veins":0,"old_foreign_wall_contacts":0,"new_veins":0,"new_foreign_wall_contacts":0,"new_maximum_protrusion":0.0,"crystal_batch_mismatches":0,"native_collision_mismatches":0,"cells":0}
			if not room.is_empty():
				var center:Vector3i=work.field.cell(room.point+Vector3.UP*2)
				for dz in range(-1,2):
					for dy in range(-1,2):
						for dx in range(-1,2):
							var key:Vector3i=center+Vector3i(dx,dy,dz);var old_generator=legacy.new();var current_generator=Crystal.new();var original:Dictionary=old_generator.build(work.field,key,73921,bundle.regions,definition.feature_configuration,{});var current:Dictionary=current_generator.build(work.field,key,73921,bundle.regions,definition.feature_configuration,{});var old_batches:Dictionary={};var new_batches:Dictionary={};var old_collision:Dictionary={};var new_collision:Dictionary={};record.cells+=1
							for batch:Dictionary in original.batches:
								if batch.kind!="mineral_bed":old_batches[batch.kind]=digest(batch);old_collision[batch.kind]=digest(batch.collision_faces)
							for batch:Dictionary in current.batches:
								if batch.kind!="mineral_bed":new_batches[batch.kind]=digest(batch);new_collision[batch.kind]=digest(batch.collision_faces)
							record.crystal_batch_mismatches+=int(var_to_bytes(old_batches)!=var_to_bytes(new_batches));record.native_collision_mismatches+=int(var_to_bytes(old_collision)!=var_to_bytes(new_collision))
							for mode:int in [0,1]:
								var payload:Dictionary=original if mode==0 else current;var generator=old_generator if mode==0 else current_generator
								for placement:Dictionary in payload.placements:
									if placement.kind!="mineral_vein":continue
									var label:String="old" if mode==0 else "new";record[label+"_veins"]+=1;var source_id:String=str(placement.id).split("/vein/")[0];var host:Dictionary=rooms[source_id]
									for point:Vector3 in contacts(generator,work.field,host,placement):record[label+"_foreign_wall_contacts"]+=int(not point.is_finite() or own_error(work.field,host,point)>.25)
									if mode==1:record.new_maximum_protrusion=maxf(record.new_maximum_protrusion,placement.width)
			records.append(record)
		output.append(records)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var records:Array=output[0] if not output.is_empty() else [];check(records.size()==2,"Both original first-profile27cell neighborhoods retained")
	var old_foreign:int=0;var new_veins:int=0
	for record:Dictionary in records:
		check(record.configured and record.room_found and record.cells==27,"Original normal selected profile and every neighborhood cell retained");old_foreign+=record.old_foreign_wall_contacts;new_veins+=record.new_veins
		check(record.new_foreign_wall_contacts==0,"Every final physical mineral vein contact belongs to its ACTUAL generating chamber wall")
		check(record.new_maximum_protrusion<=.080001,"Embedded mineral beds protrude at most8cm,not45cm continuous shelves")
		check(record.crystal_batch_mismatches==0 and record.native_collision_mismatches==0,"All crystal arrays/material flags/LOD/colliders remain byte-exact;ONLY noncolliding mineral-bed geometry changes")
	check(old_foreign>0 and new_veins>0,"Positive old foreign-wall defect and positive retained true-host veins,not deleting every mineral bed")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual host-domain source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_vein_domains.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"scope":"FIRST original normal geode/ravine54cell field neighborhoods against exact independently frozen generator. Per-contact ownership on the original generating chamber primitive;thin embedded noncolliding mineral beds,positive old foreign-wall control and retained real beds. Entire non-bed arrays/material/LOD/collider batches remain byte-exact. No core SDF/route/rock/physical-crystal change,native artistic sign-off/FPS or all-user completion."},"  "));print("CRYSTAL_VEIN_DOMAINS ",checks," records=",records," failures=",failures);quit(0 if failures.is_empty() else 1)
