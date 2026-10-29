extends RefCounted
## Private index only. Original vertices/order are never changed or clipped.
## Contiguous geometric blocks cost24bytes per64triangles,not a per-face map.
const TRIANGLES_PER_BLOCK:int=64
const CELL_METRES:float=256
const PRELOAD_METRES:float=600
static func build(faces:PackedVector3Array)->PackedVector3Array:
	var bounds:=PackedVector3Array()
	if faces.size()%3!=0:return bounds
	for start:int in range(0,faces.size(),TRIANGLES_PER_BLOCK*3):
		var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
		for index in range(start,mini(start+TRIANGLES_PER_BLOCK*3,faces.size())):
			var point:Vector3=faces[index]
			if not point.is_finite():return PackedVector3Array()
			low=low.min(point);high=high.max(point)
		bounds.append(low);bounds.append(high)
	return bounds
static func cell(point:Vector3)->Vector3i:
	return Vector3i(floori(point.x/CELL_METRES),floori(point.y/CELL_METRES),floori(point.z/CELL_METRES))
static func select(faces:PackedVector3Array,bounds:PackedVector3Array,point:Vector3)->Dictionary:
	var expected:int=ceili(float(faces.size())/(TRIANGLES_PER_BLOCK*3))*2
	if faces.size()%3!=0 or bounds.size()!=expected or not point.is_finite():return {"faces":faces,"ranges":PackedInt32Array([0,faces.size()]),"fallback":true}
	if faces.is_empty():return {"faces":faces,"ranges":PackedInt32Array(),"fallback":false}
	var origin:Vector3=Vector3(cell(point))*CELL_METRES;var low:Vector3=origin-Vector3.ONE*PRELOAD_METRES;var high:Vector3=origin+Vector3.ONE*(CELL_METRES+PRELOAD_METRES);var ranges:=PackedInt32Array();var count:int=0
	for block in range(bounds.size()/2):
		var a:Vector3=bounds[block*2];var b:Vector3=bounds[block*2+1]
		if not a.is_finite() or not b.is_finite() or a.x>b.x or a.y>b.y or a.z>b.z:return {"faces":faces,"ranges":PackedInt32Array([0,faces.size()]),"fallback":true}
		# Inclusive conservative box overlap,including zero-thickness floors.
		if a.x>high.x or b.x<low.x or a.y>high.y or b.y<low.y or a.z>high.z or b.z<low.z:continue
		var first:int=block*TRIANGLES_PER_BLOCK*3;var last:int=mini(first+TRIANGLES_PER_BLOCK*3,faces.size());ranges.append(first);ranges.append(last);count+=last-first
	if count==faces.size():return {"faces":faces,"ranges":ranges,"fallback":false}
	var selected:=PackedVector3Array();selected.resize(count);var cursor:int=0
	for range_id in range(0,ranges.size(),2):
		for index in range(ranges[range_id],ranges[range_id+1]):selected[cursor]=faces[index];cursor+=1
	return {"faces":selected,"ranges":ranges,"fallback":false}
