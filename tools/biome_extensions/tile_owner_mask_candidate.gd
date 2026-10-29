extends RefCounted
## Conservative union over every uploaded vertex, including skirts. Interpolated
## triangle controls cannot introduce an owner absent from every endpoint.
static func byte(value:float,index:int)->int:return (int(floor(value))>>(8*index))&255
static func at(data:PackedFloat32Array,stride:int,vertex:int,channel:int)->float:
	return data[vertex*stride+channel] if not data.is_empty() and channel<stride else 0.0
static func mask(arrays:Array,extensions:int)->int:
	var result:int=extensions<<8
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var count:int=arrays[Mesh.ARRAY_VERTEX].size()
	var c0:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
	var c1:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM1] if arrays[Mesh.ARRAY_CUSTOM1]!=null else PackedFloat32Array()
	var c2:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM2] if arrays[Mesh.ARRAY_CUSTOM2]!=null else PackedFloat32Array()
	var c3:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM3] if arrays[Mesh.ARRAY_CUSTOM3]!=null else PackedFloat32Array()
	var stride:int=c0.size()/count
	for i in count:
		var jungle:float=at(c0,stride,i,3)
		if jungle<0:
			jungle=-jungle-1
			if byte(uv[i].y,0)>0:result|=1<<6
		if byte(jungle,2)>0:result|=1
		var forest:float=at(c1,4,i,0);var savanna:float=at(c2,4,i,0);var swamp:float=at(c3,4,i,0)
		if savanna<0:
			if byte(-savanna-1,2)>0:result|=1<<5
			if colors[i].g>0:result|=1<<1
			if colors[i].b>0:result|=1<<2
			if colors[i].a>0:result|=1<<3
		else:
			if byte(forest,2)>0:result|=1<<1
			if byte(savanna,2)>0:result|=1<<2
			if byte(swamp,2)>0:result|=1<<3
		if at(c0,stride,i,0)<0 and byte(at(c0,stride,i,1),2)>0:result|=1<<4
		var coast:float=at(c1,4,i,2)
		if coast<0 and byte(-coast-1,1)>0:result|=1<<7
	return result
