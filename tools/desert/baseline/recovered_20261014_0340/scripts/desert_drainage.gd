extends RefCounted
## Finite, rooted dry catchments. Every tributary ends on a parent junction.
## Descriptor creation and tile culling are bounded; there is no live simulation.
const TILE: float = 1024.0
const MAX_TILES: int = 512
var settings: DesertSettings
var seed_value: int
var _catchments: Dictionary = {}
var _tiles: Dictionary = {}
var _last_tile := Vector2i(2147483647,2147483647)
var _near: Array = []
var last_floor: float = 4.0
var last_fan_lift: float = 0.0

func configure(config: DesertSettings, seed_number: int) -> void:
	settings=config;seed_value=seed_number
	_catchments.clear();_tiles.clear()
	_last_tile=Vector2i(2147483647,2147483647)

func _hash(x: int,z: int,salt: int) -> float:
	var h: int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0

func _curve(a: Vector2, b: Vector2, bend: float, _segments: int, floor_a: float, floor_b: float, width: float) -> Array:
	# One analytic arc; no visible polygon corners from a coarse polyline.
	var delta: Vector2=b-a
	var bend_vector:=Vector2(-delta.y,delta.x).normalized()*bend
	var bounds := Rect2(a,Vector2.ZERO).expand(b).grow(1250.0+absf(bend))
	var reach: float = 1250.0+absf(bend)
	# Extra margin conservatively covers float32 endpoint/interpolation roundoff.
	var margin: float = maxf(1.0,maxf(maxf(absf(a.x),absf(a.y)),maxf(absf(b.x),absf(b.y)))*0.000001)
	var point_bounds: Rect2 = bounds.grow(margin)
	return [[a,b,floor_a,floor_b,width,bend,bend_vector,delta,maxf(delta.length_squared(),1.0),bounds,reach*reach,-bend_vector*8.0,point_bounds]]

func _catchment(cell: Vector2i, source: RefCounted) -> Array:
	if _catchments.has(cell):return _catchments[cell]
	var span: float=maxf(settings.basin_size*5.0,6000.0)
	var root: Vector2=(Vector2(cell)+Vector2.ONE*0.5)*span
	var best: float=INF
	# Prefer a real low regional basin, not an arbitrary circular depression.
	for i in range(5):
		var p: Vector2=(Vector2(cell)+Vector2(0.30+_hash(cell.x,cell.y,301+i*2)*0.40,0.30+_hash(cell.x,cell.y,302+i*2)*0.40))*span
		var w: PackedFloat32Array=source.region_weights(p.x,p.y)
		var potential: float=source._macro.get_noise_2d(p.x,p.y)-(w[3]+w[6])*0.6+(w[4]+w[2])*0.25
		if potential<best:best=potential;root=p
	var edges: Array=[]
	var fans: Array=[]
	# A single asymmetric trunk collects staggered tributaries. Unlike radial
	# spokes, each ordinary junction is only a three-way confluence.
	var inset: float=span*0.08
	var minimum: Vector2=Vector2(cell)*span+Vector2.ONE*inset
	var maximum: Vector2=Vector2(cell+Vector2i.ONE)*span-Vector2.ONE*inset
	var head: Vector2=root
	var head_score: float=-INF
	for i in range(9):
		var p: Vector2=(Vector2(cell)+Vector2(0.08+_hash(cell.x,cell.y,321+i*2)*0.84,0.08+_hash(cell.x,cell.y,322+i*2)*0.84))*span
		var w: PackedFloat32Array=source.region_weights(p.x,p.y)
		var score: float=p.distance_to(root)/span+(w[2]+w[4]+w[5])*0.23-(w[3]+w[6])*0.18
		if score>head_score:head_score=score;head=p
	var direction: Vector2=(head-root).normalized()
	var normal:=Vector2(-direction.y,direction.x)
	var length: float=root.distance_to(head)
	var segments: int=4+int(_hash(cell.x,cell.y,317)*2.0)
	var points: Array[Vector2]=[root]
	var floors: Array[float]=[3.5]
	for i in range(1,segments+1):
		var fraction: float=(float(i)+(_hash(cell.x,cell.y,341+i)-0.5)*0.38)/segments if i<segments else 1.0
		var side: float=(_hash(cell.x,cell.y,351+i)-0.5)*length*0.12*sin(fraction*PI)
		points.append((root.lerp(head,fraction)+normal*side).clamp(minimum,maximum))
		floors.append(3.5+fraction*4.5)
		var width: float=lerpf(76.0,28.0,fraction)
		var bend: float=(_hash(cell.x,cell.y,371+i)-0.5)*length*0.035
		edges.append_array(_curve(points[i-1],points[i],bend,4,floors[i-1],floors[i],width))
	var first_side: float=-1.0 if _hash(cell.x,cell.y,391)<0.5 else 1.0
	for branch in range(1,segments):
		var side: float=first_side*(1.0 if branch%2==0 else -1.0)
		var junction: Vector2=points[branch]
		var reach: float=span*lerpf(0.12,0.23,_hash(cell.x,cell.y,401+branch))
		var upstream: Vector2=(junction+normal*side*reach+direction*reach*lerpf(0.12,0.62,_hash(cell.x,cell.y,441+branch))).clamp(minimum,maximum)
		var join: Vector2=junction.lerp(upstream,lerpf(0.42,0.64,_hash(cell.x,cell.y,411+branch)))
		var bend: float=(_hash(cell.x,cell.y,421+branch)-0.5)*reach*0.16
		var floor: float=floors[branch]
		edges.append_array(_curve(junction,join,bend,4,floor,floor+0.85,34.0))
		edges.append_array(_curve(join,upstream,-bend*0.6,4,floor+0.85,floor+1.8,20.0))
		# One smaller headwater joins this tributary rather than the main root.
		if branch==1:
			var twig: Vector2=(join+direction*reach*0.52+normal*side*reach*0.16).clamp(minimum,maximum)
			edges.append_array(_curve(join,twig,bend*0.4,3,floor+0.85,floor+2.0,14.0))
		var up: PackedFloat32Array=source.region_weights(upstream.x,upstream.y)
		var down: PackedFloat32Array=source.region_weights(junction.x,junction.y)
		var gate: float=clampf((up[2]+up[4]+up[5])*(down[3]+down[6])*2.0,0.0,1.0)
		if gate>0.06:
			fans.append([join,(junction-join).normalized(),minf(reach*0.60,1400.0),gate])
	var result: Array=[edges,fans]
	if _catchments.size()>=128:_catchments.clear()
	_catchments[cell]=result
	return result

