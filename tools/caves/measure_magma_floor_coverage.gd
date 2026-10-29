extends "res://tools/caves/check_frozen_world_cohort.gd"
const DefaultForms=preload("res://scripts/caves/formations.gd")
func add_grid(cells:Dictionary,point:Vector3,radius:float,spacing:float)->void:
	var first:=Vector2i(floori((point.x-radius)/spacing),floori((point.z-radius)/spacing));var last:=Vector2i(floori((point.x+radius)/spacing),floori((point.z+radius)/spacing))
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var key:=Vector3i(x,roundi(point.y/8),z)
			if not cells.has(key):cells[key]=point.y
func floor_point(field,p:Vector3)->Vector3:
	var low:Vector3=p-Vector3.UP*4;var high:Vector3=p+Vector3.UP*2.2
	if field.sample(low)<.02 or field.sample(high)>-.05:return Vector3.INF
	for iteration in range(15):
		var mid:Vector3=(low+high)*.5
		if field.sample(mid)>=0:low=mid
		else:high=mid
	var point:Vector3=(low+high)*.5
	if field.normal(point).y<cos(PI/4):return Vector3.INF
	for y:float in [.45,.95,1.45]:
		for z:float in [-.2828427,.2828427]:
			for x:float in [-.2828427,.2828427]:
				if field.sample(point+Vector3(x,y,z))>-.03:return Vector3.INF
	if field.sample(point+Vector3.UP*1.85)>-.03:return Vector3.INF
	return point
func cell_bounds(work,key:Vector3i,seed_id:int,region:Dictionary,cache:Dictionary)->Array:
	if cache.has(key):return cache[key]
	var boxes:Array=[]
	if work.field.has_chunk(key):
		var defaults:Dictionary=DefaultForms.new().build(work.field,key,seed_id,int(region.get("geology",0)),work.configuration.formation_density)
		for form:Dictionary in defaults.placements:
			var tip:float=form.root.y+form.up*form.height;boxes.append(AABB(Vector3(form.root.x-form.radius,minf(form.root.y,tip)-.9,form.root.z-form.radius),Vector3(form.radius*2,absf(tip-form.root.y)+1.8,form.radius*2)))
		var ids:Array=work.field.biome_ids_for_cell(key)
		for definition:Resource in work.configuration.biome_regions.definitions:
			if not definition.enabled or definition.feature_provider==null or not ids.has(str(definition.biome_id)):continue
			var payload:Dictionary=definition.feature_provider.new().build(work.field,key,seed_id,[region],definition.feature_configuration,work.water_cell(key))
			for form:Dictionary in payload.get("placements",[]):
				if form.get("collider",true) and form.has("bounds"):boxes.append(form.bounds)
	if cache.size()>=256:cache.erase(cache.keys()[0])
	cache[key]=boxes;return boxes
func measure(work,region:Dictionary,seed_id:int,spacing:float,cache:Dictionary)->Dictionary:
	var cells:Dictionary={}
	for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
		if int(room.get("level",-1))>=0:add_grid(cells,room.point,room.chamber_radius+spacing*.5,spacing)
	for pool:Dictionary in region.get("pools",[]):
		for room:Dictionary in pool.get("bank_lobes",[]):add_grid(cells,room.point,room.chamber_radius+spacing*.5,spacing)
	for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
		if edge.entrance:continue
		for point:Vector3 in edge.points:add_grid(cells,point,edge.half_width+spacing*.5,spacing)
	var ordered:Array=cells.keys();ordered.sort_custom(func(a:Vector3i,b:Vector3i)->bool:return a.y<b.y or (a.y==b.y and (a.z<b.z or (a.z==b.z and a.x<b.x))))
	var seen:Dictionary={};var tested:int=0;var clear:int=0;var wet:int=0;var blocked:int=0;var magma_weight:float=0;var dominant:int=0
	for key:Vector3i in ordered:
		var point:Vector3=floor_point(work.field,Vector3((key.x+.5)*spacing,float(cells[key]),(key.z+.5)*spacing));tested+=1
		if not point.is_finite():continue
		var unique:=Vector3i(key.x,roundi(point.y/4),key.z)
		if seen.has(unique):continue
		seen[unique]=true;var water:bool=false
		for pool:Dictionary in region.get("pools",[]):
			if point.y<pool.water_y+.1 and Vector2(point.x-pool.center.x,point.z-pool.center.z).length()<pool.radius:water=true;break
		if water:wet+=1;continue
		var owner:Vector3i=work.field.cell(point);var body:=AABB(point+Vector3(-.4,.05,-.4),Vector3(.8,1.8,.8));var occupied:bool=false
		for z in range(-1,2):
			if occupied:break
			for y in range(-1,2):
				if occupied:break
				for x in range(-1,2):
					for box:AABB in cell_bounds(work,owner+Vector3i(x,y,z),seed_id,region,cache):
						if body.intersects(box):occupied=true;break
					if occupied:break
		if occupied:blocked+=1;continue
		clear+=1;var weight:float=work.field.biome_weights_at(point+Vector3.UP*.05,["magma"]).x;magma_weight+=weight;dominant+=int(weight>.5)
	var area:float=spacing*spacing
	return {"spacing_m":spacing,"tested_locations":tested,"unique_supported_floors":seen.size(),"clear_dry_samples":clear,"wet_samples_excluded":wet,"conservative_prop_bounds_excluded":blocked,"dry_clear_floor_area_estimate_m2":clear*area,"magma_weighted_floor_area_estimate_m2":magma_weight*area,"dominant_magma_floor_area_estimate_m2":dominant*area,"magma_weighted_fraction":magma_weight/clear if clear>0 else 0.0}
