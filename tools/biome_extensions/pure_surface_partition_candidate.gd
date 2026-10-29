extends RefCounted
## Private experiment: classify ORIGINAL triangles, then copy their original
## packed channels verbatim. No resampling, topology change or texture rewrite.
const Pure=preload("res://tools/biome_extensions/pure_owner_shader_candidate.gd")
static func byte(value:float,index:int)->int:return (int(floor(value))>>(index*8))&255
static func controls(arrays:Array)->Array:
	var count:int=arrays[Mesh.ARRAY_VERTEX].size();var result:Array=[]
	var c0:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0];var stride:int=c0.size()/count
	var channels:Array=[]
	for slot:int in [Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:channels.append(arrays[slot] if arrays[slot]!=null else PackedFloat32Array())
	for i:int in range(count):
		var c:Array=[]
		for channel:PackedFloat32Array in channels:c.append(Vector4(channel[i*4],channel[i*4+1],channel[i*4+2],channel[i*4+3]) if not channel.is_empty() else Vector4.ZERO)
		var jungle:float=c0[i*stride+3] if stride==4 else 0.0;var weights:Array=[byte(-jungle-1 if jungle<0 else jungle,2),0,0,0,byte(c0[i*stride+1],2) if c0[i*stride]<0 else 0,0,0]
		if jungle<0:weights[6]=byte(arrays[Mesh.ARRAY_TEX_UV][i].y,0)
		if c[1].x<0:
			weights[5]=byte(-c[1].x-1,2)
			for legacy:int in range(1,4):weights[legacy]=roundi(arrays[Mesh.ARRAY_COLOR][i][legacy]*255)
		else:
			for legacy:int in range(1,4):weights[legacy]=byte(c[legacy-1].x,2)
		var mask:int=0;var pure:int=Pure.MIXED;var total:int=roundi(arrays[Mesh.ARRAY_COLOR][i].r*255)
		for legacy:int in range(7):
			if weights[legacy]>0:mask|=1<<legacy
			total+=weights[legacy]
		for legacy:int in range(7):
			if weights[legacy]==255 and total==255:pure=1<<legacy
		var coast:int=byte(-c[0].z-1,1) if c[0].z<0 else 0
		if coast>0:mask|=128
		if mask==0 or mask==128:pure=Pure.GRASS_BASE
		result.append({"mask":mask,"base":pure,"coast":coast})
	return result
static func subset(arrays:Array,triangles:PackedInt32Array)->Array:
	var remap:Dictionary={};var old_vertices:PackedInt32Array=[];var indices:=PackedInt32Array()
	for old:int in triangles:
		if not remap.has(old):remap[old]=old_vertices.size();old_vertices.append(old)
		indices.append(remap[old])
	var count:int=arrays[Mesh.ARRAY_VERTEX].size();var result:Array=[];result.resize(Mesh.ARRAY_MAX)
	for slot:int in range(Mesh.ARRAY_INDEX):
		if arrays[slot]==null:continue
		var original=arrays[slot];var packed=original.duplicate();packed.resize(0)
		var stride:int=original.size()/count
		assert(stride*count==original.size())
		for old:int in old_vertices:
			for channel:int in range(stride):packed.append(original[old*stride+channel])
		result[slot]=packed
	result[Mesh.ARRAY_INDEX]=indices;return result
static func partition(arrays:Array,span:float,data:PackedByteArray,rows:int,extensions:int)->Array:
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var controls_by_vertex:Array=controls(arrays)
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var groups:Dictionary={};var cell_cache:Dictionary={}
	var width:int=data.size()/(rows*4) if rows>0 else 0
	for first:int in range(0,indices.size(),3):
		var triangle:PackedInt32Array=indices.slice(first,first+3);var mask:int=0;var base:int=controls_by_vertex[triangle[0]].base;var coast_all:bool=true;var coast_any_full:bool=false
		var low:=Vector2(INF,INF);var high:Vector2=Vector2(-INF,-INF)
		for index:int in triangle:
			var control:Dictionary=controls_by_vertex[index];mask|=control.mask
			if base!=control.base:base=Pure.MIXED
			coast_all=coast_all and control.coast==255;coast_any_full=coast_any_full or control.coast==255
			var point:=Vector2(vertices[index].x,vertices[index].z)/span*maxi(rows-1,0);low=low.min(point);high=high.max(point)
		var extension_mask:int=0;var saturated:bool=rows>0 and extensions!=0
		if rows>0 and extensions!=0:
			# Include every bilinear atlas sample in the triangle's XZ rectangle,
			# including the fourth corner absent from its three mesh vertices.
			var a:Vector2i=Vector2i(floori(low.x-.0001),floori(low.y-.0001)).clamp(Vector2i.ZERO,Vector2i.ONE*(rows-1))
			var b:Vector2i=Vector2i(ceili(high.x+.0001),ceili(high.y+.0001)).clamp(Vector2i.ZERO,Vector2i.ONE*(rows-1))
			for z:int in range(a.y,b.y+1):
				for x:int in range(a.x,b.x+1):
					var cell:=Vector2i(x,z)
					if not cell_cache.has(cell):
						var local_mask:int=0;var total:int=0
						for family:int in range(8):
							if (extensions & (1<<family))==0:continue
							var weight:int=data[(z*width+family*rows+x)*4];total+=weight
							if weight>0:local_mask|=1<<(family+8)
						cell_cache[cell]=Vector2i(local_mask,total)
					extension_mask|=cell_cache[cell].x;saturated=saturated and cell_cache[cell].y>=255
		mask|=extension_mask
		# A partial overlay may cross the original .999 fast-path threshold
		# inside a triangle. Retain that ordered selector unless saturation is
		# proved over its entire atlas rectangle or coast owns every vertex.
		if coast_all:base=Pure.COAST_BASE;mask=128
		elif saturated and not coast_any_full:base=Pure.ZERO_BASE;mask=extension_mask|(mask&128)
		var key:=Vector2i(mask,base)
		if not groups.has(key):groups[key]=PackedInt32Array()
		groups[key].append_array(triangle)
	var result:Array=[]
	for key:Vector2i in groups:result.append({"mask":key.x,"base":key.y,"arrays":subset(arrays,groups[key])})
	return result
