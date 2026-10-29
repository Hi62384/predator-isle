extends RefCounted
## Keep actual extremal source blocks as well as all nearby triangles. This
## retains mesh-wide quantization bounds without invented/dummy geometry.
const Base=preload("res://tools/biome_extensions/structure_collision_blocks_candidate.gd")
const TRIANGLES_PER_BLOCK:int=64
const CELL_METRES:float=256
const PRELOAD_METRES:float=600
static func build(faces:PackedVector3Array)->PackedVector3Array:return Base.build(faces)
static func cell(point:Vector3)->Vector3i:return Base.cell(point)
static func select(faces:PackedVector3Array,bounds:PackedVector3Array,point:Vector3)->Dictionary:
	var expected:int=ceili(float(faces.size())/(TRIANGLES_PER_BLOCK*3))*2
	if faces.size()%3!=0 or bounds.size()!=expected or not point.is_finite():return {"faces":faces,"ranges":PackedInt32Array([0,faces.size()]),"fallback":true}
	if faces.is_empty():return {"faces":faces,"ranges":PackedInt32Array(),"fallback":false,"extremal_blocks":PackedInt32Array()}
	var origin:Vector3=Vector3(cell(point))*CELL_METRES;var low:Vector3=origin-Vector3.ONE*PRELOAD_METRES;var high:Vector3=origin+Vector3.ONE*(CELL_METRES+PRELOAD_METRES)
	var chosen:=PackedByteArray();chosen.resize(bounds.size()/2);chosen.fill(0);var extrema:=PackedInt32Array([-1,-1,-1,-1,-1,-1]);var original_low:=Vector3(INF,INF,INF);var original_high:=Vector3(-INF,-INF,-INF)
	for block in range(bounds.size()/2):
		var a:Vector3=bounds[block*2];var b:Vector3=bounds[block*2+1]
		if not a.is_finite() or not b.is_finite() or a.x>b.x or a.y>b.y or a.z>b.z:return {"faces":faces,"ranges":PackedInt32Array([0,faces.size()]),"fallback":true}
		if a.x<original_low.x:original_low.x=a.x;extrema[0]=block
		if a.y<original_low.y:original_low.y=a.y;extrema[1]=block
		if a.z<original_low.z:original_low.z=a.z;extrema[2]=block
		if b.x>original_high.x:original_high.x=b.x;extrema[3]=block
		if b.y>original_high.y:original_high.y=b.y;extrema[4]=block
		if b.z>original_high.z:original_high.z=b.z;extrema[5]=block
		if a.x<=high.x and b.x>=low.x and a.y<=high.y and b.y>=low.y and a.z<=high.z and b.z>=low.z:chosen[block]=1
	for block:int in extrema:chosen[block]=1
	var ranges:=PackedInt32Array();var count:int=0
	for block in range(chosen.size()):
		if chosen[block]==0:continue
		var first:int=block*TRIANGLES_PER_BLOCK*3;var last:int=mini(first+TRIANGLES_PER_BLOCK*3,faces.size());ranges.append(first);ranges.append(last);count+=last-first
	if count==faces.size():return {"faces":faces,"ranges":ranges,"fallback":false,"extremal_blocks":extrema}
	# Native packed-array copies avoid a per-vertex GDScript main-thread loop.
	var selected:=PackedVector3Array()
	for range_id in range(0,ranges.size(),2):selected.append_array(faces.slice(ranges[range_id],ranges[range_id+1]))
	return {"faces":selected,"ranges":ranges,"fallback":false,"extremal_blocks":extrema}
