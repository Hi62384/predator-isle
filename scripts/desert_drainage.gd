extends RefCounted
## Finite, rooted dry catchments. Every tributary ends on a parent junction.
## Descriptor creation and tile culling are bounded; there is no live simulation.
const TILE: float = 1024.0
const MAX_TILES: int = 512
var settings: DesertSettings
var seed_value: int
var _catchments: Dictionary = {}
var _tiles: Dictionary = {}
var _span: float
var _catchment_occurrence: float = 1.0
var _last_tile := Vector2i(2147483647,2147483647)
var _near: Array = []
var _local_tiles: Dictionary = {}
var _last_local_tile:=Vector2i(2147483647,2147483647)
var _local_near: Array=[]
var last_floor: float = 4.0
var last_fan_lift: float = 0.0
var last_fan_channels: float = 0.0
var last_lee: float = 0.5
var last_gully: float = 0.0
var last_gully_floor: float = 4.0

func reset_sample() -> void:
	last_floor=4.0
	last_lee=0.5
	last_fan_lift=0.0
	last_fan_channels=0.0
	last_gully=0.0
	last_gully_floor=4.0

func configure(config: DesertSettings, seed_number: int) -> void:
	settings=config;seed_value=seed_number
	_span=maxf(settings.basin_size*5.0,6000.0)
	_catchment_occurrence=clampf(settings.canyon_occurrence,0.0,1.0)
	_catchments.clear();_tiles.clear()
	_local_tiles.clear()
	_last_local_tile=Vector2i(2147483647,2147483647)
	_last_tile=Vector2i(2147483647,2147483647)

func _hash(x: int,z: int,salt: int) -> float:
	var h: int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0

func _curve(a: Vector2, b: Vector2, bend: float, _segments: int, floor_a: float, floor_b: float, width: float, support: float = 1250.0) -> Array:
	# One analytic arc; no visible polygon corners from a coarse polyline.
	var delta: Vector2=b-a
	var bend_vector:=Vector2(-delta.y,delta.x).normalized()*bend
	var bounds := Rect2(a,Vector2.ZERO).expand(b).grow(support+absf(bend))
	var reach: float = support+absf(bend)
	# Extra margin conservatively covers float32 endpoint/interpolation roundoff.
	var margin: float = maxf(1.0,maxf(maxf(absf(a.x),absf(a.y)),maxf(absf(b.x),absf(b.y)))*0.000001)
	var point_bounds: Rect2 = bounds.grow(margin)
	var phase: float = _hash(floori(a.x/17.0),floori(a.y/17.0),491) * TAU
	return [[a,b,floor_a,floor_b,width,bend,bend_vector,delta,maxf(delta.length_squared(),1.0),bounds,reach*reach,-bend_vector*8.0,point_bounds,phase,support]]

