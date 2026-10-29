extends "res://tools/caves/check_crystal_world_cohort.gd"
## First normal profiles selected by the original126case occurrence cohort.
## Per-form geometry fingerprints deliberately exclude only material bucket
## and selection flags,so an optical change cannot hide a collider/root edit.
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();var reference_path:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("reference="):reference_path=arg.trim_prefix("reference=")
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_world_cohort.gd","res://tools/caves/check_frozen_world_cohort.gd","res://shaders/cave_crystal_feature.gdshader","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var b=owner("crystal_wastes",73921);var work=Workload.new();var records:Array=[];var geometry:Dictionary={};var configured:bool=work.configure(b.settings,config,73921,0)
		for target:Dictionary in [{"profile":"geode","site":Vector2i(6,-2),"id":"6:-2:2:0:crystal:geode:1"},{"profile":"ravine","site":Vector2i(8,-4),"id":"8:-4:2:2:crystal:ravine:0"}]:
			var bundle:Dictionary=work.discover(target.site);var room:Dictionary={}
			for region:Dictionary in bundle.get("regions",[]):
				for candidate:Dictionary in region.get("pockets",[]):
					if candidate.id==target.id:room=candidate
			var record:Dictionary={"profile":target.profile,"configured":configured,"room_found":not room.is_empty(),"forms":0,"clear":0,"eligible_minor":0,"profile_forms":0,"profile_clear":0}
			if not room.is_empty():
				var center:Vector3i=work.field.cell(room.point+Vector3.UP*2)
				for dz in range(-1,2):
					for dy in range(-1,2):
						for dx in range(-1,2):
							var key:Vector3i=center+Vector3i(dx,dy,dz);var data:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,definition.feature_configuration,{})
							for placement:Dictionary in data.placements:
								var batch:Dictionary={}
								for candidate:Dictionary in data.batches:
									if candidate.kind==placement.batch:batch=candidate;break
								var first:int=placement.first_vertex;var end:int=first+placement.vertex_count;var arrays:Array=batch.arrays;var fingerprint:Array=[key,placement.id,placement.kind,placement.owner,placement.root,placement.axis,placement.height,placement.width,placement.family,placement.broken,placement.age,placement.importance,placement.collider,placement.attachments,placement.bounds]
								for slot:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:fingerprint.append(arrays[slot].slice(first,end))
								var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(var_to_bytes(fingerprint));geometry[target.profile+"/"+str(placement.id)]=hasher.finish().hex_encode()
								if placement.kind!="crystal":continue
								record.forms+=1;record.clear+=int(placement.thin_transmission)
								var eligible:bool=(placement.width<.45 and placement.height<4 and placement.family in [0,2,4]) or (placement.family==4 and placement.width<1.5 and placement.height<3);record.eligible_minor+=int(eligible)
								if str(placement.id).begins_with(str(target.id)+"/"):record.profile_forms+=1;record.profile_clear+=int(placement.thin_transmission)
			records.append(record)
		output.append({"records":records,"geometry":geometry})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1,"Complete original first-profile material inspection returned")
	if output.is_empty():quit(1);return
	var result:Dictionary=output[0]
	for record:Dictionary in result.records:
		check(record.configured and record.room_found and record.profile_forms>0,"Actual new profile itself contains positive minerals,not only neighboring parent forms")
		check((record.eligible_minor==0 and record.clear==0) or (record.eligible_minor>0 and record.clear>0 and record.clear<=maxi(1,ceili(record.eligible_minor*.35))),"Selective near optics affect only a minority of eligible thin forms;no eligible forms correctly means no transmission")
	if not reference_path.is_empty():
		check(reference_path.begins_with("res://tools/biome_extensions/artifacts/revisions/") and reference_path.ends_with(".json"),"Explicit pre-existing frozen baseline,not mutable current report")
		var previous=JSON.parse_string(FileAccess.get_file_as_string(reference_path));guards[reference_path]=FileAccess.get_sha256(reference_path);check(previous is Dictionary and previous.has("form_geometry_sha256"),"Original per-form geometry reference present")
		if previous is Dictionary:
			check(previous.form_geometry_sha256.size()==result.geometry.size(),"No form deleted or added to obtain an opacity pass")
			for identity:String in previous.form_geometry_sha256:check(result.geometry.get(identity,"")==previous.form_geometry_sha256[identity],"Every original form/root/attachment/normal/UV/importance/collider and primitive vertices exact "+identity)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable profile optical source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_profile_optics.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":result.records,"form_geometry_sha256":result.geometry,"reference":reference_path,"scope":"FIRST original normal geode/ravine27cell material populations,positive new-profile-owned forms and genuinely selective near optics. Optional exact frozen per-form geometry/root/UV/normal/importance/collider comparison excludes ONLY material bucket/selection flags. Not native image/art/FPS,normal large-lake occurrence or all-user completion."},"  "));print("CRYSTAL_PROFILE_OPTICS ",checks," records=",result.records," failures=",failures.slice(0,5));quit(0 if failures.is_empty() else 1)
