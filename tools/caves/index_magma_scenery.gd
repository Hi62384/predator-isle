extends "res://tools/caves/check_frozen_world_cohort.gd"
const MagmaFeatures=preload("res://scripts/caves/magma_features.gd")
const Scope=preload("res://tools/caves/inspection_scope.gd")
func row_scan(study:Dictionary,config:Resource)->Dictionary:
	var builder=owner(study.host,int(study.seed));var work=Workload.new();var configured:bool=work.configure(builder.settings,config,int(study.seed),0);var site:=Vector2i(study.site[0],study.site[1]);var region:Dictionary=work.network.region(site);var candidates:Array=[];var rooms:Array=[];var tubes:Array=[];var forms:Dictionary={};var by_id:Dictionary={}
	for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
		if candidate.biome_id=="magma":candidates.append(candidate)
	for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
		by_id[str(room.id)]=room
		var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(room.id),str(room.id),0,0)
		if float(assignment.weights.get("magma",0))<.7:continue
		var depth:float=builder._get_height(room.point.x,room.point.z)-room.point.y;var band:int=5
		for level in range(5):
			if depth<config.biome_regions.depth_bands[level+1]:band=level+1;break
		rooms.append({"room_id":room.id,"profile":room.get("magma_profile","ungrown"),"graph_level":room.level,"depth_level":band,"depth_m":depth,"radius_m":room.chamber_radius,"headroom_m":room.chamber_height,"weights":assignment.weights})
	for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
		if edge.has("magma_tube_profile"):tubes.append({"room_id":edge.from,"to":edge.to,"profile":edge.magma_tube_profile,"half_width_m":edge.half_width,"headroom_m":edge.headroom})
	var compiled:bool=true
	if not rooms.is_empty():
		compiled=work.use_bundle({"cell":site,"regions":[region],"connections":[]})
		if compiled:
			var keys:Dictionary={}
			for room:Dictionary in rooms:
				var body:Dictionary=by_id[str(room.room_id)];var radius:float=body.chamber_radius+4;var first:Vector3i=work.field.cell(body.point-Vector3(radius,2,radius));var last:Vector3i=work.field.cell(body.point+Vector3(radius,body.chamber_height+3,radius))
				for z in range(first.z,last.z+1):
					for y in range(first.y,last.y+1):
						for x in range(first.x,last.x+1):keys[Vector3i(x,y,z)]=true
			var ordered:Array=keys.keys();ordered.sort_custom(func(a:Vector3i,b:Vector3i)->bool:return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x))))
			var settings:Dictionary=load("res://config/caves/biomes/magma_cave_definition.tres").feature_configuration
			for key:Vector3i in ordered:
				var payload:Dictionary=MagmaFeatures.new().build(work.field,key,int(study.seed),[region],settings,{})
				for placement:Dictionary in payload.placements:
					var parent:String=str(placement.id).get_slice("/",0)
					if by_id.has(parent) and not forms.has(placement.kind):forms[placement.kind]={"room_id":parent,"placement_id":placement.id,"key":[key.x,key.y,key.z],"root":placement.root,"height_m":placement.height,"width_m":placement.width,"raw_weight":placement.raw_weight}
	return {"ordinal":study.ordinal,"host":study.host,"seed":int(study.seed),"site":study.site,"original144":study.original144,"configured":configured,"valid":region.get("valid",false),"compiled_positive":compiled,"candidates":candidates,"rooms":rooms,"tubes":tubes,"formations":forms}
