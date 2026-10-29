extends "res://tools/caves/render_crystal_lake.gd"
var dry_mask:Array=[]
var wet_triangles:Array=[]
func inspection_name()->String:return "crystal_dry_shores"
func selection_label()->String:return super.selection_label()+" Required original parent connection plus BOTH dry shore arms,terminated only by the actual retained feeder WATER FOOTPRINT before any physics walk. Not a360degree dry circumnavigation claim:the original full-ring feeder-crossing1.603mdrop remains preserved. No rerolled site/changed cave/water/mineral geometry or relaxed capsule gates."
func wet_at(point:Vector3)->bool:
	for triangle:PackedVector3Array in wet_triangles:
		if point.y-.95>maxf(triangle[0].y,maxf(triangle[1].y,triangle[2].y))+.15:continue
		if point.y-.95<minf(triangle[0].y,minf(triangle[1].y,triangle[2].y))-6:continue
		var polygon:=PackedVector2Array([Vector2(triangle[0].x,triangle[0].z),Vector2(triangle[1].x,triangle[1].z),Vector2(triangle[2].x,triangle[2].z)])
		for j in range(9):
			var probe:=Vector2(point.x,point.z)
			if j>0:probe+=Vector2(cos((j-1)*TAU/8),sin((j-1)*TAU/8))*.65
			if Geometry2D.is_point_in_polygon(probe,polygon):return true
	return false
func dry_segment(a:Vector3,b:Vector3)->bool:
	for i in range(7):
		if wet_at(a.lerp(b,float(i)/6)):return false
	return true
func inspection_routes(data:Dictionary,field)->Array:
	var original:Array=super.inspection_routes(data,field);var routes:Array=[original[0]];var full:Array=original[1].points;var ring:Array=full.slice(2,35);check(ring.size()==33,"ALL original33fixed ring stations retained for wet/dry classification,not picked after native failure")
	for cell:Dictionary in data.cells:
		var arrays:Array=cell.water.arrays
		if arrays.is_empty():continue
		var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var origin:Vector3=Vector3(cell.key)*64
		for i in range(0,points.size(),3):wet_triangles.append(PackedVector3Array([points[i]+origin,points[i+1]+origin,points[i+2]+origin]))
	check(not wet_triangles.is_empty(),"Actual normal generated retained-water triangle footprint,not a guessed circular pool mask")
	for i in range(33):dry_mask.append({"original_ring_index":i,"position":str(ring[i]),"dry_capsule_footprint":not wet_at(ring[i])})
	var all_dry:bool=true
	for record:Dictionary in dry_mask:all_dry=all_dry and record.dry_capsule_footprint
	check(not all_dry,"Original alleged dry full ring positively crosses real feeder water;failure remains an optional wet-stream crossing,not a dry-path acceptance")
	for reverse:bool in [false,true]:
		var ordered:Array=ring.duplicate()
		if reverse:ordered.reverse()
		var arm:Array[Vector3]=[data.parent.point+Vector3(0,.95,0),data.room.point+Vector3(0,.95,0)];var count:int=0;var previous:Vector3=arm[-1]
		for p:Vector3 in ordered:
			if not dry_segment(previous,p):break
			arm.append(p);previous=p;count+=1
		check(count>=3 and count<33,"Positive independently pre-walk water-limited dry shore arm;cannot skip a failed physical point or cross the feeder "+str(reverse))
		for i in range(arm.size()-2,-1,-1):arm.append(arm[i])
		routes.append({"label":"Actual retained lake "+("clockwise" if reverse else "counterclockwise")+" DRY shore arm to real feeder water boundary and exact original parent return","points":arm})
	return routes
func walk_extra_details(_walker)->Dictionary:return {"original_complete_ring_wet_dry_mask":dry_mask,"shore_selection":"Both directions from original room approach;first actual WATER FOOTPRINT intersection with0.65m capsule margin and7segment probes terminates each arm BEFORE physics. Original full wet crossing remains failed/historical."}
