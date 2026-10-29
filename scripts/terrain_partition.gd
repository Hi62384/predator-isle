extends RefCounted
## Spatial selection only. Heights still come from TerrainMeshBuilder.
var base_size:=256.0
var maximum_level:=5
var split_ratio:=1.15
var merge_ratio:=1.50
## Optional bounded fine-detail reservations (for complete cave mouths).
## Empty preserves the original distance-only selection exactly.
var forced_detail_regions:Array[Rect2]=[]
var _root_center:=Vector2i(2147483647,2147483647)

func children(key: Vector3i) -> Array[Vector3i]:
	return [Vector3i(key.x*2,key.y*2,key.z-1),Vector3i(key.x*2+1,key.y*2,key.z-1),Vector3i(key.x*2,key.y*2+1,key.z-1),Vector3i(key.x*2+1,key.y*2+1,key.z-1)]

func bounds(key: Vector3i) -> Rect2:
	var size:=base_size*float(1<<key.z)
	return Rect2(Vector2(key.x,key.y)*size,Vector2.ONE*size)

func distance_to(key: Vector3i,point: Vector2) -> float:
	var rect:=bounds(key)
	return point.distance_to(point.clamp(rect.position,rect.end))

func parent(key: Vector3i) -> Vector3i:
	return Vector3i(floori(key.x/2.0),floori(key.y/2.0),key.z+1)

func adjacent(a: Vector3i,b: Vector3i) -> bool:
	# Integer base-cell units avoid floating-point edge tolerance errors.
	var sa:=1<<a.z;var sb:=1<<b.z
	var ax:=a.x*sa;var az:=a.y*sa;var bx:=b.x*sb;var bz:=b.y*sb
	return ((ax+sa==bx or bx+sb==ax) and maxi(az,bz)<mini(az+sa,bz+sb)) or ((az+sa==bz or bz+sb==az) and maxi(ax,bx)<mini(ax+sa,bx+sb))

func reserved(key:Vector3i)->bool:
	var area:Rect2=bounds(key)
	for region:Rect2 in forced_detail_regions:
		if area.intersects(region):return true
	return false

func select(point: Vector2,previous: Dictionary) -> Dictionary:
	var ancestors: Dictionary={}
	for leaf: Vector3i in previous:
		var p:=leaf
		while p.z<maximum_level:
			p=parent(p);ancestors[p]=true
	var size:=base_size*float(1<<maximum_level)
	var center:=Vector2i(floori(point.x/size),floori(point.y/size))
	if _root_center.x!=2147483647:
		var retained:=Rect2(Vector2(_root_center)*size-Vector2.ONE*size*0.25,Vector2.ONE*size*1.5)
		if retained.has_point(point): center=_root_center
	_root_center=center
	var stack: Array[Vector3i]=[]
	for z in range(-1,2):
		for x in range(-1,2): stack.append(Vector3i(center.x+x,center.y+z,maximum_level))
	var leaves: Dictionary={}
	while not stack.is_empty():
		var key:=stack.pop_back() as Vector3i
		var threshold: float=(merge_ratio if ancestors.has(key) else split_ratio)*base_size*float(1<<key.z)
		if key.z>0 and (distance_to(key,point)<threshold or reserved(key)): stack.append_array(children(key))
		else: leaves[key]=true
	# Query aligned ancestors across each edge. Fine leaves discover coarser
	# neighbors without quadratic all-pairs scans on the main thread.
	while true:
		var split: Dictionary={}
		for key: Vector3i in leaves:
			var width:=1<<key.z;var x:=key.x*width;var z:=key.y*width
			var half:=width/2
			for point_cell in [Vector2i(x-1,z+half),Vector2i(x+width,z+half),Vector2i(x+half,z-1),Vector2i(x+half,z+width)]:
				for level in range(key.z+2,maximum_level+1):
					var span:=float(1<<level)
					var neighbor:=Vector3i(floori(point_cell.x/span),floori(point_cell.y/span),level)
					if leaves.has(neighbor): split[neighbor]=true;break
		if split.is_empty(): break
		for key: Vector3i in split:
			leaves.erase(key)
			for child in children(key): leaves[child]=true
	return leaves
