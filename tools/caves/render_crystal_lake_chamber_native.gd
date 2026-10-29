extends "res://tools/caves/render_crystal_world.gd"
const SelectionReport:String="res://tools/biome_extensions/artifacts/check_cave_crystal_lake_chamber_candidate.json"
var selection:Dictionary={}
func inspection_name()->String:return "crystal_lake_chamber_native"
func inspection_host()->String:return selection.host
func inspection_seed()->int:return int(selection.seed)
func inspection_site()->Vector2i:return Vector2i(selection.site[0],selection.site[1])
func selected_room_id()->String:return selection.parent_room_id
func selected_pool_id()->String:return selection.pool_id
func selection_label()->String:return "FIRST complete production-generated bank lake in five ORIGINAL fixed pool cases,selected before native images;all negatives retained."
func inspection_control_scope()->String:return "DIAGNOSTIC large_lake_frequency1 only;normal18percent/.65mineral density/host/network/seed unchanged. Normal saved lake frequency.12 is never edited."
func inspection_definition()->Resource:
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);definition.feature_configuration.large_lake_frequency=1.0;return definition
func additional_guards()->Dictionary:return {SelectionReport:FileAccess.get_sha256(SelectionReport),get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)}
func inspection_views(data:Dictionary,_largest:Dictionary)->Array:
	var center:Vector3=data.pool.center;var direction:Vector3=(data.room.point-center).normalized();direction.y=0;direction=direction.normalized();var across:=Vector3(-direction.z,0,direction.x);var distance:float=data.pool.radius+2
	return [{"name":"actual_large_lake","position":center+direction*distance+Vector3.UP*1.8,"target":center+Vector3.UP*.2},{"name":"opposite_dry_bank","position":center+across*distance+Vector3.UP*1.8,"target":center+Vector3.UP*1.0},{"name":"original_room_approach","position":data.room.point+Vector3.UP*1.8,"target":center}]
func floor_target(point:Vector3)->Vector3:
	var hit:Dictionary=root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*6,point-Vector3.UP*4,1));check(not hit.is_empty() and hit.get("normal",Vector3.ZERO).y>cos(PI/4),"Every lake approach/perimeter waypoint measured on actual walkable native rock before physics")
	if not hit.is_empty():point.y=hit.position.y
	return point+Vector3.UP*.95
func inspection_routes(data:Dictionary,_field)->Array:
	var routes:Array=super.inspection_routes(data,_field);var center:Vector3=data.pool.center;var direction:Vector3=data.room.point-center;direction.y=0;var phase:float=atan2(direction.z,direction.x);var points:Array=[floor_target(data.room.point)]
	check(data.pool.has("bank_lobes") and data.pool.get("bank_access",[]).size()==1,"Actual full pipeline retains one bounded bank lobe and protected dry approach")
	for index in range(65):
		var angle:float=phase+TAU*index/64;var p:Vector3=center+Vector3(cos(angle),0,sin(angle))*(data.pool.radius+2);var target:Vector3=floor_target(p);check(target.y-.95>=data.pool.water_y+.2,"Every native bank station has dry water-level freeboard");points.append(target)
	var outward:Array=points.duplicate()
	for index in range(outward.size()-2,-1,-1):points.append(outward[index])
	routes.append({"label":"Original room approach,COMPLETE dry lake perimeter,and exact same-way return","points":points});return routes
func run()->void:
	var report=JSON.parse_string(FileAccess.get_file_as_string(SelectionReport));check(report is Dictionary and report.get("passed",false),"Positive actual complete-generator lake report available")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	for path:String in report.source_sha256:check(FileAccess.get_sha256(path)==report.source_sha256[path],"Lake selection bound to unchanged validated generator "+path)
	selection=report.get("first_positive",{});check(not selection.is_empty(),"FIRST complete generated lake exists without substituted seed/site")
	if selection.is_empty() or not failures.is_empty():print("LAKE_NATIVE_PREFLIGHT ",failures);quit(1);return
	await render_selected()
func render_selected()->void:
	await super.run()
