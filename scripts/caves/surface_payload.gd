extends RefCounted
## Cave core: surface replacement transport. Decode every packed control BEFORE
## barycentric interpolation. A float24 integer is never a linear attribute.
## Sixty-seven semantic floats plus one pad = seventeen RGBAF texels/vertex.
const STRIDE:int=68
const TEXELS:int=17
const WIDTH:int=1024
const MAX_BYTES:int=16777216
static func unpack24(value:float)->Vector3:
	var n:int=floori(value);return Vector3(float(n&255)/255,float((n>>8)&255)/255,float(n>>16)/255)
static func channel(arrays:Array,slot:int,index:int,count:int)->PackedFloat32Array:
	var result:=PackedFloat32Array();result.resize(count)
	if arrays[slot]==null:return result
	var source:PackedFloat32Array=arrays[slot];var stride:int=source.size()/arrays[Mesh.ARRAY_VERTEX].size()
	for i in range(count):result[i]=source[index*stride+i] if i<stride else (1.0 if i==3 else 0.0)
	return result
static func decode(arrays:Array,index:int,extension_normalization:bool=false)->PackedFloat32Array:
	if arrays.size()!=Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX]==null or index<0 or index>=arrays[Mesh.ARRAY_VERTEX].size():return PackedFloat32Array()
	var c0:PackedFloat32Array=channel(arrays,Mesh.ARRAY_CUSTOM0,index,4);var c1:PackedFloat32Array=channel(arrays,Mesh.ARRAY_CUSTOM1,index,4);var c2:PackedFloat32Array=channel(arrays,Mesh.ARRAY_CUSTOM2,index,4);var c3:PackedFloat32Array=channel(arrays,Mesh.ARRAY_CUSTOM3,index,4)
	var color:Color=arrays[Mesh.ARRAY_COLOR][index];var uv:Vector2=arrays[Mesh.ARRAY_TEX_UV][index];var uv2:Vector2=arrays[Mesh.ARRAY_TEX_UV2][index]
	# Native Godot4.6.1 ARRAY_COLOR upload truncates float colors to RGBA8.
	# Match those actual inputs once,then carry interpolated colors as RGBAF
	# so replacement vertices do not quantize the already-decoded values twice.
	for i in range(4):color[i]=float(clampi(int(color[i]*255),0,255))/255
	var geology:=Vector3(c0[0],c0[1],c0[2]);var jungle:Vector3=unpack24(c0[3]);var badlands:=Vector2.ZERO
	if c0[3]<0:
		jungle=unpack24(-c0[3]-1);var b:Vector3=unpack24(uv.y);badlands=Vector2(b.x,b.y);uv.y=(roundf(b.z*255)-127)/254
	var forest:Vector3=unpack24(c1[0]);var ecology:Vector3=unpack24(c1[1]);var forest_geology:=Vector2(c1[2],c1[3]);var coast:=Vector3.ZERO;var sediment:float=0;var beach:=Vector2.ZERO
	if c1[2]<0:
		var a:Vector3=unpack24(-c1[2]-1);var b:Vector3=unpack24(c1[3]);forest_geology=Vector2(a.x,b.x);coast=Vector3(a.y,a.z,b.y);sediment=b.z
		if c1[3]<0:b=unpack24(-c1[3]-1);forest_geology.y=b.x;beach=Vector2(b.y,b.z);coast.z=.5;sediment=0
	var savanna:Vector3=unpack24(c2[0]);var savanna_geology:Vector3=unpack24(c2[1]);var savanna_water:Vector3=unpack24(c2[2]);var savanna_surface:Vector3=unpack24(c2[3]);var swamp:Vector3=unpack24(c3[0]);var hydro:Vector3=unpack24(c3[1]);var land:Vector3=unpack24(c3[2]);var swamp_ecology:Vector3=unpack24(c3[3]);var tropical:=Vector3.ZERO
	if c2[0]<0:
		var s:Vector3=unpack24(-c2[0]-1);var w:Vector3=unpack24(-c3[0]-1);var f:Vector3=unpack24(-c1[0]-1);tropical=Vector3(s.z,w.z,f.z);savanna=Vector3(s.x,s.y,roundf(color.b*255)/255);swamp=Vector3(w.x,w.y,roundf(color.a*255)/255);forest=Vector3(f.x,f.y,roundf(color.g*255)/255)
	var mountain:=Vector3.ZERO;var mountain_geology:=Vector3.ZERO;var mountain_shape:=Vector3.ZERO;var mountain_wet:float=0;var surface:Vector2=uv2
	if c0[0]<0:
		geology=unpack24(-c0[0]-1);mountain=unpack24(c0[1]);mountain_geology=unpack24(c0[2]);var a:Vector3=unpack24(uv2.x);var b:Vector3=unpack24(uv2.y);surface=Vector2(a.x,a.y);mountain_shape=Vector3(a.z,b.x,b.y);mountain_wet=b.z
	if extension_normalization:
		var total:float=color.r+jungle.z+forest.z+savanna.z+swamp.z+mountain.z+tropical.x+badlands.x
		if total>.0001:jungle.z/=total;forest.z/=total;savanna.z/=total;swamp.z/=total;mountain.z/=total;tropical.x/=total;badlands.x/=total
	var result:=PackedFloat32Array()
	for value in [geology,jungle,forest,ecology,forest_geology,savanna,savanna_geology,savanna_water,savanna_surface,swamp,hydro,land,swamp_ecology,mountain,mountain_geology,mountain_shape,mountain_wet,surface,coast,sediment,beach,tropical,badlands,uv.x,uv.y]:
		if value is Vector3:result.append_array(PackedFloat32Array([value.x,value.y,value.z]))
		elif value is Vector2:result.append_array(PackedFloat32Array([value.x,value.y]))
		else:result.append(value)
	assert(result.size()==63)
	for i in range(4):result.append(color[i])
	result.append(0);return result
