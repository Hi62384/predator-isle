extends RefCounted
## One sediment mass cut by a cached, finite drainage tree; not a Desert/Mesa clone.
const NAMES=["Painted hills","Red mudstone","Gray clay","Bentonite hills","Eroded ridge country","Hoodoo country","Badlands canyon","Dissected plateau","Sediment basin","Dry wash country","Stratified clay hills","Pale badlands","Rocky highlands","Stratified escarpment","Sediment fans","Barren plain"]
const STEP:float=16
const CHANNELS:int=16
const REGION_RELIEFS=[150,200,100,115,300,180,340,340,38,85,160,180,390,300,75,18]
var settings:Resource
var _host:WeakRef
var seed_value:int
var _macro:=FastNoiseLite.new()
var _weather:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _node_ring:Array[Vector2i]=[]
var _node_cursor:int=0
var _patches:Dictionary={}
var _patch_ring:Array[Vector2i]=[]
var _patch_cursor:int=0
var _regions:Dictionary={}
var _trees:Dictionary={}
var _carriers:Dictionary={}
var state:=PackedFloat64Array()
var palette_state:=Vector4.ZERO
var remnant_delta:float=0
var profile:bool=false
var timings:Dictionary={}
## Internal reference toggle for exact-equivalence/performance tests only.
var _use_segment_index:bool=true
var _use_grade_bound:bool=true
var _tree_radius_override:int=0 # diagnostic exhaustive-neighbour reference
func configure(config:Resource,world_seed:int,host:RefCounted)->void:
	settings=config;seed_value=world_seed;_host=weakref(host)
	for item in [[_macro,31013,1.0/2900,2],[_weather,31039,1.0/380,2]]:
		var n:FastNoiseLite=item[0];n.seed=world_seed+item[1];n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.3
	_nodes.clear();_node_ring.clear();_node_cursor=0;_regions.clear();_trees.clear();_carriers.clear();timings.clear()
	_patches.clear();_patch_ring.clear();_patch_cursor=0
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _region(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:Vector2=Vector2(cell)*256;var span:float=settings.region_metres;var base:=Vector2i(floori(p.x/span),floori(p.y/span));var sites:Array=[];var closest:float=INF
	var occurrence:Array=[settings.painted_frequency,.5,settings.clay_frequency,settings.clay_frequency*.6,settings.rugged_frequency,.18,.25,.3,settings.basin_frequency,.3,.4,.4,settings.rugged_frequency*.5,.25,.25,settings.basin_frequency*.7]
	var mass:float=0
	for v:float in occurrence:mass+=v
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=base+Vector2i(x,z);var site:Vector2=(Vector2(q)+Vector2(.2+random(q.x,q.y,1)*.6,.2+random(q.x,q.y,2)*.6))*span
			var roll:float=random(q.x,q.y,3)*mass;var id:int=15
			for i in range(16):
				roll-=occurrence[i]
				if roll<=0:id=i;break
			var distance:float=p.distance_to(site);closest=minf(closest,distance);sites.append([distance,id])
	var w:=PackedFloat32Array();w.resize(16);var total:float=0
	for s:Array in sites:
		var amount:float=1-smoothstep(0,span*.2,s[0]-closest);w[s[1]]+=amount;total+=amount
	for i in range(16):w[i]/=maxf(total,.00001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=w;return w
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/256;var c:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(c)
	var a:PackedFloat32Array=_region(c);var b:PackedFloat32Array=_region(c+Vector2i.RIGHT);var d:PackedFloat32Array=_region(c+Vector2i.DOWN);var e:PackedFloat32Array=_region(c+Vector2i.ONE)
	if a==b and a==d and a==e:return a
	f=Vector2(smoothstep(0,1,f.x),smoothstep(0,1,f.y));var w:=PackedFloat32Array();w.resize(16)
	for i in range(16):w[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(d[i],e[i],f.x),f.y)
	return w
func material_palette(p:Vector2)->Vector4:
	var weights:PackedFloat32Array=region_weights(p)
	return Vector4(weights[2]+weights[3],weights[8]+weights[15],weights[1]+weights[10]*.5,weights[11])
func _spacing()->float:return 4000/maxf(_host.get_ref().settings.grass_river_frequency,.01)
func _carrier(x:float,lane:int)->float:
	return _host.get_ref()._grass_river_center(x,lane,_spacing())
func _carrier_node(index:int,lane:int)->float:
	var key:=Vector2i(index,lane)
	if _carriers.has(key):return _carriers[key]
	var v:float=_carrier(index*1024.0,lane)
	if _carriers.size()>=2048:_carriers.clear()
	_carriers[key]=v;return v
func _broad_carrier(x:float,lane:int)->float:
	var q:float=x/1024;var i:int=floori(q)
	return cubic(_carrier_node(i-1,lane),_carrier_node(i,lane),_carrier_node(i+1,lane),_carrier_node(i+2,lane),q-i)
func _tree(index:int,lane:int,side:int)->Dictionary:
	var key:=Vector3i(index,lane,side)
	if _trees.has(key):return _trees[key]
	var r:float=random(index,lane,41+side);var span:float=settings.drainage_spacing
	var x:float=(index+.25+r*.5)*span;var root:=Vector3(x,28,_carrier(x,lane));var extent:float=_spacing()*(.32+r*.09)
	var junction:=root+Vector3((r-.5)*span*.4,extent*.025,side*extent*.36)
	var edges:Array=[[root,junction,0]];var ends:Array=[]
	for branch in [-1,1]:
		var b:float=random(index,lane,55+branch*3+side)
		var shoulder:=junction+Vector3(branch*span*(.18+b*.14),extent*.033,side*extent*.36)
		var top:=shoulder+Vector3(branch*span*(.08+b*.12),extent*.03,side*extent*.28)
		edges.append([junction,shoulder,1]);edges.append([shoulder,top,1]);ends.append(top)
		# Several differently spaced hillslope tributaries, all rooted on the
		# SAME trunk. A single pair left most upland as an unincised plateau.
		for station in range(3):
			for twig in [-1,1]:
				var variation:float=random(index,lane,83+station*17+twig*5+branch*3+side)
				var station_t:float=[.06,.28,.63][station]+variation*[.18,.33,.30][station]
				var join:Vector3=shoulder.lerp(top,station_t)
				var parent_direction:=Vector2(top.x-shoulder.x,top.z-shoulder.z).normalized()
				var direction:Vector2=parent_direction.rotated(twig*(.5+variation*.65))
				var reach:float=span*(.13+variation*.13)
				var end:Vector3=join+Vector3(direction.x*reach,extent*(.017+variation*.014),direction.y*reach)
				edges.append([join,end,2])
				# Keep caprock occurrence independent of drainage-network density.
				if station==1:ends.append(end)
	# Third-order source gullies inherit actual parent junctions. They are not
	# a repeating scratch mask crossing ridges or disconnected random segments.
	var parent_count:int=edges.size()
	for i in range(parent_count):
		if edges[i][2]!=2:continue
		var a:Vector3=edges[i][0];var b:Vector3=edges[i][1]
		for k in [-1,1]:
			var t:float=.35+random(index,lane,i*11+k+side)*.3;var join:Vector3=a.lerp(b,t)
			var variation:float=random(index,lane,1703+i*29+k*7+side)
			var direction:=Vector2(b.x-a.x,b.z-a.z).normalized().rotated(k*(.45+variation*.7))
			var reach:float=span*(.045+variation*.075)
			var end:Vector3=join+Vector3(direction.x*reach,extent*(.009+variation*.016),direction.y*reach)
			edges.append([join,end,3])
	# Fine source channels inherit the parent tree, not an independent scratch
	# texture. Their finite extent leaves broad calm provinces intact.
	var source_count:int=edges.size()
	for i in range(source_count):
		if edges[i][2]!=3:continue
		var a:Vector3=edges[i][0];var b:Vector3=edges[i][1]
		var t:float=.4+random(index,lane,i*17+side)*.3
		var join:Vector3=a.lerp(b,t)
		var handed:float=-1 if random(index,lane,i*19+side)<.5 else 1
		var variation:float=random(index,lane,1901+i*23+side)
		var direction:=Vector2(b.x-a.x,b.z-a.z).normalized().rotated(handed*(.5+variation*.65))
		var reach:float=span*(.02+variation*.04)
		var end:Vector3=join+Vector3(direction.x*reach,extent*(.004+variation*.008),direction.y*reach)
		edges.append([join,end,4])
	# Precomputed numeric segments make distant canonical normal probes cheap.
	# Bounds reject without constructing/projecting every unrelated edge.
	var edge_bounds:=PackedVector4Array();var edge_vectors:=PackedVector4Array();var edge_metrics:=PackedVector4Array()
	for edge:Array in edges:
		var a:Vector3=edge[0];var b:Vector3=edge[1];var delta:=Vector2(b.x-a.x,b.z-a.z)
		edge_bounds.append(Vector4(minf(a.x,b.x),minf(a.z,b.z),maxf(a.x,b.x),maxf(a.z,b.z)))
		edge_vectors.append(Vector4(a.x,a.z,delta.x,delta.y))
		edge_metrics.append(Vector4(1.0/delta.length_squared(),a.y,b.y-a.y,edge[2]))
	# A conservative world-anchored binning of the SAME segments. Maximum
	# relief/width bounds include every regional mixture and a numeric margin.
	# No feature is moved, simplified or seeded per chunk by this acceleration.
	var segment_cells:Dictionary={}
	# Include fans and every valley's maximum supported envelope. The former
	# fixed root-distance rejection could truncate still-influential banks.
	var fan_reach:float=350+391*settings.relief
	var support_bounds:=Vector4(root.x-320,root.z-fan_reach,root.x+320,root.z+fan_reach)
	for edge_index in range(edge_bounds.size()):
		var bound:Vector4=edge_bounds[edge_index];var order:float=edge_metrics[edge_index].w
		var maximum_bank:float=(390+391*settings.relief)*(1.6 if order>=2 else 1)/(1+order*.4)+31
		var low:=Vector2i(floori((bound.x-maximum_bank)/256),floori((bound.y-maximum_bank)/256))
		var high:=Vector2i(floori((bound.z+maximum_bank)/256),floori((bound.w+maximum_bank)/256))
		support_bounds=Vector4(minf(support_bounds.x,bound.x-maximum_bank),minf(support_bounds.y,bound.y-maximum_bank),maxf(support_bounds.z,bound.z+maximum_bank),maxf(support_bounds.w,bound.w+maximum_bank))
		for cz in range(low.y,high.y+1):
			for cx in range(low.x,high.x+1):
				var cell:=Vector2i(cx,cz)
				if not segment_cells.has(cell):segment_cells[cell]=[]
				segment_cells[cell].append(edge_index)
	# A catchment has one grade scale. Re-scaling the same stream at every
	# query point made a regional relief transition reverse actual bed grades.
	var root_weights:PackedFloat32Array=region_weights(Vector2(root.x,root.z));var root_relief:float=0
	for region in range(16):root_relief+=root_weights[region]*float(REGION_RELIEFS[region])
	var grade_scale:float=clampf(root_relief*settings.relief/300,.12,1.6)
	var data:Dictionary={"root":root,"edges":edges,"ends":ends,"random":r,"extent":extent,"edge_bounds":edge_bounds,"edge_vectors":edge_vectors,"edge_metrics":edge_metrics,"segment_cells":segment_cells,"grade_scale":grade_scale}
	data.support_bounds=support_bounds
	if _trees.size()>=512:_trees.clear()
	_trees[key]=data;return data
func geological_coordinate(p:Vector2,height:float)->float:
	# Broad continuously varying dip/folds; mirrored exactly in the shader.
	var beds:float=height+settings.strata_dip.dot(p)+(24*sin(p.x/5300+sin(p.y/7100))+17*sin(p.y/3900))*settings.fold_strength
	var unit:float=settings.strata_metres*.35
	return beds/unit+settings.thickness_variation*sin(beds/(unit*1.7)+p.x/11000)
func strata(p:Vector2,height:float)->Vector2:
	# Unequal units within a long sequence: thick sediment, thin shale and
	# resistant caps. No identical hard band every fixed 84 metres.
	var phase:float=fposmod(geological_coordinate(p,height),5)
	var hard:float=smoothstep(.48,.53,phase)*(1-smoothstep(.67,.74,phase))
	hard=maxf(hard,smoothstep(3.57,3.63,phase)*(1-smoothstep(3.92,4.02,phase)))
	return Vector2(phase,hard)
func _remnant_formations(tree:Dictionary,index:int,lane:int,side:int)->Array:
	if tree.has("formations"):return tree.formations
	var formations:Array=[];var unit:float=settings.strata_metres*.35
	for ordinal in range(tree.ends.size()):
		var end:Vector3=tree.ends[ordinal];var salt:int=ordinal*97+side
		var r:float=random(index,lane,271+salt);var anchor:=Vector2(end.x+80,end.z)
		var potential:float=_base_sample(anchor.x,anchor.y,false)+settings.remnant_height*(1.1+r*.6)
		var coordinate:float=geological_coordinate(anchor,potential);var cycle:float=floorf(coordinate/5)*5
		var target:float=maxf(cycle+.60 if coordinate>=cycle+.60 else cycle-5+.60,cycle+3.77 if coordinate>=cycle+3.77 else cycle-5+3.77)
		var height:float=potential+(target-coordinate)*unit
		# Invert the monotonic geological coordinate, so caps are resistant beds,
		# not arbitrary flat hats whose material stripes pass through unchanged.
		for iteration in range(4):
			var beds:float=height+settings.strata_dip.dot(anchor)+(24*sin(anchor.x/5300+sin(anchor.y/7100))+17*sin(anchor.y/3900))*settings.fold_strength
			var derivative:float=(1+settings.thickness_variation/1.7*cos(beds/(unit*1.7)+anchor.x/11000))/unit
			height-=(geological_coordinate(anchor,height)-target)/derivative
		formations.append({"position":anchor,"height":height,"radius":Vector2(22+r*28,22+random(index,lane,283+salt)*32),"angle":random(index,lane,293+salt)*TAU,"phase":r*TAU,"shoulder":.18+random(index,lane,307+salt)*.22,"weathering":.9+random(index,lane,311+salt)*.35})
	tree["formations"]=formations;return formations
func remnant_surface(p:Vector2,base:float,publish:bool)->float:
	# Evaluate compact features continuously AFTER the coarse erosion lattice.
	# Nearby mesh/collision vertices then see the same narrow world-space shape
	# instead of a 16m cubic blur. The background lattice/density is unchanged.
	if settings.remnants<=0:return base
	var weights:PackedFloat32Array=region_weights(p);var mass:float=weights[5]
	if mass<=.000001:return base
	var spacing:float=_spacing();var initial_lane:int=roundi(p.y/spacing);var lane:int=initial_lane;var closest:float=INF
	for offset in range(-1,2):
		var candidate:int=initial_lane+offset;var distance:float=absf(p.y-_broad_carrier(p.x,candidate))
		if distance<closest:closest=distance;lane=candidate
	var side:int=-1 if p.y<_broad_carrier(p.x,lane) else 1
	var index:int=floori(p.x/settings.drainage_spacing);var height:float=base;var influence:float=0
	for offset in range(-1,2):
		var tree:Dictionary=_tree(index+offset,lane,side)
		if tree.random>=settings.remnants:continue
		for formation:Dictionary in _remnant_formations(tree,index+offset,lane,side):
			var relative:Vector2=p-formation.position
			if absf(relative.x)>160 or absf(relative.y)>160:continue
			var q:Vector2=relative.rotated(-formation.angle)/formation.radius
			var radius:float=pow(pow(absf(q.x),3)+pow(absf(q.y),3),1.0/3)+sin(q.x*3+formation.phase)*.06+sin(q.y*4-formation.phase)*.04
			# Unequal vertical joint ribs and a separate low colluvial apron.
			# The upper column is not one smoothly tapering cone to ground level.
			var angle:float=atan2(q.y,q.x)
			# Joint-guided bays break the old broad cylindrical silhouette into
			# unequal fluted buttresses. The cap is narrow; its surviving bed is
			# not a uniformly broad, flat mesa extruded above a smooth apron.
			var joints:float=pow(absf(sin(angle*5+formation.phase)),8)*.22
			radius+=(sin(angle*5+formation.phase)*.10+sin(angle*9-formation.phase)*.06+joints)*smoothstep(.15,.65,radius)
			if radius>=1.8 or formation.height<=height:continue
			var core:float=pow(1-smoothstep(formation.shoulder,formation.shoulder+.65,radius),formation.weathering)
			var apron:float=1-smoothstep(.8,1.8,radius)
			var support:float=(core*.86+apron*.14)*mass
			influence=maxf(influence,support);height=lerpf(height,formation.height,support)
	if publish:
		state[0]=height;state[10]=influence
		remnant_delta=height-base
		state[4]=clampf(state[4]+influence,0,1)
		var beds:Vector2=strata(p,height);state[11]=beds.y;state[15]=beds.x
	return height
func _raw(p:Vector2)->PackedFloat64Array:
	var tick:int=Time.get_ticks_usec() if profile else 0
	var w:PackedFloat32Array=region_weights(p);var macro:float=_macro.get_noise_2d(p.x,p.y);var weather:float=_weather.get_noise_2d(p.x,p.y)
	var relief:float=0;var id:int=0
	for i in range(16):
		relief+=w[i]*float(REGION_RELIEFS[i])
		if w[i]>w[id]:id=i
	relief*=settings.relief
	var calm:float=clampf(w[8]+w[9]*.4+w[14]*.6+w[15],0,1)
	var clay:float=clampf(w[0]*.5+w[2]+w[3]+w[10]*.6,0,1)
	var dissected:float=clampf(w[4]+w[5]*.65+w[6]+w[7]+w[12]*.7+w[13],0,1)
	var source_eligibility:float=(1-smoothstep(.65,.99,calm))*lerpf(1.0,.4,clay)
	var spacing:float=_spacing();var initial_lane:int=roundi(p.y/spacing)
	var lane:int=initial_lane;var primary:float=INF
	for j in range(-1,2):
		var candidate:int=initial_lane+j;var d:float=absf(p.y-_broad_carrier(p.x,candidate))
		if d<primary:primary=d;lane=candidate
	var fine_distance:float=absf(p.y-_carrier(p.x,lane))
	var side:int=-1 if p.y<_broad_carrier(p.x,lane) else 1
	var width:float=settings.wash_width*(1+w[9]*1.5+w[8])
	var upland:float=1-exp(-pow(maxf(primary-width,0)/(900+clay*500+w[8]*700),1.6))
	var plateau:float=smoothstep(.35,.72,upland+macro*.3)
	var mass_height:float=relief*(.82+macro*.3)*upland
	var rounded_province:float=w[0]+w[2]*.8+w[3]+w[10]*.65+w[11]*.55
	if settings.rounded_hill_strength>0 and rounded_province>.000001:
		# Broad rounded sediment masses provide different hill rhythms from
		# the dissected plateau provinces. This acts only on surviving upland;
		# the same connected drainage envelopes are cut into it below.
		var broad:float=_weather.get_noise_2dv(p*.45)
		var lobes:float=pow(clampf(.5+weather*.8+broad*.35,0,1),1.35)
		var rounded_height:float=relief*(.15+.95*lobes+macro*.08)*upland
		mass_height=lerpf(mass_height,rounded_height,clampf(rounded_province*settings.rounded_hill_strength,0,1))
	var h:float=28+(mass_height+relief*.25*plateau*(w[7]+w[13]))
	var main:float=1-smoothstep(width*.5,width*2,fine_distance)
	h=lerpf(h,minf(h,25+weather*.8),main)
	var drainage:float=main;var second:float=0;var fan:float=0;var remnant:float=0
	var fan_deposit_sum:float=0;var fan_deposit_weight:float=0
	var floor_protection:float=main
	var nearest:float=INF;var index:int=floori(p.x/settings.drainage_spacing)
	var segment_cell:=Vector2i(floori(p.x/256),floori(p.y/256))
	var banks:=PackedFloat64Array();var floors:=PackedFloat64Array()
	for order in range(5):
		banks.append((390+relief)*(1-calm*.55)/(1+order*(.4+dissected*.18))*(1-clay*.45 if order>=2 else 1)*(1+dissected*.6 if order>=2 else 1))
		floors.append(24.0/(1+order*.6))
	var tree_radius:int=ceili((settings.drainage_spacing*1.5+(390+391*settings.relief)*1.6/1.8)/settings.drainage_spacing)
	if _tree_radius_override>0:tree_radius=_tree_radius_override
	for j in range(-tree_radius,tree_radius+1):
		var tree:Dictionary=_tree(index+j,lane,side);var root:Vector3=tree.root
		var tree_bound:Vector4=tree.support_bounds
		if p.x<tree_bound.x or p.y<tree_bound.y or p.x>tree_bound.z or p.y>tree_bound.w:continue
		var bounds:PackedVector4Array=tree.edge_bounds;var vectors:PackedVector4Array=tree.edge_vectors;var metrics:PackedVector4Array=tree.edge_metrics
		var candidates:Array=tree.segment_cells.get(segment_cell,[]) if _use_segment_index else range(metrics.size())
		for edge_index:int in candidates:
			var metric:Vector4=metrics[edge_index];var order:int=int(metric.w)
			# The nonnegative valley-wall envelope cannot lower terrain below
			# either endpoint grade. Reject an impossible cut before expensive
			# projections/powers; all published cut controls would be zero too.
			if _use_grade_bound and 28+(metric.y-28+minf(metric.z,0))*tree.grade_scale>=h:continue
			if order>=2 and (settings.secondary_gullies<=0 or source_eligibility<=0):continue
			if order==4 and dissected<=.05:continue
			var bank:float=banks[order];var bound:Vector4=bounds[edge_index]
			if p.x<bound.x-bank-30 or p.y<bound.y-bank-30 or p.x>bound.z+bank+30 or p.y>bound.w+bank+30:continue
			var segment:Vector4=vectors[edge_index];var delta:=Vector2(segment.z,segment.w);var relative:=p-Vector2(segment.x,segment.y)
			var t:float=clampf(relative.dot(delta)*metric.x,0,1);var distance:float=(relative-delta*t).length()
			if distance>bank+30:continue
			var grade:float=28+(metric.y-28+metric.z*t)*tree.grade_scale;var floor_width:float=floors[order]
			var support:float=1-smoothstep(floor_width,bank,distance)
			var bed:float=1-smoothstep(floor_width*.3,floor_width*1.8,distance)
			var amount:float=settings.erosion*(settings.secondary_gullies if order>=2 else 1)
			if order>=2:amount*=source_eligibility
			if order==4:amount*=smoothstep(.05,.45,dissected)
			# Convex-up valley walls meet as narrow divides in dissected country;
			# sublinear profiles instead left broad smooth shoulders everywhere.
			# Erosion controls the lateral reach of an incised valley, not a
			# succession of shallow blends back toward the uncut plateau. The
			# latter left every source channel as a dent in inflated terrain.
			var effective_bank:float=bank*sqrt(clampf(amount,0,1))
			var shape:float=pow(clampf(distance/maxf(effective_bank,1),0,1),lerpf(1.35,2.6,clampf(settings.ridge_sharpness*.5+dissected*.35,0,1)))
			# A drainage-distance envelope creates surviving interfluves instead
			# of cutting tiny grooves in an otherwise uniformly flat upland.
			# At the finite support boundary this ceiling exceeds the upland,
			# so early rejection cannot cut a hard rectangular feature edge.
			# The small-strength fade keeps zero/near-zero regional eligibility
			# continuous, including the segment centreline and calm boundaries.
			var before:float=h
			h=lerpf(h,minf(h,grade+relief*1.5*shape),smoothstep(0,.12,amount))
			var actual_cut:float=smoothstep(.02,.5,before-h)
			var core:float=1-smoothstep(maxf(floor_width,STEP),maxf(floor_width*2,STEP*2),distance)
			floor_protection=maxf(floor_protection,core*actual_cut*smoothstep(0,.12,amount))
			drainage=maxf(drainage,bed*amount*actual_cut)
			if order>0:second=maxf(second,support*amount*actual_cut)
			nearest=minf(nearest,distance)
		# Fan is rooted at the ACTUAL tributary outlet; broadens toward its wash.
		var along:float=(p.y-root.z)*side;var fan_span:float=350+relief
		var fan_mask:float=(1-smoothstep(0,fan_span,absf(along)))*(1-smoothstep(70,320,absf(p.x-root.x)))
		if settings.fan_shape_strength>0 and settings.fans>0 and w[14]+w[8]*.6+w[9]*.3>0:
			var shaped:float=preload("res://scripts/badlands_fan_geometry.gd").mask(p,tree,fan_span)
			fan_mask=lerpf(fan_mask,shaped,clampf(settings.fan_shape_strength,0,1))
		if settings.fan_gradient>0 and settings.fan_shape_strength>0:
			var contribution:float=fan_mask*settings.fans*(w[14]+w[8]*.6+w[9]*.3)*clampf(settings.fan_shape_strength,0,1)
			if contribution>0:
				var basis:PackedFloat64Array=preload("res://scripts/badlands_fan_geometry.gd").frame(tree)
				if not basis.is_empty():
					var upstream:float=clampf((p-Vector2(basis[0],basis[1])).dot(Vector2(basis[2],basis[3])),0,minf(fan_span,maxf(32,basis[4]*.85)))
					fan_deposit_sum+=contribution*upstream*settings.fan_gradient;fan_deposit_weight+=contribution
		fan=maxf(fan,fan_mask*settings.fans*(w[14]+w[8]*.6+w[9]*.3))
	var layers:Vector2=strata(p,h)
	var exposed:float=clampf((1-calm)*(.2+second*.5+w[12]*.4+w[13]*.35)+remnant,0,1)
	# Mesoscopic buttress relief follows surviving drainage divides, rather than
	# applying an isotropic noise blanket to wash floors and depositional fans.
	var divide:float=(1-floor_protection)*(1-fan)*exposed*upland*(1-remnant)
	# Small differential weathering is subordinate to the connected drainage;
	# no world-axis sinusoidal rib pattern across unrelated hillsides.
	h+=divide*_weather.get_noise_2dv(p*1.7)*(3+dissected*5)
	h+=layers.y*settings.ledges*5*exposed*(1-floor_protection)*(1-remnant)
	if settings.fan_shape_strength>0:
		# Deposition mantles banks, not the active primary/feeder floor. The
		# original full-apron blend could raise a berm across a protected wash.
		h=lerpf(h,28+weather+(fan_deposit_sum/fan_deposit_weight if fan_deposit_weight>0 else 0),fan*.6*(1-floor_protection*clampf(settings.fan_shape_strength,0,1)))
	else:h=lerpf(h,28+weather,fan*.6)
	var pool:float=0;var water:float=0
	# Rare retained water is attached to a drainage root in a basin province.
	if w[8]>.5 and settings.pool_frequency>0:
		var tree:Dictionary=_tree(index,lane,side)
		if tree.random<settings.pool_frequency:
			var root:Vector3=tree.root;var q:=Vector2((p.x-root.x)/100,(p.y-root.z)/65);var r:float=q.length()+sin(q.x*3)*.08
			var support:float=1-smoothstep(.7,1.5,r);pool=(1-smoothstep(.25,.9,r))*support
			water=24*support;h=lerpf(h,29-pool*9,support)
	if profile:timings["raw_us"]=timings.get("raw_us",0)+Time.get_ticks_usec()-tick
	# h, water, moisture, region, exposure, erosion, deposition, ridge,
	# major drainage, secondary drainage, remnant, hard bed, clay, fan, pool, strata.
	return PackedFloat64Array([h,water,pool*.8,float(id)/15,exposed,second,clampf(maxf(main,fan)+second*.15,0,1),clampf(upland*(1-second),0,1),main,second,remnant,layers.y,clay,fan,pool,layers.x])
func _node(c:Vector2i)->PackedFloat64Array:
	if _nodes.has(c):return _nodes[c]
	var v:PackedFloat64Array=_raw(Vector2(c)*STEP)
	if _nodes.is_empty():_node_ring.clear();_node_cursor=0
	if _node_ring.size()<16384:
		# Also tolerate externally seeded diagnostic caches without exceeding cap.
		if _nodes.size()>=16384:_nodes.erase(_nodes.keys()[0])
		_node_ring.append(c)
	else:
		_nodes.erase(_node_ring[_node_cursor]);_node_ring[_node_cursor]=c;_node_cursor=(_node_cursor+1)%16384
	_nodes[c]=v;return v
func cubic(a:float,b:float,c:float,d:float,t:float)->float:return b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)))
func _patch(cell:Vector2i)->Array:
	if _patches.has(cell):return _patches[cell]
	var coefficients:=PackedFloat64Array();var corners:Array=[]
	for row in range(-1,3):
		var a:PackedFloat64Array=_node(cell+Vector2i(-1,row));var b:PackedFloat64Array=_node(cell+Vector2i(0,row))
		var c:PackedFloat64Array=_node(cell+Vector2i(1,row));var d:PackedFloat64Array=_node(cell+Vector2i(2,row))
		for channel in range(2):
			coefficients.append_array(PackedFloat64Array([b[channel],c[channel]-a[channel],2*a[channel]-5*b[channel]+4*c[channel]-d[channel],3*(b[channel]-c[channel])+d[channel]-a[channel]]))
		if row==0 or row==1:corners.append(b);corners.append(c)
	var patch:Array=[coefficients,corners]
	if _patch_ring.size()<1024:_patch_ring.append(cell)
	else:
		_patches.erase(_patch_ring[_patch_cursor]);_patch_ring[_patch_cursor]=cell;_patch_cursor=(_patch_cursor+1)%1024
	_patches[cell]=patch;return patch
