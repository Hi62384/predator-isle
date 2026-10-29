extends "res://tools/caves/render_magma_intrusive_world.gd"
func index_path()->String:return "res://tools/biome_extensions/artifacts/check_cave_magma_fixed_lakes.json"
func selected_case(catalogue:Dictionary)->Dictionary:
	var row:Dictionary=catalogue.first_diagnostic
	if row.is_empty():return {}
	return {"ordinal":catalogue.cases.find(row),"host":row.host,"seed":int(row.seed),"site":row.site,"rooms":[{"room":{"id":str(row.pool_id).trim_suffix(":seepage")}}],"pool_id":row.pool_id}
func world_definition()->Resource:
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);definition.feature_configuration.large_lake_chance=1.0;return definition
func report_basename()->String:return "render_cave_magma_large_lake_world"
func capture_prefix()->String:return "magma_large_lake_world"
func additional_routes(data:Dictionary)->Array:
	var pool:Dictionary=data.pool;check(pool.get("magma_large_lake",false) and pool.get("bank_lobes",[]).size()==3,"Actual production larger lake has low dry bank and two unequal source-backed vaults")
	if not pool.get("magma_large_lake",false):return []
	var route:Array[Vector3]=[data.room.point+Vector3(0,.95,0)];var outward:Array[Vector3]=[];var phase:float=atan2(data.room.point.z-pool.center.z,data.room.point.x-pool.center.x)
	for station in range(65):var angle:float=phase+TAU*station/64;outward.append(pool.center+Vector3(cos(angle)*(pool.radius+2),.95,sin(angle)*(pool.radius+2)))
	route.append_array(outward)
	for index in range(outward.size()-2,-1,-1):route.append(outward[index])
	route.append(route[0]);return [{"label":"Exact fixed source-backed large lake complete two-way360degree dry rim and original parent return","points":route}]
func additional_native_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var camera_before:Transform3D=camera.transform;var light_before:Transform3D=light.transform;var pool:Dictionary=data.pool;var direction:Vector3=(data.room.point-pool.center)*Vector3(1,0,1);camera.position=pool.center+direction.normalized()*(pool.radius+2)+Vector3(0,1.8,0);camera.look_at(data.largest.bounds.get_center());light.position=camera.position+Vector3.UP*.5
	var before:Image=await capture("bank_basalt_test_only_lamp")
	for node:Node in nodes:
		for child:Node in node.get_children():
			if str(child.name)=="CaveBiome_magma_cooled_volcanic":child.visible=false
	var off:Image=await capture("bank_basalt_off")
	for node:Node in nodes:
		for child:Node in node.get_children():
			if str(child.name)=="CaveBiome_magma_cooled_volcanic":child.visible=true
	var restored:Image=await capture("bank_basalt_return");check(before.get_data()!=off.get_data() and before.get_data()==restored.get_data(),"Actual opaque bank basalt is separately visible with exact geometry-off/return")
	var result:Dictionary={"basalt_camera":camera.position,"basalt_target":data.largest.bounds.get_center(),"independent_opaque_geometry_counterfactual":before.get_data()!=off.get_data()};camera.transform=camera_before;light.transform=light_before;return result
func scope_description()->String:return "DIAGNOSTIC large-profile chance100percent ONLY;normal saved8percent unchanged. Exact FIRST physically eligible large lake among ALL eight fixed original source-backed molten positives;all16normal/diagnostic outcomes retained. Original source/biome22percent/molten14percent/host/seed/site/pool ID unchanged;no feeder removal or location replacement. Actual neighbouring production field/native large clipped molten surface/three joined vaults/opaque PBR basalt/collision/frontiers and full two-way360degree dry rim plus original passage/parent returns. Original main environment/test-only lamp,independent molten/opaque geometry-off/exactreturn;lava clock frozen only for diagnostic pixels. Not a normal-frequency large-lake appearance,full live large-lake route,FPS,reference art or all-user completion."
