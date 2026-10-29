extends "res://scripts/alien_infected_sampler.gd"
## Isolated landform study: broad grown crust, not another prop/texture system.
var plate_relief:float=72
var _plate_shapes:Dictionary={}
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	super.configure(config,seed_id,host,family_id);_plate_shapes.clear()
func plate_shape(cell:Vector2i,span:float)->Dictionary:
	if _plate_shapes.has(cell):return _plate_shapes[cell]
	var d:Dictionary=descriptor(cell,span);var hive_cell:=Vector2i(floori(d.position.x/(4096*settings.feature_scale)),floori(d.position.y/(4096*settings.feature_scale)))
	var edges:PackedVector2Array=network_edges(hive_cell);var nearest:float=INF;var axis:=Vector2.RIGHT
	for edge in range(0,8,4):
		for i in range(2):
			var distance:float=segment(d.position,edges[edge+i],edges[edge+i+1]).x
			if distance<nearest:nearest=distance;axis=(edges[edge+i+1]-edges[edge+i]).normalized()
	var plane_axis:Vector2=axis.rotated((random(cell.x,cell.y,421)-.5)*.6)
	var shape:Dictionary={"position":d.position,"axis":plane_axis,"length":d.radius*(1.3+random(cell.x,cell.y,422)*.6),"width":d.radius*(.58+random(cell.x,cell.y,423)*.28),"phase":d.angle,"age":d.age,"chance":d.chance,"height_hard":super.evaluate(d.position,2)[0],"height_ancient":super.evaluate(d.position,5)[0],"grade":Vector2((random(cell.x,cell.y,424)-.5)*.28,(random(cell.x,cell.y,425)-.5)*.16)}
	if _plate_shapes.size()>=512:_plate_shapes.clear()
	_plate_shapes[cell]=shape;return shape
func grown_crust(p:Vector2,habit:int)->float:
	var span:float=900*settings.feature_scale;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var weighted_delta:float=0;var total_weight:float=0;var strongest:float=0
	var original:float=super.evaluate(p,habit)[0];var strength:float=plate_relief*minf(settings.feature_scale,1)*(.42 if habit==5 else 1)
	for z in range(-1,2):
		for x in range(-1,2):
			var shape:Dictionary=plate_shape(cell+Vector2i(x,z),span)
			if shape.chance>.45:continue
			var delta:Vector2=p-shape.position;var side:=Vector2(-shape.axis.y,shape.axis.x);var u:float=delta.dot(shape.axis)/shape.length;var v:float=delta.dot(side)/shape.width
			var angle:float=atan2(v,u);var boundary:float=1+.11*sin(angle*3+shape.phase)+.055*sin(angle*7-shape.phase)
			var q:float=Vector2(u,v).length()/boundary
			if q>=1:continue
			# Grow a gently banked crust PLANE into the existing hillside rather
			# than adding another dome. It can flatten/cut a high flank as well as
			# raise a low one. The irregular compact rim returns to unchanged earth.
			var weight:float=1-smoothstep(.55,1,q)
			var center_height:float=shape.height_ancient if habit==5 else shape.height_hard
			var plane:float=center_height+strength*(.18+shape.age*.2)+shape.grade.dot(Vector2(delta.dot(shape.axis),delta.dot(side)))
			# Raised physical armor keels, not a flat geological mesa or shader
			# bump painted onto one. Asymmetric compact ribs taper at their ends.
			var bend:float=.09*u*u*(shape.age-.5);var rib:float=0
			for i in range(3):
				var offset:float=[0.0,-.46,.39][i]+bend;var width:float=[.18,.12,.2][i]
				var distance:float=absf(v-offset)/width
				rib=maxf(rib,pow(maxf(0,1-distance*distance),3)*[.34,.17,.11][i])
			plane+=strength*rib*(1-smoothstep(.5,.95,absf(u)))
			var change:float=clampf(plane-original,-strength*.5,strength)
			weighted_delta+=change*weight;total_weight+=weight;strongest=maxf(strongest,weight)
	return clampf(weighted_delta/maxf(total_weight,.000001)*strongest,-strength*.5,strength)
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var value:PackedFloat64Array=super.evaluate(p,id)
	if plate_relief>0 and id in [2,5]:value[0]+=grown_crust(p,id)
	return value
