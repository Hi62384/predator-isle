extends "res://tools/caves/check_magma_heat_source.gd"
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_magma_heat_source.gd","res://scripts/caves/magma_heat.gd","res://scripts/caves/workload.gd","res://scripts/caves/magma_features.gd","res://config/caves/biomes/magma_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var bowl=Bowl.new();bowl.flat=true;var heat=Heat.new();heat.configure(bowl);var point:=Vector3(0,-180,0)
	check(heat.sample(point)=={"heat":0.0},"Strict retained-surface model stays cold when pool is not retained")
	heat.geological_intrusions=true;var explicit:Dictionary=heat.sample(point);check(explicit.heat>.9 and explicit.kind=="explicit_modeled_active_volcanic_intrusion" and explicit.id=="2:0:0/intrusion","Separate explicit underground body tied to active canonical volcanic centre,not a fake retained pool")
	check(heat.sample(Vector3(0,0,0))=={"heat":0.0} and heat.sample(Vector3(100,-180,0))=={"heat":0.0},"Above modeled intrusion and outside its finite radial body remain cold")
	check(heat.sample(Vector3(37.999,-180,0)).heat<.00001,"Intrusion suitability tapers continuously to zero at finite edge")
	heat.geological_intrusions=false;check(heat.sample(point)=={"heat":0.0},"Independent intrusive model OFF clears positive witnesses")
	heat.geological_intrusions=true;check(var_to_bytes(heat.sample(point))==var_to_bytes(explicit),"Explicit model ON/OFF/ON exact including negative source-cache invalidation")
	for mode:String in ["owner","island","ocean","inactive","liquids_off"]:
		var candidate=Bowl.new();candidate.flat=true
		match mode:
			"owner":candidate.coverage=.94
			"island":candidate.island=.09
			"ocean":candidate.water_level=100
			"inactive":candidate._extras[2].settings.active_frequency=0.0
			"liquids_off":candidate._extras[2].settings.special_liquids_enabled=false
		var negative=Heat.new();negative.geological_intrusions=true;negative.configure(candidate);check(negative.sample(point)=={"heat":0.0},"Explicit geology cannot bypass actual "+mode+" source eligibility")
	var edge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([Vector3(-100,-180,0),Vector3(100,-180,0)]),"half_width":4.0,"headroom":8.0};var region:Dictionary={"valid":true,"nodes":[],"edges":[edge]};var annotated:Dictionary=heat.annotate_region(region);check(not annotated.get("cave_thermal_sources",[]).is_empty() and annotated.cave_thermal_sources.size()<=64 and not region.has("cave_thermal_sources"),"Existing solved passage intersection receives bounded immutable heat without room anchors or new geometry")
	for source:Dictionary in annotated.cave_thermal_sources:check(source.kind=="explicit_modeled_active_volcanic_intrusion" and source.surface_source==explicit.id,"Every passage heat record preserves explicit source kind and exact identity")
	var real=make_builder(2);var actual=Heat.new();actual.geological_intrusions=true;actual.configure(real);var preserved:Dictionary=actual.sample(Vector3(241955,290,-97306.7));check(preserved.get("id","")=="2:33:-14" and preserved.get("kind","")=="retained_surface_crater_vertical_intrusion","Original actual retained surface source takes precedence and retains original witness semantics")
	check(heat.cache_counts().x<=32 and heat.cache_counts().y<=512,"Both source models share bounded cache,not extra terrain workers")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable explicit intrusion source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_intrusions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"explicit_source":explicit,"passage_sources":annotated.get("cave_thermal_sources",[]),"scope":"Explicit modeled intrusion source separate from strict retained-surface source:canonical active volcanic centre/owner/island/region/above-water constraints,finite64–864m below-source body and radial taper;OFF/cache restoration,passage-only heat,original real retained source precedence. No Kelvin or physical gradient simulation;native naturally admitted intrusive lava scene remains separate validation."},"  "));print("MAGMA_INTRUSIONS ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