func _catchment(cell: Vector2i, source: RefCounted) -> Array:
	if _catchments.has(cell):return _catchments[cell]
	# Select complete immutable catchments. Clipping a network with a point mask
	# would strand tributaries and fans or interrupt its graded downstream bed.
	# The independent hash retains the same networks as probability increases.
	if _catchment_occurrence < 1.0:
		if _catchment_occurrence <= 0.0 or _hash(cell.x,cell.y,791) >= _catchment_occurrence:
			var empty: Array = [[],[],[]]
			if _catchments.size()>=128:_catchments.clear()
			_catchments[cell]=empty
			return empty
	var span: float=_span
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
	var gullies: Array=[]
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
		# Up to two two-edge local tributaries per catchment. Their downstream
		# endpoint is an actual existing tributary junction, with its exact floor.
		# Cache construction pays for region classification, not each vertex.
		if up[5] > 0.12 and gullies.size() < 4:
			var gully_length: float = lerpf(160.0,340.0,_hash(cell.x,cell.y,501+branch))
			var gully_tip: Vector2 = (join + direction*gully_length*0.75 + normal*side*gully_length*0.65).clamp(minimum,maximum)
			var gully_join: Vector2 = join.lerp(gully_tip,0.55)
			var gully_floor: float = floor+0.85
			gullies.append_array(_curve(join,gully_tip,bend*0.08,2,gully_floor,gully_floor+32.0,11.0,190.0))
			# This endpoint is on the curved parent at t=.55, not its chord.
			var main: Array = gullies.back()
			gully_join += Vector2(main[6])*(4.0*0.55*0.45)
			var twig_tip: Vector2 = (gully_join+direction*gully_length*0.30-normal*side*gully_length*0.40).clamp(minimum,maximum)
			gullies.append_array(_curve(gully_join,twig_tip,-bend*0.04,2,gully_floor+32.0*0.55,gully_floor+39.0,7.0,125.0))
		var gate: float=clampf((up[2]+up[4]+up[5])*(down[3]+down[6])*2.0,0.0,1.0)
		if gate>0.06:
			var fan_direction: Vector2=(junction-join).normalized()
			var fan_length: float=minf(reach*0.60,1400.0)
			var radius: float=sqrt(fan_length*fan_length+pow(fan_length*0.65+35.0,2.0))
			var fan_bounds:=Rect2(join-Vector2.ONE*radius,Vector2.ONE*radius*2.0)
			fans.append([join,fan_direction,fan_length,gate,fan_bounds,Vector2(-fan_direction.y,fan_direction.x)])
	var result: Array=[edges,fans,gullies]
	if _catchments.size()>=128:_catchments.clear()
	_catchments[cell]=result
	return result

func _nearby(tile: Vector2i,source: RefCounted) -> Array:
	if _tiles.has(tile):return _tiles[tile]
	var bounds:=Rect2(Vector2(tile)*TILE,Vector2.ONE*TILE)
	var span: float=_span
	var p: Vector2=bounds.get_center()
	var center:=Vector2i(floori(p.x/span),floori(p.y/span))
	var edges: Array=[]
	var fans: Array=[]
	var gullies: Array=[]
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
				var box: Rect2=fan[4]
				if box.intersects(bounds,true):fans.append(fan)
			for gully: Array in descriptor[2]:
				var box: Rect2=gully[9]
				if box.intersects(bounds,true):gullies.append(gully)
	var result: Array=[edges,fans,gullies]
	if _tiles.size()>=MAX_TILES:_tiles.clear()
	_tiles[tile]=result
	return result

func _local_candidates(p: Vector2, source: RefCounted) -> Array:
	# Exact conservative 128 m subtiles: retain each descriptor whose existing
	# support box intersects this cell. Same order, profiles and Newton solves;
	# only provably irrelevant candidates are skipped in the per-vertex loop.
	var local_tile:=Vector2i(floori(p.x/128.0),floori(p.y/128.0))
	if local_tile==_last_local_tile:return _local_near
	_last_local_tile=local_tile
	if _local_tiles.has(local_tile):
		_local_near=_local_tiles[local_tile]
		return _local_near
	var parent_tile:=Vector2i(floori(p.x/TILE),floori(p.y/TILE))
	var parent: Array=_nearby(parent_tile,source)
	var box:=Rect2(Vector2(local_tile)*128.0,Vector2.ONE*128.0).grow(0.1)
	var result: Array=[[],[],[]]
	for kind in range(3):
		for descriptor: Array in parent[kind]:
			var support: Rect2=descriptor[4] if kind==1 else descriptor[12]
			if support.intersects(box,true):result[kind].append(descriptor)
	if _local_tiles.size()>=2048:_local_tiles.clear()
	_local_tiles[local_tile]=result
	_local_near=result
	return result

