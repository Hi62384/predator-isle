extends "res://tools/caves/render_crystal_world.gd"
const CandidateField=preload("res://tools/caves/floor_relief_field_candidate.gd")
const Relief=preload("res://tools/caves/floor_relief_candidate.gd")
var candidate_field
var floor_route:Array=[]
var floor_admissions:Array=[]
func inspection_name()->String:return "crystal_floor_relief_candidate"
func selected_room_id()->String:return "6:-2:3:3:lobe:0"
func inspection_control_scope()->String:return "PRIVATE floor-relief field only,same original normal Crystal Wastes73921/(6,-2)quartz chamber. Normal geography/mineral controls unchanged. First deterministic dry floor line admitted before physics;all rejected lines retained."
func additional_guards()->Dictionary:
	var result:Dictionary={}
	for path:String in ["res://tools/caves/floor_relief_field_candidate.gd","res://tools/caves/floor_relief_candidate.gd"]:result[path]=FileAccess.get_sha256(path)
	return result
func inspection_prepare_workload(work)->void:
	candidate_field=CandidateField.new();candidate_field.maximum_depth=work.field.maximum_depth;candidate_field.minimum_roof=work.field.minimum_roof;work.field=candidate_field
func measured_floor(p:Vector3)->Vector3:
	var low:float=p.y-1;var high:float=p.y+1
	if candidate_field.sample(Vector3(p.x,low,p.z))<0 or candidate_field.sample(Vector3(p.x,high,p.z))>=0:return Vector3.INF
	for iteration in range(16):
		var mid:float=(low+high)*.5
		if candidate_field.sample(Vector3(p.x,mid,p.z))>=0:low=mid
		else:high=mid
	return Vector3(p.x,(low+high)*.5,p.z)
func inspection_views(data:Dictionary,largest:Dictionary)->Array:
	# Fixed line ordering is established before native physics. No new line is
	# substituted after a walking failure.
	for axis in range(2):
		for fraction:float in [.5,-.5,.65,-.65]:
			var points:Array=[];var valid:bool=true;var raised:int=0
			for station in range(-4,5):
				var p:Vector3=data.room.point+(Vector3(station*1.5,0,fraction*data.room.chamber_radius) if axis==0 else Vector3(fraction*data.room.chamber_radius,0,station*1.5));var floor:Vector3=measured_floor(p)
				if not floor.is_finite():valid=false;break
				if candidate_field.normal(floor).y<cos(PI/4):valid=false;break
				for form:Dictionary in data.placements:
					if form.collider and form.bounds.grow(.6).has_point(floor+Vector3.UP*.9):valid=false
				if not valid:break
				raised+=int(Relief.offset(candidate_field,floor,.65)>.12);points.append(floor+Vector3.UP*.95)
			floor_admissions.append({"axis":axis,"fraction":fraction,"clear":valid,"positive_ridge_stations":raised})
			if valid and raised>0:
				floor_route=points
				for i in range(points.size()-2,-1,-1):floor_route.append(points[i])
				break
		if not floor_route.is_empty():break
	check(not floor_route.is_empty(),"Actual original room has first pre-physics admitted positive raised dry floor line")
	var views:Array=super.inspection_views(data,largest)
	if not floor_route.is_empty():views.append({"name":"actual_rock_floor_ridges","position":floor_route[0]+Vector3.UP*.85,"target":floor_route[4]-Vector3.UP*.5})
	return views
func inspection_routes(data:Dictionary,field)->Array:
	var routes:Array=super.inspection_routes(data,field)
	if not floor_route.is_empty():routes.append({"label":"First pre-physics admitted actual raised Crystal floor line and same-way return","points":floor_route})
	return routes
func inspection_material_checks(_data:Dictionary,_nodes:Array,_camera:Camera3D,_light:OmniLight3D)->Dictionary:return {"floor_line_admissions":floor_admissions,"selected_line":floor_route}
