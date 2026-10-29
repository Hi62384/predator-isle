extends "res://scripts/badlands_sampler.gd"
## Validation-only reference interpolation, with the SAME current raw geology.
## Never bound by production terrain. Isolates polynomial caching performance.
func _base_sample(x:float,z:float,publish:bool)->float:
	var q:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	if f==Vector2.ZERO:
		var value:PackedFloat64Array=_node(cell)
		if publish:state=value.duplicate()
		return value[0]
	var heights:=PackedFloat64Array();var waters:=PackedFloat64Array()
	for row in range(-1,3):
		var a:PackedFloat64Array=_node(cell+Vector2i(-1,row));var b:PackedFloat64Array=_node(cell+Vector2i(0,row))
		var c:PackedFloat64Array=_node(cell+Vector2i(1,row));var d:PackedFloat64Array=_node(cell+Vector2i(2,row))
		heights.append(cubic(a[0],b[0],c[0],d[0],f.x))
		if publish:waters.append(cubic(a[1],b[1],c[1],d[1],f.x))
	var h:float=cubic(heights[0],heights[1],heights[2],heights[3],f.y)
	if publish:
		var a:PackedFloat64Array=_node(cell);var b:PackedFloat64Array=_node(cell+Vector2i.RIGHT)
		var c:PackedFloat64Array=_node(cell+Vector2i.DOWN);var d:PackedFloat64Array=_node(cell+Vector2i.ONE)
		state=PackedFloat64Array();state.resize(CHANNELS);state[0]=h;state[1]=cubic(waters[0],waters[1],waters[2],waters[3],f.y)
		for i in range(2,CHANNELS):state[i]=clampf(lerpf(lerpf(a[i],b[i],f.x),lerpf(c[i],d[i],f.x),f.y),0,1)
	return h
