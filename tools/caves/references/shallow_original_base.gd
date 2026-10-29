extends RefCounted
## Private shared-core proposal. An attached shallow side chamber follows an
## existing entry's grade before turning onto its own flat floor. Original
## graph nodes/routes remain intact; every old access floor is tested again.
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Field=preload("res://scripts/caves/field.gd")
static func prepare(region:Dictionary,height:Callable,enabled:bool=true,maximum_depth:float=400,minimum_roof:float=10)->Dictionary:
	if not enabled or not region.get("valid",false) or region.get("cave_family",-1) in [6,7] or region.get("pockets",[]).size()>=Profiles.MAX_POCKETS:return region
	var access:Dictionary=region.edges[0];var points:PackedVector3Array=access.points;var attempts:int=0
	var original=Field.new();original.maximum_depth=maximum_depth;original.minimum_roof=minimum_roof
	if not original.compile([region],height):return region
	for index in range(1,points.size()-1):
		var start:Vector3=points[index];var depth:float=height.call(start.x,start.z)-start.y
		if depth<28 or depth>36:continue
		var delta:Vector3=points[index+1]-points[index-1];var heading:=Vector2(delta.x,delta.z).normalized();var grade:float=delta.y/maxf(Vector2(delta.x,delta.z).length(),.001)
		if absf(grade)>.18:continue
		for side:float in [-1.0,1.0]:
			attempts+=1
			if attempts>12:return region
			var lateral:=Vector2(-heading.y,heading.x)*side;var diagonal:Vector2=heading*(23*cos(PI/7.2))+lateral*(23*sin(PI/7.2));var join:Vector3=start+Vector3(diagonal.x,grade*23*cos(PI/7.2),diagonal.y);var point:Vector3=join+Vector3(lateral.x,0,lateral.y)*30;var final_depth:float=height.call(point.x,point.z)-point.y
			if final_depth<24 or final_depth>=40 or not Profiles.compatible(point,14,10,region,region.get("pockets",[])):continue
			var safe:bool=true
			for z in range(-2,3):
				for x in range(-2,3):
					var cover:float=height.call(point.x+x*7,point.z+z*7)-point.y
					if not is_finite(cover) or cover<minimum_roof+14 or cover>maximum_depth-4:safe=false
			if not safe:continue
			var path:=PackedVector3Array()
			for retained in range(points.size()-1,index-1,-1):path.append(points[retained])
			path.append(join);path.append(point)
			var id:String=str(access.to)+":shallow:0";var proposal:Dictionary=region.duplicate(true);proposal.pockets.append({"id":id,"parent":str(access.to),"point":point,"level":0,"chamber_radius":14.0,"chamber_height":10.0,"shallow_chamber":true});proposal.pocket_passages.append({"from":str(access.to),"to":id,"points":path,"half_width":4.0,"headroom":8.0,"entrance":false,"maximum_grade":absf(grade),"shallow_chamber":true})
			var candidate=Field.new();candidate.maximum_depth=maximum_depth;candidate.minimum_roof=minimum_roof
			if not candidate.compile([proposal],height):continue
			# Protect the old full-width access,including every intermediate2m
			# station. Near-height unions must never excavate its existing floor.
			for segment in range(points.size()-1):
				var a:Vector3=points[segment];var b:Vector3=points[segment+1];var across:=Vector2(-(b-a).z,(b-a).x).normalized();var count:int=maxi(1,ceili(a.distance_to(b)/2))
				for step in range(count+1):
					for offset:float in [-3.5,0.0,3.5]:
						var p:Vector3=a.lerp(b,float(step)/count)+Vector3(across.x,0,across.y)*offset-Vector3.UP*.02
						if original.sample(p)>=0 and candidate.sample(p)<-.001:safe=false;break
					if not safe:break
				if not safe:break
			if safe:return proposal
	return region