func sample(p: Vector2,source: RefCounted,wind: Vector2 = Vector2.ZERO) -> Vector4:
	reset_sample()
	# A disabled network has no descriptors or fan contributions anywhere.
	# Reset every published field without allocating empty per-tile entries.
	if _catchment_occurrence <= 0.0:
		last_floor=4.0
		last_lee=0.5
		last_fan_lift=0.0
		last_fan_channels=0.0
		return Vector4(0.0,0.0,10000.0,0.0)
	_near=_local_candidates(p,source)
	var best: float=INF
	last_floor=4.0
	last_lee=0.5
	var valley_mask: float=0.0
	var bed_mask: float=0.0
	var floor_sum: float=0.0
	var floor_weight: float=0.0
	var lee_sum: float=0.0
	for edge: Array in _near[0]:
		var point_bounds: Rect2 = edge[12]
		if not point_bounds.has_point(p): continue
		var a: Vector2=edge[0]
		var delta: Vector2=edge[7]
		var t: float=clampf((p-a).dot(delta)/float(edge[8]),0.0,1.0)
		if p.distance_squared_to(a+delta*t)>float(edge[10]):continue
		var bend_vector: Vector2=edge[6]
		var edge_width: float = edge[4]
		var acceleration: Vector2 = edge[11]
		# The same two clamped Newton steps, with no per-edge iterator. Keep
		# the expression order and Vector2 rounding of the canonical solver.
		var curve: Vector2=a+delta*t+bend_vector*(4.0*t*(1.0-t))
		var tangent: Vector2=delta+bend_vector*(4.0-8.0*t)
		var curve_offset: Vector2=curve-p
		t=clampf(t-curve_offset.dot(tangent)/maxf(tangent.length_squared()+curve_offset.dot(acceleration),1.0),0.0,1.0)
		curve=a+delta*t+bend_vector*(4.0*t*(1.0-t))
		tangent=delta+bend_vector*(4.0-8.0*t)
		curve_offset=curve-p
		t=clampf(t-curve_offset.dot(tangent)/maxf(tangent.length_squared()+curve_offset.dot(acceleration),1.0),0.0,1.0)
		var offset: Vector2=p-(a+delta*t+bend_vector*(4.0*t*(1.0-t)))
		var distance: float=offset.length()
		# Smooth within-segment narrowing/widening, with unchanged endpoint
		# widths and zero endpoint derivative, preserves every confluence.
		var width_envelope: float = sin(t*PI)
		var width_ratio: float = 1.0+0.22*width_envelope*width_envelope*sin(t*TAU+float(edge[13]))
		edge_width *= width_ratio
		# A small width-normalized adjustment lets tributaries merge smoothly
		# with the broader trunk, without moving any descriptor endpoint.
		# Transport variation into the broad canyon wall coordinate as well as
		# the narrow wash. Changing just bed width barely moves a 600 m wall.
		var adjusted: float=maxf(0.0,distance/width_ratio-float(edge[4])*0.25)
		var blend: float=1.0-smoothstep(0.0,1200.0,distance)
		# Zero support contributes exactly zero to all three sums. Still keep
		# the edge below for the nearest distance and the wider valley support.
		if blend > 0.0:
			blend*=blend
			blend*=blend
			var relative_distance: float=distance/maxf(edge_width*0.4,5.0)
			var squared_distance: float=relative_distance*relative_distance
			blend/=1.0+squared_distance*squared_distance
			floor_sum+=(lerpf(edge[2],edge[3],t)-4.0)*blend
			floor_weight+=blend
			# Blend exposure with the same smooth support as floor elevation. A
			# nearest-edge switch would jump sand relief at tributary confluences.
			var flank_lee: float=clampf(0.5-offset.dot(wind)/maxf(distance,1.0)*0.5,0.0,1.0)
			lee_sum+=(flank_lee-0.5)*blend
		valley_mask=maxf(valley_mask,1.0-smoothstep(edge_width*1.5,1200.0,adjusted))
		bed_mask=maxf(bed_mask,1.0-smoothstep(edge_width*0.35,edge_width*1.7,adjusted))
		if adjusted<best:
			best=adjusted
	if floor_weight > 0.0:
		var normalization: float=maxf(floor_weight,0.000001)
		last_floor=4.0+floor_sum/normalization
		last_lee=clampf(0.5+lee_sum/normalization,0.0,1.0)
	if settings.erosion_intensity > 0.0 and source.last_weights.size() > 5 and source.last_weights[5] > 0.001:
		_sample_gullies(p)
	var fan_mask: float=0.0
	last_fan_lift=0.0
	last_fan_channels=0.0
	for fan: Array in _near[1]:
		var d: Vector2=p-fan[0]
		var direction: Vector2=fan[1]
		var fan_length: float=fan[2]
		var t: float=d.dot(direction)/fan_length
		# Longitudinal endpoints and the outer edge have exactly zero shape.
		if t<=0.0 or t>=1.0:continue
		var signed_across: float=d.dot(fan[5])
		var across: float=absf(signed_across)
		var extent: float=35.0+t*fan_length*0.65
		if across>=extent:continue
		var shape: float=(1.0-smoothstep(extent*0.55,extent,across))*smoothstep(0.0,0.08,t)*(1.0-smoothstep(0.6,1.0,t))
		# Three finite distributary ribbons diverge from the real valley mouth.
		# Sediment relief only; the connected dry channel is protected by caller.
		var spread: float=t*fan_length*0.43
		var wander: float=t*(1.0-t)*fan_length*0.10
		var ribbon_distance: float=minf(absf(signed_across-wander),minf(absf(signed_across-spread+wander),absf(signed_across+spread+wander)))
		var ribbon: float=1.0-smoothstep(10.0,35.0+t*24.0,ribbon_distance)
		var deposit: float=shape*float(fan[3])
		fan_mask=maxf(fan_mask,deposit)
		last_fan_channels=maxf(last_fan_channels,deposit*ribbon)
		last_fan_lift=maxf(last_fan_lift,deposit*(1.0-t)*12.0*(1.0-ribbon*0.18))
	return Vector4(valley_mask,bed_mask,minf(best,10000.0),fan_mask)

