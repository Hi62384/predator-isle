extends RefCounted
const TRIANGLES_PER_BLOCK:int=64
const CELL_METRES:float=256
const PRELOAD_METRES:float=600
const BIN_METRES:float=1024
const MAX_BINS_PER_BLOCK:int=64
const MAX_CELL:int=2147483646
## Immutable worker-built block index; all selected faces retain original order.
## Real mesh extrema are always retained to preserve native mesh quantization.
static func cell(point:Vector3)->Vector3i:
	return Vector3i(floori(point.x/CELL_METRES),floori(point.y/CELL_METRES),floori(point.z/CELL_METRES))
static func block_bounds(faces:PackedVector3Array)->PackedVector3Array:
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
static func build(faces:PackedVector3Array)->Dictionary:
	if faces.is_empty() or faces.size()%3!=0:return {}
	var bounds:PackedVector3Array=block_bounds(faces)
	if bounds.is_empty():return {}
	var extrema:=PackedInt32Array([-1,-1,-1,-1,-1,-1]);var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF);var bins:Dictionary={};var overflow:=PackedInt32Array()
	for block in range(bounds.size()/2):
		var a:Vector3=bounds[block*2];var b:Vector3=bounds[block*2+1]
		if maxf(maxf(absf(a.x),absf(a.z)),maxf(absf(b.x),absf(b.z)))>MAX_CELL*BIN_METRES:return {}
		if a.x<low.x:low.x=a.x;extrema[0]=block
		if a.y<low.y:low.y=a.y;extrema[1]=block
		if a.z<low.z:low.z=a.z;extrema[2]=block
		if b.x>high.x:high.x=b.x;extrema[3]=block
		if b.y>high.y:high.y=b.y;extrema[4]=block
		if b.z>high.z:high.z=b.z;extrema[5]=block
		var first:=Vector2i(floori(a.x/BIN_METRES),floori(a.z/BIN_METRES));var last:=Vector2i(floori(b.x/BIN_METRES),floori(b.z/BIN_METRES))
		if int(last.x-first.x+1)*int(last.y-first.y+1)>MAX_BINS_PER_BLOCK:overflow.append(block);continue
		for z in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key:=Vector2i(x,z)
				if not bins.has(key):bins[key]=[]
				bins[key].append(block)
	# Build-time Arrays avoid packed-array copy-on-write on every insertion;
	# immutable numeric arrays are the only retained bucket values.
	var references:int=0
	for key:Vector2i in bins:references+=bins[key].size();bins[key]=PackedInt32Array(bins[key])
	return {"version":1,"faces_count":faces.size(),"bounds":bounds,"bins":bins,"overflow":overflow,"extrema":extrema,"references":references}
static func numeric_bytes(metadata:Dictionary)->int:
	if metadata.is_empty():return 0
	return metadata.bounds.size()*12+(metadata.references+metadata.overflow.size()+metadata.extrema.size())*4
static func select(faces:PackedVector3Array,metadata:Dictionary,point:Vector3)->Dictionary:
	var fallback:Dictionary={"faces":faces,"ranges":PackedInt32Array([0,faces.size()]),"fallback":true}
	if metadata.get("version",0)!=1 or metadata.get("faces_count",-1)!=faces.size() or not point.is_finite() or maxf(absf(point.x),maxf(absf(point.y),absf(point.z)))>MAX_CELL*CELL_METRES:return fallback
	if not metadata.get("bounds") is PackedVector3Array or not metadata.get("bins") is Dictionary or not metadata.get("overflow") is PackedInt32Array or not metadata.get("extrema") is PackedInt32Array:return fallback
	var bounds:PackedVector3Array=metadata.bounds;var count:int=ceili(float(faces.size())/(TRIANGLES_PER_BLOCK*3))
	if bounds.size()!=count*2 or metadata.extrema.size()!=6:return fallback
	var origin:Vector3=Vector3(cell(point))*CELL_METRES;var low:Vector3=origin-Vector3.ONE*PRELOAD_METRES;var high:Vector3=origin+Vector3.ONE*(CELL_METRES+PRELOAD_METRES);var first:=Vector2i(floori(low.x/BIN_METRES),floori(low.z/BIN_METRES));var last:=Vector2i(floori(high.x/BIN_METRES),floori(high.z/BIN_METRES))
	var flags:=PackedByteArray();flags.resize(count);flags.fill(0);var chosen:=PackedInt32Array();var groups:Array=[metadata.overflow]
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var key:=Vector2i(x,z)
			if metadata.bins.has(key):
				if not metadata.bins[key] is PackedInt32Array:return fallback
				groups.append(metadata.bins[key])
	for group:PackedInt32Array in groups:
		for block:int in group:
			if block<0 or block>=count:return fallback
			if flags[block]>0:continue
			flags[block]=1;var a:Vector3=bounds[block*2];var b:Vector3=bounds[block*2+1]
			if not a.is_finite() or not b.is_finite() or a.x>b.x or a.y>b.y or a.z>b.z:return fallback
			if a.x<=high.x and b.x>=low.x and a.y<=high.y and b.y>=low.y and a.z<=high.z and b.z>=low.z:flags[block]=2;chosen.append(block)
	for block:int in metadata.extrema:
		if block<0 or block>=count:return fallback
		if flags[block]!=2:flags[block]=2;chosen.append(block)
	chosen.sort();var ranges:=PackedInt32Array()
	for block:int in chosen:
		var begin:int=block*TRIANGLES_PER_BLOCK*3;var end:int=mini(begin+TRIANGLES_PER_BLOCK*3,faces.size())
		if not ranges.is_empty() and ranges[-1]==begin:ranges[-1]=end
		else:ranges.append(begin);ranges.append(end)
	if chosen.size()==count:return {"faces":faces,"ranges":ranges,"fallback":false}
	var selected:=PackedVector3Array()
	for index in range(0,ranges.size(),2):selected.append_array(faces.slice(ranges[index],ranges[index+1]))
	return {"faces":selected,"ranges":ranges,"fallback":false}
