extends "res://tools/caves/render_crystal_world.gd"
const Shapes=preload("res://scripts/caves/formations.gd")
func inspection_name()->String:return "crystal_lake"
func selected_room_id()->String:return "6:-2:3:3:lobe:0"
func selected_pool_id()->String:return "6:-2:3:3:lobe:0:seepage"
func selection_label()->String:return "FIRST wet Crystal pool in the original126case cohort,not a rerolled/forced lake"
func inspection_views(data:Dictionary,largest:Dictionary)->Array:
	check(not data.pool.is_empty(),"Original first normal Crystal retained pool exists")
	var pool:Dictionary=data.pool;var center:Vector3=data.room.point;var water:=Vector3(pool.center.x,pool.water_y,pool.center.z)
	return [{"name":"actual_deep_lake","position":center+Vector3(0,1.8,0),"target":water},{"name":"actual_deep_minerals","position":center+Vector3(0,2.4,0),"target":largest.bounds.get_center() if not largest.is_empty() else center+Vector3(10,5,10)}]
func inspection_routes(data:Dictionary,field)->Array:
	var routes:Array=super.inspection_routes(data,field)
	if data.pool.is_empty():check(false,"Cannot replace missing original wet target with another seed/site");return routes
	var pool:Dictionary=data.pool;var center:Vector3=data.room.point;var radius:float=pool.radius+1.8;var direction:=Vector2(center.x-pool.center.x,center.z-pool.center.z);check(direction.length()>radius,"Original room point remains outside the predetermined dry bank route,not underwater start")
	var angle:float=atan2(direction.y,direction.x);var shapes=Shapes.new();var ring:Array[Vector3]=[]
	for i in range(33):
		var phase:float=angle+TAU*i/32;var p:=Vector3(pool.center.x+cos(phase)*radius,center.y,pool.center.z+sin(phase)*radius);var low:Vector3=p-Vector3.UP*6;var high:Vector3=p+Vector3.UP*8
		check(field.sample(low)>=0 and field.sample(high)<0,"Original fixed lake-bank station has actual supported solid/air floor bracket")
		var foot:Vector3=shapes.boundary(field,low,high);ring.append(foot+Vector3.UP*.95);check(Vector2(foot.x-pool.center.x,foot.z-pool.center.z).length()>pool.radius+1.5,"Entire preselected dry route remains outside retained water footprint")
	var route:Array[Vector3]=[data.parent.point+Vector3(0,.95,0),center+Vector3(0,.95,0)];route.append_array(ring);route.append(center+Vector3(0,.95,0));route.append(route[0]);routes.append({"label":"Same original deep Crystal parent/room/full fixed dry lake-bank circuit/same parent return","points":route});return routes
