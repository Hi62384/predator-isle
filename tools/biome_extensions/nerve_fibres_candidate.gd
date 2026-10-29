extends "res://tools/biome_extensions/reference_pre_fibres_alien_sampler.gd"
## Isolated canonical-field prototype, not registered in the production worker.
var fibre_height:float=24
var _want_frame:bool=false
var _last_frame_point:=Vector2.INF
var _last_frame:Dictionary={}
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	super.configure(config,seed_id,host,family_id);_want_frame=false;_last_frame_point=Vector2.INF;_last_frame={}
func _node(cell:Vector2i)->PackedFloat64Array:
	if fibre_height<=0 or _nodes.has(cell):return super._node(cell)
	# Prepare the frame on the first regional evaluation at this lattice point,
	# including a fringe/nerve blend. Do not project all segments a second time.
	var r:float=region(Vector2(cell)*STEP);var id:int=floori(r);var previous:bool=_want_frame
	_want_frame=id==1 or (id==0 and smoothstep(.25,.75,r-floorf(r))>0)
	var value:PackedFloat64Array=super._node(cell);_want_frame=previous;return value
func network(p:Vector2)->Dictionary:
	if not _want_frame or fibre_height<=0:return super.network(p)
	if _network_cache.has(p) and _last_frame_point==p:return _network_cache[p]
	var span:float=4096*settings.feature_scale;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var trunk:float=INF;var second:float=INF;var branch:float=INF;var center:float=INF;var nearest:=Vector2.ZERO;var identity:String="";var frame:Dictionary={}
	for z in range(-1,2):
		for x in range(-1,2):
			var c:=cell+Vector2i(x,z);var a:Vector2=hive_node(c)
			if p.distance_to(a)<center:center=p.distance_to(a);nearest=a;identity=str(c)
			var edges:PackedVector2Array=network_edges(c)
			for edge in range(0,8,4):
				var b:Vector2=edges[edge+2];var mid:Vector2=edges[edge+1]
				var first:Vector2=segment(p,a,mid);var last:Vector2=segment(p,mid,b);var distance:float=minf(first.x,last.x)
				if distance<trunk:
					second=minf(second,trunk)
					frame={"start":a if first.x<=last.x else mid,"end":mid if first.x<=last.x else b,"t":first.y*.5 if first.x<=last.x else .5+last.y*.5,"cell":c,"edge":edge/4}
				else:second=minf(second,distance)
				trunk=minf(trunk,distance)
				branch=minf(branch,segment(p,mid,edges[edge+3]).x)
	var influence:float=maxf(exp(-trunk/340)*(1-smoothstep(900,1600,trunk)),exp(-branch/110)*.65*(1-smoothstep(400,700,branch)))
	var result:Dictionary={"id":identity,"center":nearest,"center_distance":center,"trunk_distance":trunk,"branch_distance":branch,"influence":influence,"age":.5+.5*macro(p*.25),"underground_geometry":false}
	if not _network_cache.has(p) and _network_cache.size()>=8192:_network_cache.clear()
	_network_cache[p]=result;frame["gap"]=maxf(0,second-trunk);_last_frame=frame;_last_frame_point=p;return result
func fibre_relief(p:Vector2,net:Dictionary)->float:
	var frame:Dictionary=_last_frame;var t:float=frame.t;var scale:float=settings.feature_scale
	var arc:float=sin(t*PI);var taper:float=smoothstep(0,.15,t)*smoothstep(0,.15,1-t)
	var isolation:float=smoothstep(0,100*scale,frame.gap)
	# Use signed distance to the finite polyline, not distance to an infinite
	# segment line: closest-point changes around a bend must not step the field.
	var signed:float=net.trunk_distance*signf((frame.end-frame.start).cross(p-frame.start));var relief:float=0
	for i in range(3):
		var seed_offset:int=380+int(frame.edge)*19+i*3
		var maturity:float=.75+.5*random(frame.cell.x,frame.cell.y,seed_offset)
		var offset:float=[-140.0,90.0,260.0][i]*scale*arc*maturity
		offset+=macro(p*.6)*(30+i*20)*scale*arc*arc
		var width:float=[70.0,90.0,55.0][i]*scale*(.4+.6*arc)*(.8+.4*random(frame.cell.x,frame.cell.y,seed_offset+1))
		var q:float=absf(signed-offset)/maxf(width,.1);var crest:float=pow(maxf(0,1-q*q),3)
		relief=maxf(relief,crest*[1.0,.7,.4][i])
	return fibre_height*minf(scale,1)*relief*taper*isolation*(.6+net.age*.4)
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var previous:bool=_want_frame;_want_frame=_want_frame or (id==1 and fibre_height>0)
	var value:PackedFloat64Array=super.evaluate(p,id)
	if id==1 and fibre_height>0:value[0]+=fibre_relief(p,network(p))
	_want_frame=previous;return value
func nerve_fibre_relief(p:Vector2)->float:
	if fibre_height<=0:return 0
	var previous:bool=_want_frame;_want_frame=true
	var value:float=fibre_relief(p,network(p));_want_frame=previous;return value
