extends RefCounted
## A finite depositional apron follows its actual feeder trunk into the wash.
## The cached frame is worker-owned and shares the drainage tree's lifetime.
static func frame(tree:Dictionary)->PackedFloat64Array:
	if tree.has("fan_frame"):return tree.fan_frame
	var root:Vector3=tree.root;var junction:Vector3=tree.edges[0][1]
	var axis:=Vector2(junction.x-root.x,junction.z-root.z);var length:float=axis.length()
	if length<=.001:return PackedFloat64Array()
	axis/=length
	var result:=PackedFloat64Array([root.x,root.z,axis.x,axis.y,length]);tree.fan_frame=result;return result
static func mask(p:Vector2,tree:Dictionary,span:float)->float:
	var basis:PackedFloat64Array=frame(tree)
	if basis.is_empty():return 0
	var axis:=Vector2(basis[2],basis[3]);var relative:=p-Vector2(basis[0],basis[1])
	var reach:float=minf(span,maxf(32,basis[4]*.85))
	var t:float=1-relative.dot(axis)/maxf(reach,1)
	if t<=0 or t>=1.22:return 0
	var width:float=lerpf(18,320,clampf(t,0,1))
	var across:float=absf(relative.cross(axis))
	return smoothstep(0,.18,t)*(1-smoothstep(1,1.22,t))*(1-smoothstep(.25,1,across/width))