func _sample_gullies(p: Vector2) -> void:
	var floor_sum: float = 0.0
	var floor_weight: float = 0.0
	for edge: Array in _near[2]:
		var bounds: Rect2 = edge[12]
		if not bounds.has_point(p): continue
		var a: Vector2 = edge[0]
		var delta: Vector2 = edge[7]
		var bend: Vector2 = edge[6]
		var t: float = clampf((p-a).dot(delta)/float(edge[8]),0.0,1.0)
		if p.distance_squared_to(a+delta*t)>float(edge[10]): continue
		# Only short, weakly curved local branches enter this solver.
		var q: Vector2 = a+delta*t+bend*(4.0*t*(1.0-t))
		var tangent: Vector2 = delta+bend*(4.0-8.0*t)
		var offset: Vector2 = q-p
		t=clampf(t-offset.dot(tangent)/maxf(tangent.length_squared()+offset.dot(Vector2(edge[11])),1.0),0.0,1.0)
		q=a+delta*t+bend*(4.0*t*(1.0-t))
		var distance: float=p.distance_to(q)
		var width: float=edge[4]
		var support: float=edge[14]
		# The upstream end closes gradually; downstream support remains full
		# until the parent channel's final floor takes over in DesertSampler.
		var head_fade: float=1.0-smoothstep(0.72,1.0,t)
		var mask: float=(1.0-smoothstep(width,support,distance))*head_fade
		if mask<=0.0: continue
		last_gully=maxf(last_gully,mask)
		var weight: float=mask*mask*mask*mask
		floor_sum+=lerpf(edge[2],edge[3],t)*weight
		floor_weight+=weight
	if floor_weight>0.0: last_gully_floor=floor_sum/floor_weight
