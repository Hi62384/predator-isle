extends "res://tools/caves/check_biome_regions.gd"
const Blend=preload("res://scripts/caves/biome_blend.gd")
const Frozen=preload("res://tools/caves/frozen_fixture.gd")
const GOLDEN:String="res://tools/biome_extensions/artifacts/revisions/experiment_cave_frozen_components_checkpoint_7023bc5d9e40/sources/scripts/caves/biome_regions.gd.txt"
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,GOLDEN,"res://scripts/caves/biome_definition.gd","res://scripts/caves/biome_region_settings.gd","res://scripts/caves/biome_regions.gd","res://scripts/caves/workload.gd","res://scripts/caves/biome_blend.gd","res://scripts/caves/biome_materials.gd","res://scripts/caves/frozen_surface.gd","res://scripts/caves/surface_biomes.gd","res://config/caves/cave_biome_regions.tres"]:guards[path]=FileAccess.get_sha256(path)
	var old:=GDScript.new();old.source_code=FileAccess.get_file_as_string(GOLDEN);check(old.reload()==OK,"Source-frozen accepted pre-Crystal selector loads as independent golden control")
	var registry:Resource=load("res://config/caves/cave_biome_regions.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);var planner=Regions.new();var baseline=old.new();var flat=FlatBuilder.new();planner.configure(flat,registry,73921);baseline.configure(flat,registry,73921)
	for seed_value in range(48):
		planner.seed_id=seed_value;baseline.seed_id=seed_value;var a:Dictionary=planner.decorate(fixture());var b:Dictionary=baseline.decorate(fixture());check(var_to_bytes(a)==var_to_bytes(b),"Complete Default/Frozen-only graph candidate output remains byte-identical to frozen accepted source")
	var crystal=Definition.new();crystal.biome_id=&"crystal";crystal.display_name="Crystal probability fixture";crystal.spawn_chance_percent=18;crystal.depth_preferences=PackedFloat32Array([5,20,50,80,100]);crystal.surface_preferences={"crystal_wastes":100.0,"quarry":65.0};crystal.minimum_extent_metres=350;crystal.maximum_extent_metres=1500;crystal.independent_suitability_admission=true
	var count:int=0;var raw_count:int=0;var size_sum:float=0
	for i in range(100000):
		var identity:String="crystal_eligible_"+str(i);var proposed:Dictionary=Regions.proposal(crystal,identity,73921)
		if proposed.accepted:
			raw_count+=1
			if Regions.suitability_admitted(crystal,identity,73921,.8*.65):count+=1;size_sum+=proposed.extent_m
		check(not Regions.suitability_admitted(crystal,identity,73921,0) and Regions.suitability_admitted(crystal,identity,73921,1) and not Regions.suitability_admitted(crystal,identity,73921,NAN),"Exact suitability zero/one/NaN boundaries")
	check(absi(count-9360)<500 and absi(raw_count-18000)<600,"100000 predeclared eligible anchors reproduce18%*.8*.65=.0936,not diluted Default competition or area coverage")
	check(size_sum/count>880 and size_sum/count<970,"Admitted physical extent independent of suitability/chance channel")
	# Actual planner at the230m level-four anchor,with pure Quarry surface.
	var b=make_builder(0,73921);var test_region:Dictionary={"valid":true,"id":Vector2i.ZERO,"geology":0,"nodes":[{"id":"eligible","point":Vector3.ZERO,"level":3}],"edges":[]}
	var builder=FlatBuilder.new();builder._extra_weights[0]=1
	# FlatBuilder has Grass1 too;use a tiny numeric adapter for exact Quarry.
	var synthetic:=GDScript.new();synthetic.source_code="extends RefCounted\nvar _jungle_weight=0.0\nvar _mountain_weight=0.0\nvar _tropical_weight=0.0\nvar _badlands_weight=0.0\nvar _extra_weights=PackedFloat64Array([1,0,0,0,0,0,0,0])\nfunc _get_height(_x,_z):return 230.0\nfunc _biome_weights(_x,_z):return Vector4.ZERO\n";check(synthetic.reload()==OK,"Exact canonical-owner probability control adapter")
	registry.definitions.append(crystal);planner.configure(synthetic.new(),registry,73921);var planner_count:int=0
	for i in range(20000):
		test_region.nodes[0].id="eligible"+str(i);var plan:Dictionary=planner.decorate(test_region.duplicate(true))
		for candidate:Dictionary in plan.cave_biome_regions.candidates:
			if candidate.biome_id=="crystal":planner_count+=1;check(is_equal_approx(candidate.depth_preference,.8) and is_equal_approx(candidate.surface_preference,.65),"Planner records raw independent depth/surface product")
	check(absi(planner_count-1872)<180,"Actual planner confirms9.36percent product while Default remains eligible")
	var halo_results:Array=[];crystal.spawn_chance_percent=2;crystal.minimum_extent_metres=1000;crystal.maximum_extent_metres=2000;check(registry.validation_errors().is_empty() and registry.discovery_halo()==2,"Requested rare2percent/1000–2000m configuration admits bounded5x5 halo")
	for i in range(10000):
		var p:Dictionary=Regions.proposal(crystal,"rare"+str(i),73921);check(p.extent_m>=1000 and p.extent_m<=2000,"Rare extent remains continuous independent actual kilometre range")
	crystal.enabled=false;check(registry.discovery_halo()==1,"Disabled large definition restores exact original3x3 halo");crystal.enabled=true;crystal.spawn_chance_percent=0;check(registry.discovery_halo()==1,"Zero-chance large definition cannot expand worker discovery");crystal.spawn_chance_percent=2
	var config=Config.new();config.regional_activity=1;config.biome_regions=registry;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual original Quarry worker accepts rare2000m configuration without new jobs")
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(6,-2));halo_results.append({"valid":not bundle.has("error") and bundle.get("regions",[]).size()==25,"regions":bundle.get("regions",[]).size(),"features":work.field.begins.size(),"numeric_bytes":work.field.numeric_bytes(),"cache_regions":work.network._regions.size(),"connections":bundle.get("connections",[]).size()})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(halo_results.size()==1 and halo_results[0].valid and halo_results[0].features>0 and halo_results[0].features<65536 and halo_results[0].cache_regions<=32,"Positive original actual5x5 sparse compilation within unchanged feature/cache bounds")
	# Joined-region geography crosses only actual graph edges,not close rock.
	var candidate:Dictionary={"id":"r0/crystal","biome_id":"crystal","anchor":"A","distances":{"A":0},"reach_m":1000.0,"transition_m":32.0,"connected_growth":true}
	var r0:Dictionary={"cave_biome_regions":{"candidates":[candidate],"edges":[{"from":"A","to":"B","length":200.0}]}};var r1:Dictionary={"cave_biome_regions":{"candidates":[],"edges":[{"from":"C","to":"D","length":200.0},{"from":"isolated","to":"isolated2","length":1.0}]}}
	var combined:Dictionary=Regions.combine([r0,r1],[{"from":"B","to":"C","points":PackedVector3Array([Vector3.ZERO,Vector3(300,0,0)])}]);check(combined.candidates[0].distances.D==700 and not combined.candidates[0].distances.has("isolated"),"Canonical inter-region connector extends candidate to real700m graph distance without disconnected spherical islands")
	check(candidate.distances.size()==1,"Combined graph growth never mutates cached source region")
	# Four-channel simplex including zero/full/overlap;the GPU will interpolate
	# raw controls then normalize,not interpolate already-divided controls.
	var maximum_error:float=0
	for a in range(11):
		for c in range(11-a):
			for d in range(11-a-c):
				for e in range(11-a-c-d):
					var w:=Vector4(a,c,d,e)/10.0;var actual:float=1.0;var expected:float=1.0-w.x-w.y-w.z-w.w
					for slot in range(4):actual=lerpf(actual,float(slot+2),Blend.control(w,slot,4));expected+=float(slot+2)*w[slot]
					maximum_error=maxf(maximum_error,absf(actual-expected));check(absf(actual-expected)<.000002,"Conditional sequential composition equals raw normalized biome-weighted sum")
	for i in range(101):var w:=Vector4(i/100.0,0,0,0);check(Blend.control(w,0,1)==w.x,"Single-biome weight exactly unchanged")
	crystal.minimum_extent_metres=350;crystal.maximum_extent_metres=1500;crystal.spawn_chance_percent=18;check(registry.discovery_halo()==1,"Rare diagnostic controls restored to normal18percent/350–1500m;no saved registry mutation")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable Crystal foundation source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_foundation.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"product_expected":.0936,"eligible_anchors":100000,"raw_spawn_admitted":raw_count,"product_admitted":count,"actual_planner_admitted_of_20000":planner_count,"rare_actual_worker":halo_results,"maximum_composition_error":maximum_error,"scope":"Independent Crystal product/size,exact accepted-source Default+Frozen geography controls,actual original Quarry rare2000m5x5 bounded worker,geodesic connected inter-region propagation and CPU blend simplex. Crystal definition here is private,not yet registered;no rendered crystals,native traversal,FPS or all-user completion claim."},"  "));print("CRYSTAL_FOUNDATION ",checks," product=",count," planner=",planner_count," halo=",halo_results," failures=",failures);quit(0 if failures.is_empty() else 1)