func _nearby(tile: Vector2i,source: RefCounted) -> Array:
	if _tiles.has(tile):return _tiles[tile]
	var bounds:=Rect2(Vector2(tile)*TILE,Vector2.ONE*TILE)
	var span: float=maxf(settings.basin_size*5.0,6000.0)
	var p: Vector2=bounds.get_center()
	var center:=Vector2i(floori(p.x/span),floori(p.y/span))
	var edges: Array=[]
	var fans: Array=[]
	for dz in range(-1,2):
		for dx in range(-1,2):
			var cell: Vector2i=center+Vector2i(dx,dz)
			# Descriptor endpoints/curves stay within this conservative basin bound.
			if not Rect2(Vector2(cell)*span,Vector2.ONE*span).grow(span*0.20+1250.0).intersects(bounds,true):continue
			var descriptor: Array=_catchment(cell,source)
			for edge: Array in descriptor[0]:
				var box: Rect2 = edge[9]
				if box.intersects(bounds,true):edges.append(edge)
			for fan: Array in descriptor[1]:
				var radius: float=sqrt(float(fan[2])*float(fan[2])+pow(float(fan[2])*0.65+35.0,2.0))
				var box:=Rect2(fan[0]-Vector2.ONE*radius,Vector2.ONE*radius*2.0)
				if box.intersects(bounds,true):fans.append(fan)
	var result: Array=[edges,fans]
	if _tiles.size()>=MAX_TILES:_tiles.clear()
	_tiles[tile]=result
	return result

func sample(p: Vector2,source: RefCounted) -> Vector4:
	var tile:=Vector2i(floori(p.x/TILE),floori(p.y/TILE))
	if tile!=_last_tile:
		_near=_nearby(tile,source)
		_last_tile=tile
	var best: float=INF
	var width: float=45.0
	last_floor=4.0
	var valley_mask: float=0.0
	var bed_mask: float=0.0
	var floor_sum: float=0.0
	var floor_weight: float=0.0
	for edge: Array in _near[0]:
		var point_bounds: Rect2 = edge[12]
		if not point_bounds.has_point(p): continue
		var a: Vector2=edge[0]
		var delta: Vector2=edge[7]
		var t: float=clampf((p-a).dot(delta)/float(edge[8]),0.0,1.0)
		var bend_vector: Vector2=edge[6]
		var edge_width: float = edge[4]
		var acceleration: Vector2 = edge[11]
		if p.distance_squared_to(a+delta*t)>float(edge[10]):continue
		for iteration in range(2):
			var curve: Vector2=a+delta*t+bend_vector*(4.0*t*(1.0-t))
			var tangent: Vector2=delta+bend_vector*(4.0-8.0*t)
			t=clampf(t-(curve-p).dot(tangent)/maxf(tangent.length_squared()+(curve-p).dot(acceleration),1.0),0.0,1.0)
		var distance: float=p.distance_to(a+delta*t+bend_vector*(4.0*t*(1.0-t)))
		# A small width-normalized adjustment lets tributaries merge smoothly
		# with the broader trunk, without moving any descriptor endpoint.
		var adjusted: float=maxf(0.0,distance-edge_width*0.25)
		var blend: float=1.0-smoothstep(0.0,1200.0,distance)
		blend*=blend
		blend*=blend
		var relative_distance: float=distance/maxf(edge_width*0.4,5.0)
		var squared_distance: float=relative_distance*relative_distance
		blend/=1.0+squared_distance*squared_distance
		floor_sum+=(lerpf(edge[2],edge[3],t)-4.0)*blend
		floor_weight+=blend
		valley_mask=maxf(valley_mask,1.0-smoothstep(edge_width*1.5,1200.0,adjusted))
		bed_mask=maxf(bed_mask,1.0-smoothstep(edge_width*0.35,edge_width*1.7,adjusted))
		if adjusted<best:
			best=adjusted;width=edge_width
	last_floor=4.0+floor_sum/maxf(floor_weight,0.000001)
	var fan_mask: float=0.0
	last_fan_lift=0.0
	for fan: Array in _near[1]:
		var d: Vector2=p-fan[0]
		var direction: Vector2=fan[1]
		var t: float=d.dot(direction)/fan[2]
		if t<0.0 or t>1.0:continue
		var across: float=absf(d.dot(Vector2(-direction.y,direction.x)))
		var extent: float=35.0+t*fan[2]*0.65
		var shape: float=(1.0-smoothstep(extent*0.55,extent,across))*smoothstep(0.0,0.08,t)*(1.0-smoothstep(0.6,1.0,t))
		fan_mask=maxf(fan_mask,shape*fan[3])
		last_fan_lift=maxf(last_fan_lift,shape*float(fan[3])*(1.0-t)*12.0)
	return Vector4(valley_mask,bed_mask,minf(best,10000.0),fan_mask)
