extends RefCounted
## PRIVATE sparse implicit union; no SceneTree/GPU access. One common volume
## removes internal walls at joins. Floor planes are not noisy circular pipes.
const BIN_METRES:float=16
const FAR:float=4
const MAX_FEATURES:int=65536
var begins:=PackedVector3Array()
var ends:=PackedVector3Array()
var dimensions:=PackedVector2Array()
var kinds:=PackedByteArray() # 0 closed route,1 intentional entrance,2 chamber
var bins:Dictionary={}
var chunks:Dictionary={}
var height:Callable
var maximum_depth:float=400
var minimum_roof:float=10
var references:int=0
func clear()->void:
	begins.clear();ends.clear();dimensions.clear();kinds.clear();bins.clear();chunks.clear();references=0
func cell(point:Vector3)->Vector3i:return Vector3i(floori(point.x/64),floori(point.y/64),floori(point.z/64))
func bin_cell(point:Vector3)->Vector3i:return Vector3i(floori(point.x/BIN_METRES),floori(point.y/BIN_METRES),floori(point.z/BIN_METRES))
func has_chunk(key:Vector3i)->bool:return chunks.has(key)
func append_feature(a:Vector3,b:Vector3,size:Vector2,kind:int)->bool:
	if not a.is_finite() or not b.is_finite() or not size.is_finite() or size.x<=0 or size.y<=0 or begins.size()>=MAX_FEATURES:return false
	var low:Vector3=a.min(b)-Vector3(size.x+FAR,FAR,size.x+FAR);var high:Vector3=a.max(b)+Vector3(size.x+FAR,size.y+FAR,size.x+FAR)
	for component:float in [low.x,low.y,low.z,high.x,high.y,high.z]:
		if absf(component)>2147483646.0*BIN_METRES:return false
	var first:Vector3i=bin_cell(low);var last:Vector3i=bin_cell(high)
	if int(last.x-first.x+1)*int(last.y-first.y+1)*int(last.z-first.z+1)>128:return false
	var feature:int=begins.size();begins.append(a);ends.append(b);dimensions.append(size);kinds.append(kind)
	var first_chunk:Vector3i=cell(low);var last_chunk:Vector3i=cell(high)
	for z in range(first_chunk.z,last_chunk.z+1):
		for y in range(first_chunk.y,last_chunk.y+1):
			for x in range(first_chunk.x,last_chunk.x+1):chunks[Vector3i(x,y,z)]=true
	for z in range(first.z,last.z+1):
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key:=Vector3i(x,y,z)
				if not bins.has(key):bins[key]=[]
				bins[key].append(feature)
	return true
func compile(regions:Array,surface:Callable,extra_edges:Array=[])->bool:
	clear();height=surface
	if not surface.is_valid():return false
	var edges:Array=extra_edges.duplicate()
	for region:Dictionary in regions:
		if not region.get("valid",false):continue
		edges.append_array(region.edges)
		for node:Dictionary in region.nodes:
			if int(node.get("level",-1))<0:continue
			if not append_feature(node.point,node.point,Vector2(node.chamber_radius,node.chamber_height),2):clear();return false
	for edge:Dictionary in edges:
		var points:PackedVector3Array=edge.points
		for i in range(points.size()-1):
			if not append_feature(points[i],points[i+1],Vector2(edge.half_width,edge.headroom),1 if edge.entrance else 0):clear();return false
	for key:Vector3i in bins:references+=bins[key].size();bins[key]=PackedInt32Array(bins[key])
	return true
func evaluate(point:Vector3,features:PackedInt32Array)->float:
	var closed:float=FAR;var opening:float=FAR
	var wall:float=sin(point.x*.71+sin(point.y*.23))*sin(point.z*.53+point.y*.41)*.12
	for feature:int in features:
		var a:Vector3=begins[feature];var b:Vector3=ends[feature];var size:Vector2=dimensions[feature];var floor_y:float=a.y;var radius_distance:float=0
		if kinds[feature]==2:radius_distance=Vector2(point.x-a.x,point.z-a.z).length()
		else:
			var ab:=Vector2(b.x-a.x,b.z-a.z);var q:=Vector2(point.x-a.x,point.z-a.z);var along:float=q.dot(ab)/maxf(ab.length_squared(),.000001);var t:float=clampf(along,0,1)
			# Continue the sloping floor plane through the rounded segment caps.
			# Clamping the floor to the lower endpoint made each cap cut a small
			# horizontal shelf/drop out of its uphill neighbor in the air union.
			radius_distance=(q-ab*t).length();floor_y=lerpf(a.y,b.y,along)
		var y:float=point.y-floor_y;var arch:float=(Vector2(radius_distance/size.x,(y-size.y*.4)/(size.y*.6)).length()-1)*minf(size.x,size.y*.6)
		var value:float=maxf(-y,arch+wall)
		if kinds[feature]==1:opening=minf(opening,value)
		else:closed=minf(closed,value)
	if minf(closed,opening)>=FAR:return FAR
	var ground:float=height.call(point.x,point.z)
	if not is_finite(ground):return FAR
	var depth:float=ground-point.y
	return minf(FAR,maxf(minf(maxf(closed,minimum_roof-depth),opening),depth-maximum_depth))
func sample(point:Vector3)->float:
	if not point.is_finite():return FAR
	for component:float in [point.x,point.y,point.z]:
		if absf(component)>2147483646.0*BIN_METRES:return FAR
	var key:Vector3i=bin_cell(point)
	if not bins.has(key):return FAR
	return evaluate(point,bins[key])
func normal(point:Vector3)->Vector3:
	var e:float=.125
	# Negative gradient points from solid rock into the navigable air volume.
	return -Vector3(sample(point+Vector3(e,0,0))-sample(point-Vector3(e,0,0)),sample(point+Vector3(0,e,0))-sample(point-Vector3(0,e,0)),sample(point+Vector3(0,0,e))-sample(point-Vector3(0,0,e))).normalized()
func numeric_bytes()->int:return begins.size()*33+references*4
