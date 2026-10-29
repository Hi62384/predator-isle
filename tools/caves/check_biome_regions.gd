extends "res://tools/biome_extensions/check_all.gd"
const Definition=preload("res://scripts/caves/biome_definition.gd")
const Settings=preload("res://scripts/caves/biome_region_settings.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
class FlatBuilder extends RefCounted:
	var _jungle_weight:float=0
	var _mountain_weight:float=0
	var _tropical_weight:float=0
	var _badlands_weight:float=0
	var _extra_weights:PackedFloat64Array=PackedFloat64Array([0,0,0,0,0,0,0,0])
	func _get_height(_x:float,_z:float)->float:return 200.0
	func _biome_weights(_x:float,_z:float)->Vector4:return Vector4(1,0,0,0)
func fixture()->Dictionary:
	var nodes:Array=[]
	for i in range(5):nodes.append({"id":"room"+str(i),"point":Vector3(i*100,150,0),"level":0,"chamber_radius":18,"chamber_height":18})
	var edges:Array=[]
	for i in range(4):edges.append({"from":nodes[i].id,"to":nodes[i+1].id,"points":PackedVector3Array([nodes[i].point,nodes[i+1].point])})
	# Geometrically nearby but disconnected room must receive no graph growth.
	nodes.append({"id":"disconnected","point":Vector3(50,150,1),"level":0,"chamber_radius":18,"chamber_height":18})
	return {"valid":true,"id":Vector2i.ZERO,"nodes":nodes,"edges":edges,"geology":0}
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/biome_definition.gd","res://scripts/caves/biome_region_settings.gd","res://scripts/caves/biome_regions.gd","res://scripts/caves/cave_settings.gd","res://scripts/caves/workload.gd","res://scripts/caves/network.gd","res://config/caves/biomes/default_cave_definition.tres","res://config/caves/cave_biome_regions.tres",get_script().resource_path]:guards[path]=FileAccess.get_sha256(path)
	var settings=Settings.new();check(settings.validation_errors().is_empty(),"Saved Default definition/registry valid");var definition:Resource=settings.definitions[0].duplicate_deep(Resource.DEEP_DUPLICATE_ALL);check(definition.biome_id==&"default" and definition.spawn_chance_percent==100 and definition.minimum_extent_metres==200 and definition.maximum_extent_metres==1200 and definition.depth_preferences==PackedFloat32Array([100,85,65,40,15]),"All requested initial Default controls are independent saved resource values")
	for depth in range(401):check(definition.depth_preference(depth,settings.depth_bands)>0,"Default has a positive preference through all five depth levels")
	for boundary:float in [40,100,180,280]:check(absf(definition.depth_preference(boundary-.001,settings.depth_bands)-definition.depth_preference(boundary+.001,settings.depth_bands))<.0001,"Depth-band boundaries do not create discontinuities")
	check(Definition.preference({"snow":100,"mountain":50,"grass":5},{"mountain":1.0})==.5,"Dormant Snow preference does not invent a live Snow owner or renormalize Mountain to100percent")
	check(is_equal_approx(Definition.preference({"grass":5,"mountain":100},{"grass":.5,"mountain":.5}),.525),"Actual mixed surface weights blend normalized preferences")
	check(Definition.preference({"snow":100},{"grass":1.0})==0,"Zero/unlisted surface preference excludes eligibility")
	var rare=definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);rare.biome_id=&"verification_only";rare.spawn_chance_percent=2;rare.minimum_extent_metres=1500;rare.maximum_extent_metres=1500;var common=rare.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);common.spawn_chance_percent=100;var count:int=0;var zero=rare.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);zero.spawn_chance_percent=0
	for i in range(10000):
		var identity:String="sample"+str(i);var a:Dictionary=Regions.proposal(rare,identity,73921);var b:Dictionary=Regions.proposal(common,identity,73921);check(a.extent_m==1500 and b.extent_m==a.extent_m and b.accepted and not Regions.proposal(zero,identity,73921).accepted,"Rare1500m size/chance independent,with exact0/100chance endpoints")
		if a.accepted:count+=1
	check(count>130 and count<270,"Positive deterministic2percent proposal ensemble,not a claimed world-volume coverage")
	var original:Dictionary=fixture();var topology:Dictionary=Regions.graph(original);var distances:Dictionary=Regions.distances(topology,"room0",250);check(not distances.has("disconnected") and distances.room2==200 and distances.room3==300,"Bounded geodesic growth includes partial last edge but never crosses disconnected nearby rock")
	var candidate:Dictionary={"id":"controlled","biome_id":"verification_only","distances":distances,"reach_m":250.0,"transition_m":32.0};var assignment:Dictionary={"fallback":"default","candidates":[candidate]};var first:Dictionary=Regions.along_edge(assignment,"room2","room3",0,100);var last:Dictionary=Regions.along_edge(assignment,"room2","room3",50,100);check(first.primary=="verification_only" and first.weights.verification_only==1 and last.primary=="default" and last.weights.default==1,"Coherent graph region has full interior and smooth physical extent endpoint")
	var previous:float=1
	for station in range(101):
		var direct:Dictionary=Regions.along_edge(assignment,"room2","room3",station,100);var reverse:Dictionary=Regions.along_edge(assignment,"room3","room2",100-station,100);var amount:float=direct.weights.get("verification_only",0);check(var_to_bytes(direct)==var_to_bytes(reverse) and amount<=previous+.000001,"Both edge directions/query orders give identical monotonic transition weights");previous=amount
	var planner=Regions.new();planner.configure(FlatBuilder.new(),settings,73921);var first_plan:Dictionary=planner.decorate(original.duplicate(true));var reordered:Dictionary=original.duplicate(true);reordered.nodes.reverse();reordered.edges.reverse();var second_plan:Dictionary=planner.decorate(reordered);check(var_to_bytes(first_plan.cave_biome_regions.candidates)==var_to_bytes(second_plan.cave_biome_regions.candidates),"Canonical candidate geography independent of input node/edge order")
	var extents:Dictionary={}
	for item:Dictionary in first_plan.cave_biome_regions.candidates:extents[item.extent_m]=true;check(item.extent_m>=200 and item.extent_m<=1200,"Default region extent stays within requested range")
	check(extents.size()>1,"Default regions do not all use midpoint extent")
	var special=definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);special.biome_id=&"verification_only";special.display_name="Synthetic verification only";special.depth_preferences=PackedFloat32Array([100,100,100,100,100]);special.minimum_extent_metres=400;special.maximum_extent_metres=400;settings.definitions.append(special);var selected:int=0
	for seed_value in range(200):
		planner.seed_id=seed_value;var mixed:Dictionary=planner.decorate(original.duplicate(true));settings.definitions.reverse();var reversed_definitions:Dictionary=planner.decorate(original.duplicate(true));settings.definitions.reverse();check(var_to_bytes(mixed.cave_biome_regions.candidates)==var_to_bytes(reversed_definitions.cave_biome_regions.candidates),"Weighted definition competition independent of registry order")
		for item:Dictionary in mixed.cave_biome_regions.candidates:
			if item.biome_id=="verification_only":selected+=1
	check(selected>400 and selected<900,"Positive independently proposed and preference-weighted competition across200fixed seeds")
	planner.seed_id=73921;special.enabled=false;check(var_to_bytes(planner.decorate(original.duplicate(true)).cave_biome_regions.candidates)==var_to_bytes(first_plan.cave_biome_regions.candidates),"Disabled future/synthetic definition leaves complete Default geography exact");settings.definitions.pop_back()
	check(Definition.preference({0:100},{0:1.0})==1 and Definition.preference({"0":100},{0:1.0})==1,"Stable geological style preferences support native integer or saved string keys")
	var save_path:String="res://.godot/cave_registry_roundtrip.tres";check(ResourceSaver.save(settings,save_path)==OK,"Editable registry saves through native ResourceSaver");var restored:Resource=ResourceLoader.load(save_path,"",ResourceLoader.CACHE_MODE_IGNORE);check(restored!=null and restored.validation_errors().is_empty() and restored.depth_bands==settings.depth_bands and restored.definitions[0].depth_preferences==settings.definitions[0].depth_preferences,"Native registry/definition roundtrip retains initial controls")
	check(not Regions.description(first_plan.cave_biome_regions).is_empty(),"Runtime debug summary exposes positive candidate counts/physical extent")
	settings.enabled=false;check(var_to_bytes(planner.decorate(original.duplicate(true)))==var_to_bytes(original),"Exact disabled graph descriptor restoration")
	settings.enabled=true;var locked:Dictionary=original.duplicate(true);locked["cave_family"]=7;check(var_to_bytes(planner.decorate(locked.duplicate(true)))==var_to_bytes(locked),"Existing organic biological network remains locked and unchanged")
	var invalid=definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);invalid.maximum_extent_metres=3000;check(not invalid.validation_errors().is_empty(),"Unsupported larger-than-halo definition fails closed instead of load-order-dependent geography")
	var config=Config.new();config.regional_activity=1;var builder=make_builder(3,73921);var work=Workload.new();check(work.configure(builder.settings,config,73921,0),"Actual original Default host accepts saved data-driven registry");var result:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var region:Dictionary=work.network.region(Vector2i(9,-3));var enabled:Dictionary=region.duplicate(true);var assignment_data:Dictionary=enabled.get("cave_biome_regions",{});enabled.erase("cave_biome_regions");work.network.region_finalizer=Callable();work.network._regions.clear();work.network._ring.clear();var disabled:Dictionary=work.network.region(Vector2i(9,-3));var exact:bool=var_to_bytes(enabled)==var_to_bytes(disabled);var bundle:Dictionary={"cell":Vector2i(9,-3),"regions":[region],"connections":[]};var valid:bool=work.use_bundle(bundle);var key:Vector3i=work.field.cell(region.nodes[1].point+Vector3(0,2,0));var arrays:Array=work.build(key);work.bundle_key=Vector2i(2147483647,2147483647);valid=valid and work.use_bundle({"cell":Vector2i(9,-3),"regions":[disabled],"connections":[]});var controls:Array=work.build(key);result.append({"valid":valid,"metadata_only":exact,"mesh_exact":var_to_bytes(arrays)==var_to_bytes(controls),"candidates":assignment_data.get("candidates",[]).size(),"key":str(key),"triangles":arrays[Mesh.ARRAY_VERTEX].size()/3})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(result.size()==1 and result[0].valid and result[0].metadata_only and result[0].mesh_exact and result[0].candidates>0 and result[0].triangles>0,"Actual original worker integrates positive Default geography while retaining complete old graph/mesh geometry exactly")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable biome schema/selection source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_biome_regions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"two_percent_proposals":count,"actual_original_worker":result,"scope":"Saved initial Default resource values,five continuous normalized depth preferences,blended canonical live-owner surface preferences,independent deterministic chance/size/competition,10000rare1500m proposal controls,bounded connected graph growth/partial-edge transitions/query reversal/order/off/biological-lock controls and positive actual original Spore worker full graph/mesh equality. Verification-only synthetic definition never saved or registered. Only Default registered;Frozen/Crystal Caverns/Magma geometry/materials not implemented by this component. No full later-biome/visual/performance completion claim."},"  "));print("CAVE_BIOME_REGIONS ",checks," rare=",count," actual=",result," failures=",failures);quit(0 if failures.is_empty() else 1)