func scan(studies:Array,offset:int)->Array:
	var rows:Array=[]
	for index in range(offset,studies.size(),3):
		var study:Dictionary=studies[index];var builder=owner("volcanic",int(study.seed));var config=Config.new();var work=Workload.new();var configured:bool=work.configure(builder.settings,config,int(study.seed),0);var region:Dictionary=work.network.region(Vector2i(study.site[0],study.site[1]));var count:int=0;var frozen:int=0
		for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):count+=int(candidate.biome_id=="magma");frozen+=int(candidate.biome_id=="frozen")
		var row:Dictionary={"ordinal":study.ordinal,"seed":study.seed,"site":study.site,"configured":configured,"region_valid":region.get("valid",false),"magma_candidate_count":count,"frozen_candidate_count":frozen,"compiled":true,"coarse":{},"fine":{}}
		if region.get("valid",false):
			row.compiled=work.use_bundle({"cell":region.id,"regions":[region],"connections":[]})
			if row.compiled:
				work.field.include_surface_air=false;work.field.opening_rock_cover=6;var cache:Dictionary={};row.coarse=measure(work,region,int(study.seed),8,cache)
				if study.fine:row.fine=measure(work,region,int(study.seed),4,cache)
		rows.append(row)
	return rows
func run()->void:
	var guards:Dictionary={get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)}
	for folder:String in ["res://scripts/caves","res://scripts"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://config/caves/cave_biome_regions.tres","res://config/caves/cave_settings.tres","res://config/caves/biomes/magma_cave_definition.tres","res://config/caves/biomes/crystal_cave_definition.tres","res://config/caves/biomes/frozen_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var studies:Array=[]
	for seed_id:int in [73921,17,92881]:
		for site:Vector2i in SITES:studies.append({"ordinal":studies.size(),"seed":seed_id,"site":[site.x,site.y],"fine":site==SITES[0]})
	for study:Dictionary in [{"seed":17,"site":[-73,138],"fine":true},{"seed":1001,"site":[-134,-196],"fine":false}]:study["ordinal"]=studies.size();studies.append(study)
	var plan_path:String="res://tools/biome_extensions/artifacts/magma_floor_coverage_plan.json";FileAccess.open(plan_path,FileAccess.WRITE).store_string(JSON.stringify({"studies":studies,"scope":"Original18Volcanic cohort cases plus two original real molten-source cases;8m grid and predeclared4m checks at four cases. Saved before sampling;all normal controls."},"  "));guards[plan_path]=FileAccess.get_sha256(plan_path)
	var outputs:Array=[[],[],[]];var tasks:Array=[]
	for worker in range(3):
		var target:Array=outputs[worker];var offset:int=worker;tasks.append(WorkerThreadPool.add_task(func()->void:target.append_array(scan(studies,offset))))
	for task:int in tasks:
		while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task)
	var rows:Array=[]
	for output:Array in outputs:rows.append_array(output)
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.ordinal<b.ordinal)
	var area:float=0;var magma:float=0;var occurrences:int=0;var fine_checks:Array=[]
	for row:Dictionary in rows:
		check(row.configured and row.compiled and row.frozen_candidate_count==0,"Actual normal pure-Volcanic floor query configures;no unmodeled frozen-water floor")
		occurrences+=int(row.magma_candidate_count>0)
		if not row.coarse.is_empty():
			area+=row.coarse.dry_clear_floor_area_estimate_m2;magma+=row.coarse.magma_weighted_floor_area_estimate_m2;check(row.coarse.magma_weighted_fraction>=0 and row.coarse.magma_weighted_fraction<=1,"Bounded actual floor coverage fraction")
			if row.magma_candidate_count==0:check(row.coarse.magma_weighted_floor_area_estimate_m2==0,"No candidate gives exact zero specialized accessible-floor weight")
		if not row.fine.is_empty():fine_checks.append({"ordinal":row.ordinal,"coarse_fraction":row.coarse.magma_weighted_fraction,"fine_fraction":row.fine.magma_weighted_fraction,"absolute_fraction_difference":absf(row.coarse.magma_weighted_fraction-row.fine.magma_weighted_fraction)})
	check(rows.size()==20 and area>0 and magma>0 and fine_checks.size()>0,"All20 fixed floor-area cases retained with positive actual specialized area and finer-grid checks")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual Magma coverage sampler "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_floor_coverage.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"rows":rows,"region_candidate_occurrences":occurrences,"sampled_dry_clear_floor_area_estimate_m2":area,"magma_weighted_floor_area_estimate_m2":magma,"magma_weighted_sampled_floor_fraction":magma/area if area>0 else 0.0,"finer_grid_checks":fine_checks,"scope":"NORMAL actual procedural pure-Volcanic20case query-field floor-area estimate,distinct from candidate occurrence. Fixed8m world grid/4m predeclared checks,actual45degree support and ordinary1.8m/.4m capsule envelope,retained water/lava exclusion,deduplicated overlapping room/passage floors,conservative complete optional-form bounds including neighboring owner cells. Connected generated network floor footprint;not exact3D volume,exhaustive native navigation,global mixed-world coverage or FPS. Conservative bounds/grid sampling can undercount narrow routes;finer-grid discrepancies reported,not silently normalized."},"  "));print("MAGMA_FLOOR_COVERAGE ",checks," area=",area," magma=",magma," occurrences=",occurrences," failures=",failures);quit(0 if failures.is_empty() else 1)