func _patch_row(coefficients:PackedFloat64Array,index:int,t:float)->float:
	return coefficients[index]+.5*t*(coefficients[index+1]+t*(coefficients[index+2]+t*coefficients[index+3]))
func sample(x:float,z:float,publish:bool=true)->float:
	if publish:palette_state=material_palette(Vector2(x,z));remnant_delta=0
	return remnant_surface(Vector2(x,z),_base_sample(x,z,publish),publish)
func _base_sample(x:float,z:float,publish:bool)->float:
	var q:=Vector2(x,z)/STEP;var c:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(c)
	if f==Vector2.ZERO:
		var v:PackedFloat64Array=_node(c)
		if publish:state=v.duplicate()
		return v[0]
	var patch:Array=_patch(c);var coefficients:PackedFloat64Array=patch[0]
	var h:float=cubic(_patch_row(coefficients,0,f.x),_patch_row(coefficients,8,f.x),_patch_row(coefficients,16,f.x),_patch_row(coefficients,24,f.x),f.y)
	if publish:
		var corners:Array=patch[1];var a:PackedFloat64Array=corners[0];var b:PackedFloat64Array=corners[1];var d:PackedFloat64Array=corners[2];var e:PackedFloat64Array=corners[3]
		state=PackedFloat64Array();state.resize(CHANNELS);state[0]=h
		state[1]=cubic(_patch_row(coefficients,4,f.x),_patch_row(coefficients,12,f.x),_patch_row(coefficients,20,f.x),_patch_row(coefficients,28,f.x),f.y)
		for i in range(2,CHANNELS):state[i]=clampf(lerpf(lerpf(a[i],b[i],f.x),lerpf(d[i],e[i],f.x),f.y),0,1)
	return h