static func triangle(local:Vector2,span:float,resolution:int)->Dictionary:
	if not local.is_finite() or not is_finite(span) or span<=0 or resolution<1 or local.x<0 or local.y<0 or local.x>span or local.y>span:return {}
	var q:Vector2=local/float(span)*resolution;var x:int=mini(floori(q.x),resolution-1);var z:int=mini(floori(q.y),resolution-1);var fx:float=q.x-x;var fz:float=q.y-z;var a:int=z*(resolution+1)+x
	if fx+fz<=1:return {"indices":PackedInt32Array([a,a+1,a+resolution+1]),"weights":Vector3(1-fx-fz,fx,fz)}
	return {"indices":PackedInt32Array([a+1,a+resolution+2,a+resolution+1]),"weights":Vector3(1-fz,fx+fz-1,1-fx)}
static func interpolate(decoded:Array,selection:Dictionary)->PackedFloat32Array:
	if selection.is_empty():return PackedFloat32Array()
	var indices:PackedInt32Array=selection.indices;var weights:Vector3=selection.weights;var result:=PackedFloat32Array();result.resize(STRIDE)
	for corner in range(3):
		if indices[corner]<0 or indices[corner]>=decoded.size() or decoded[indices[corner]].size()!=STRIDE:return PackedFloat32Array()
		for component in range(STRIDE):result[component]+=float(decoded[indices[corner]][component])*weights[corner]
	return result
static func atlas(values:PackedFloat32Array)->Dictionary:
	if values.is_empty() or values.size()%STRIDE!=0 or values.size()*4>MAX_BYTES:return {}
	var rows:int=ceili(float(values.size())/(WIDTH*4));var size:int=WIDTH*rows*16
	if size>MAX_BYTES:return {}
	# Resize the final bytes,not an extra full float copy. New byte padding
	# is exactly IEEE754 positive zero,as in the original padded float atlas.
	var bytes:PackedByteArray=values.to_byte_array();bytes.resize(size)
	return {"width":WIDTH,"height":rows,"bytes":bytes,"vertices":values.size()/STRIDE,"semantic_components":67,"texels_per_vertex":TEXELS}