func run()->void:
	var original_path:String="res://tools/biome_extensions/artifacts/check_cave_magma_world_index.json";var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original_path));var guards:Dictionary={original_path:FileAccess.get_sha256(original_path),get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)};Scope.capture_terrain_dependencies(guards)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	check(original.passed and original.studies.size()==144,"All original144 cases retained before additional scenic discovery")
	var studies:Array=[]
	for row:Dictionary in original.studies:studies.append({"ordinal":studies.size(),"host":row.host,"seed":int(row.seed),"site":row.site,"original144":true})
	for host:String in ["volcanic","mountain","wise_mountains","badlands","quarry","radiation_wasteland"]:
		for seed_id in range(1000,1016):
			for site:Vector2i in SITES:studies.append({"ordinal":studies.size(),"host":host,"seed":seed_id,"site":[site.x,site.y],"original144":false})
	var plan_path:String="res://tools/biome_extensions/artifacts/magma_scenic_cohort_plan.json";FileAccess.open(plan_path,FileAccess.WRITE).store_string(JSON.stringify({"studies":studies,"order":"Original144,then six hosts in declared order,seeds1000–1015,original six sites. Complete720case plan saved before first region evaluation;no probability/extent override."},"  "));guards[plan_path]=FileAccess.get_sha256(plan_path)
	var outputs:Array=[[],[],[]];var tasks:Array=[];var config=Config.new()
	for worker in range(3):
		var target:Array=outputs[worker];var offset:int=worker
		tasks.append(WorkerThreadPool.add_task(func()->void:
			for index in range(offset,studies.size(),3):target.append(row_scan(studies[index],config))
		))
	for task:int in tasks:
		while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task)
	var rows:Array=[]
	for output:Array in outputs:rows.append_array(output)
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.ordinal<b.ordinal)
	var selected:Dictionary={};var candidate_count:int=0;var actual_room_count:int=0;var shallow_candidates:int=0;var formation_kinds:Dictionary={}
	for row:Dictionary in rows:
		check(row.configured and row.compiled_positive,"Configured actual normal case and all positive numeric fields "+str(row.ordinal));candidate_count+=row.candidates.size();actual_room_count+=row.rooms.size()
		for candidate:Dictionary in row.candidates:
			shallow_candidates+=int(candidate.depth_m<40);check(candidate.extent_m>=300 and candidate.extent_m<=1100,"Normal physical region extent retained")
		for room:Dictionary in row.rooms:
			var keys:Array=["host_"+str(row.host),"depth_"+str(room.depth_level)]
			if room.profile!="ungrown":keys.append("profile_"+str(room.profile))
			for name:String in keys:
				if not selected.has(name):selected[name]={"ordinal":row.ordinal,"host":row.host,"seed":row.seed,"site":row.site,"room_id":room.room_id,"selection":room}
		for tube:Dictionary in row.tubes:
			var name:String="tube_"+str(tube.profile)
			if not selected.has(name):selected[name]={"ordinal":row.ordinal,"host":row.host,"seed":row.seed,"site":row.site,"room_id":tube.room_id,"selection":tube}
		for kind:String in row.formations:
			formation_kinds[kind]=true;var name:String="formation_"+kind
			if not selected.has(name):selected[name]={"ordinal":row.ordinal,"host":row.host,"seed":row.seed,"site":row.site,"room_id":row.formations[kind].room_id,"selection":row.formations[kind]}
	check(rows.size()==720 and candidate_count>0 and actual_room_count>0 and shallow_candidates==0,"Every predeclared case retained;positive actual normal volcanic geology;no Level1 Magma candidate")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable current Magma scenic survey "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_scenic_index.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"rows":rows,"first":selected,"candidate_count":candidate_count,"actual_magma_rooms":actual_room_count,"shallow_candidate_count":shallow_candidates,"formation_kinds":formation_kinds.keys(),"scope":"Complete predeclared720case normal-settings numeric scenic catalogue including all original144cases and all negatives. Actual generated room/tube descriptors and measured finite feature payloads on single-region shared fields;first selections fixed after ordinal merge. Candidate occurrence and room counts are separate,not accessible-area coverage. Native3x3 scene/walk/LOD/material/FPS/art acceptance separate. Dormant Desert remains an original negative,not a new surface owner."},"  "));print("MAGMA_SCENIC_INDEX ",checks," cases=",rows.size()," candidates=",candidate_count," rooms=",actual_room_count," selected=",selected.keys()," failures=",failures);quit(0 if failures.is_empty() else 1)
