extends RefCounted
## Canonical coastal target field. Reads actual island geography, never SceneTree.
const STEP:float=8
const CHANNELS:int=21
const NAMES=["Towering cliffs","Rugged shore","Headlands","Sheltered coves","Wave-cut platforms","Boulder/shingle","Sea stacks","Granite highlands","Sedimentary cliffs","Dark rocky coast","Fjord-like inlets","Coastal plateau","Wave-battered coast","Sheltered inlets","Low rocky islands","Coastal ravines"]
var settings:Resource
var beach
var seed_value:int
var _host:WeakRef
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _detail:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _patches:Dictionary={}
var _regions:Dictionary={}
var _formations:Dictionary={}
var state:=PackedFloat64Array()
var neutral:=PackedFloat64Array()
var profile:bool=false
var timings:Dictionary={}
func configure(config:Resource,seed:int,host:RefCounted)->void:
	settings=config;seed_value=seed;_host=weakref(host)
	beach=null
	if host.settings.beaches_enabled:
		beach=preload("res://scripts/beach_sampler.gd").new();beach.configure(host.settings.beach,self)
	neutral.resize(CHANNELS);neutral.fill(0);state=neutral
	for entry in [[_macro,31013,1.0/settings.bay_scale],[_meso,31039,1.0/220],[_detail,31051,1.0/48]]:
		var n:FastNoiseLite=entry[0];n.seed=seed+entry[1];n.frequency=entry[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=2;n.fractal_gain=.3
	_nodes.clear();_patches.clear();_regions.clear();_formations.clear();timings.clear()
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff;return float(h^(h>>16))/2147483647.0
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:=Vector2(cell)*512;var span:float=settings.region_metres;var center:=Vector2i(floori(p.x/span),floori(p.y/span));var sites:Array=[];var closest:float=INF
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=center+Vector2i(x,z);var point:Vector2=(Vector2(q)+Vector2(.15+random(q.x,q.y,3)*.7,.15+random(q.x,q.y,5)*.7))*span
			var d:float=p.distance_to(point);closest=minf(closest,d);sites.append([d,mini(15,int(random(q.x,q.y,7)*16))])
	var result:=PackedFloat32Array();result.resize(16);var total:float=0
	for item:Array in sites:
		var amount:float=1-smoothstep(0,span*.22,float(item[0])-closest);result[item[1]]+=amount;total+=amount
	for i in range(16):result[i]/=maxf(total,.001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=result;return result
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/512;var c:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(c)
	var a:PackedFloat32Array=_region_node(c);var b:PackedFloat32Array=_region_node(c+Vector2i.RIGHT);var d:PackedFloat32Array=_region_node(c+Vector2i.DOWN);var e:PackedFloat32Array=_region_node(c+Vector2i.ONE)
	if a==b and a==d and a==e:return a
	var result:=PackedFloat32Array();result.resize(16)
	for i in range(16):result[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(d[i],e[i],f.x),f.y)
	return result
func max_width()->float:
	var rock:float=settings.influence_width*3.5+settings.stack_size*4+500
	if beach==null:return rock
	return maxf(rock,maxf(2500,beach.settings.beach_width*(1+2.4*beach.settings.width_variation)+beach.settings.foredune_width*1.35+1600)+500)
func influence_width(w:PackedFloat32Array,a:float)->float:
	return settings.influence_width*(.65+w[0]*.8+w[7]*.4+w[11]*.5+w[10]*.6)*(1+a*.25)
func may_affect(x:float,z:float,distance_hint:float)->bool:
	if beach!=null:
		if absf(distance_hint)>max_width()*2:state=neutral;return false
		if fposmod(x,STEP)==0 and fposmod(z,STEP)==0:
			var p:=Vector2(x,z);var w:PackedFloat32Array=region_weights(p);var a:float=_macro.get_noise_2d(x,z)
			var sand_width:float=maxf(2500,beach.settings.beach_width*(1+2.4*beach.settings.width_variation)+beach.settings.foredune_width*1.35+1600)
			if absf(distance_hint)>2*influence_width(w,a) and absf(beach.shore_distance(p))>sand_width+500:state=neutral;return false
		return true
	if settings.coverage<=0 or absf(distance_hint)>max_width():state=neutral;return false
	# Exact canonical-node query: distance / clamped_gradient is at least
	# abs(distance)/2. If even that exceeds this node's regional width, its
	# influence is provably zero. Do not apply this shortcut off the lattice:
	# neighboring bicubic support could still contribute there.
	if fposmod(x,STEP)!=0 or fposmod(z,STEP)!=0:return true
	var p:=Vector2(x,z);var w:PackedFloat32Array=region_weights(p);var a:float=_macro.get_noise_2d(p.x,p.y)
	if absf(distance_hint)>2*influence_width(w,a):state=neutral;return false
	if settings.coverage<.999:
		var selector:float=_macro.get_noise_2d(p.x*.23+81731,p.y*.23-73191)*.5+.5
		if selector>=settings.coverage+.08:state=neutral;return false
	return true
func coast_frame(p:Vector2)->Vector3:
	var host:RefCounted=_host.get_ref();var radius:float=maxf(host.settings.island_size*.5,8)
	var d:float=host._island_mask(p.x,p.y)*radius
	var g:=Vector2(host._island_mask(p.x+16,p.y)-host._island_mask(p.x-16,p.y),host._island_mask(p.x,p.y+16)-host._island_mask(p.x,p.y-16))*radius/32
	var length:float=g.length();g/=maxf(length,.001)
	return Vector3(d/clampf(length,.5,2),g.x,g.y)
func _formation_sites(cell:Vector2i)->Array:
	if _formations.has(cell):return _formations[cell]
	var result:Array=[]
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=cell+Vector2i(x,z);var roll:float=random(q.x,q.y,431)
			if roll>settings.stack_frequency:continue
			var p:Vector2=(Vector2(q)+Vector2(.2+random(q.x,q.y,433)*.6,.2+random(q.x,q.y,439)*.6))*768
			# Major remnant peaks sit on the coarsest supported coastal lattice.
			# Their silhouettes may simplify, but their summits cannot fall
			# between all far-LOD vertices and disappear entirely.
			var anchor:float=128 # Fixed world lattice, never a camera/quality input.
			p=(p/anchor).round()*anchor
			var frame:Vector3=coast_frame(p)
			if frame.x> -100 or frame.x< -650:continue
			result.append([p,roll,frame.x])
	if _formations.size()>=512:_formations.clear()
	_formations[cell]=result;return result
func inherited_river(p:Vector2)->float:
	var host:RefCounted=_host.get_ref();var river:float=0
	if host.settings.grass_river_frequency<=0:return river
	var spacing:float=4000/maxf(host.settings.grass_river_frequency,.1);var lane:int=roundi(p.y/spacing)
	for k in [-1,0,1]:river=maxf(river,1-smoothstep(18,80,absf(p.y-host._grass_river_center(p.x,lane+k,spacing))))
	return river
func inherited_river_distance(p:Vector2)->float:
	var host:RefCounted=_host.get_ref();var distance:float=INF
	if host.settings.grass_river_frequency<=0:return distance
	var spacing:float=4000/maxf(host.settings.grass_river_frequency,.1);var lane:int=roundi(p.y/spacing)
	for k in [-1,0,1]:distance=minf(distance,absf(p.y-host._grass_river_center(p.x,lane+k,spacing)))
	return distance
func _raw(p:Vector2)->PackedFloat64Array:
	if beach==null:return _raw_rock(p)
	var frame:Vector3=coast_frame(p);var w:PackedFloat32Array=region_weights(p)
	var a:float=_macro.get_noise_2d(p.x,p.y);var b:float=_meso.get_noise_2d(p.x,p.y);var c:float=_detail.get_noise_2d(p.x,p.y)
	var river_distance:float=inherited_river_distance(p);var river:float=1-smoothstep(18,80,river_distance)
	var s:PackedFloat64Array=beach.evaluate(p,frame,w,a,b,c,river_distance)
	if s[1]>=1:
		var result:=PackedFloat64Array();result.resize(CHANNELS);result.fill(0)
		result[0]=s[0];result[2]=1;result[3]=s[2];result[4]=s[3];result[5]=s[4];result[6]=frame.x;result[7]=frame.y;result[8]=frame.z;result[18]=river;result[19]=1;result[20]=s[2]
		return result
	var result:PackedFloat64Array=_raw_rock(p);var combined:float=lerpf(result[2],1,s[1])
	if combined>0:
		var amount:float=s[1]/combined;result[0]=lerpf(result[0],s[0],amount);result[1]*=1-amount;result[19]=amount
	result[2]=combined;result[20]=s[2];return result
func _raw_rock(p:Vector2)->PackedFloat64Array:
	var start:int=Time.get_ticks_usec() if profile else 0
	var frame:Vector3=coast_frame(p);var original_d:float=frame.x;var n:=Vector2(frame.y,frame.z);var tangent:=Vector2(-n.y,n.x)
	var w:PackedFloat32Array=region_weights(p);var id:int=0
	for i in range(1,16):
		if w[i]>w[id]:id=i
	var a:float=_macro.get_noise_2d(p.x,p.y);var b:float=_meso.get_noise_2d(p.x,p.y);var c:float=_detail.get_noise_2d(p.x,p.y)
	var selector:float=_macro.get_noise_2d(p.x*.23+81731,p.y*.23-73191)*.5+.5
	var ownership:float=1-smoothstep(settings.coverage-.08,settings.coverage+.08,selector)
	if settings.coverage>=.999:ownership=1
	if settings.coverage<=0:ownership=0
	var width:float=influence_width(w,a)
	var influence:float=ownership*(1-smoothstep(width*.6,width,absf(original_d)))
	var headland:float=a*settings.headlands*(300+w[2]*450-w[3]*120)
	var d:float=original_d+headland*(1-smoothstep(width*.35,width*.9,absf(original_d)))
	var exposure:float=clampf(.55+.4*(-n).dot(Vector2(.8,-.6))+a*.15-w[3]*.35-w[13]*.35,0,1)
	var platform:float=clampf((w[1]*.5+w[4]+w[5]*.5+w[7]*.35+w[9]*.5+w[14]*.7)*settings.platform_frequency*1.5,0,1)
	var shelf_width:float=settings.platform_width*(.25+platform)*(1+b*.25)
	var heights:Array=[1.1,.2,.9,.15,.3,.25,.65,.7,.9,.5,1.0,.9,.7,.18,.1,.4]
	var height:float=0
	for i in range(16):height+=w[i]*heights[i]
	height*=settings.cliff_height*(.8+a*.25+b*.15)*settings.cliff_frequency
	var cliff_width:float=settings.cliff_width*(1+w[3]*1.8+w[5]+w[14]*1.2+w[7]*.5)
	var rise:float=smoothstep(shelf_width*.5+b*20,shelf_width*.5+cliff_width+b*20,d)
	var platform_h:float=1.5+(b*.7+c*.3)*settings.platform_relief
	var h:float=platform_h+rise*height+maxf(d-shelf_width-cliff_width,0)*.035
	var submerged:float=-6-(1-platform)*10
	h=lerpf(submerged, h,smoothstep(-shelf_width,0,d))
	# Coherent weathered ledges; finite-width geometry, not vertical extrusion.
	var weather:float=(1-smoothstep(.03,.3,absf(b+c*.15)))*settings.erosion*rise*(1-rise*.6)
	h-=weather*(12+w[15]*30)
	h+=sin(d/34+b*1.5)*rise*(1-rise)*8*w[8]
	h+=c*settings.ruggedness*(3+w[5]*4)*smoothstep(-20,80,d)
	var host:RefCounted=_host.get_ref();var spacing:float=4000/maxf(host.settings.grass_river_frequency,.1)
	var river:float=0
	if host.settings.grass_river_frequency>0:
		var lane:int=roundi(p.y/spacing)
		for k in [-1,0,1]:river=maxf(river,1-smoothstep(18,80+w[13]*100,absf(p.y-host._grass_river_center(p.x,lane+k,spacing))))
	var inlet:float=(1-smoothstep(.015,.12,absf(b)))*(w[10]+w[13]+w[15]*.6)*settings.inlet_frequency
	var outlet:float=maxf(river,inlet)*(1-smoothstep(width*.45,width*.95,maxf(d,0)))
	h=lerpf(h,-1.2+maxf(d,0)*.001,outlet)
	var stack:float=0
	if original_d<100 and original_d> -850 and w[6]+w[2]+w[7]+w[14]>.1:
		for site:Array in _formation_sites(Vector2i(floori(p.x/768),floori(p.y/768))):
			var size:float=settings.stack_size*(.7+site[1]*2)
			var q:Vector2=p-site[0];var length:float=Vector2(q.dot(tangent)/size,q.dot(n)/(size*.65)).length()
			var shape:float=1-smoothstep(.25,.95,length+sin(q.dot(tangent)/100)*.1)
			var tower:float=shape*(45+height*(.5+site[1]))-8
			h=maxf(h,tower);stack=maxf(stack,shape)
	var pool:float=0;var pool_water:float=0;var connected_pool:float=0
	if platform>.12 and rise<.2 and outlet<.1 and d> -40 and d<shelf_width*.7:
		var q:Vector2=p/96;var cell:=Vector2i(floori(q.x),floori(q.y))
		for z in range(-1,2):
			for x in range(-1,2):
				var k:=cell+Vector2i(x,z);var r:float=random(k.x,k.y,503)
				if r>settings.pool_frequency:continue
				var center:Vector2=(Vector2(k)+Vector2(.2+random(k.x,k.y,509)*.6,.2+random(k.x,k.y,521)*.6))*96
				var delta:Vector2=p-center;var size:float=settings.pool_size*(.65+r*.8)
				var contour:float=Vector2(delta.dot(tangent)/size,delta.dot(n)/(size*(.45+r))).length()+c*.15
				var compound:bool=r<settings.pool_frequency*.35
				if compound:
					# Overlapping lobes share one real basin and water elevation;
					# this is not two unrelated circles labelled "connected".
					var second:Vector2=delta-tangent*size*.8-n*size*.3
					contour=minf(contour,Vector2(second.dot(tangent)/(size*.85),second.dot(n)/(size*.7)).length()+c*.1)
				var support:float=1-smoothstep(.6,1.25,contour);var bed:float=1-smoothstep(.15,.7,contour)
				h=lerpf(h,1.8+(.4-bed*(.4+settings.pool_depth)),support*platform)
				pool=maxf(pool,bed*support*platform);pool_water=maxf(pool_water,1.8*support)
				if compound:connected_pool=maxf(connected_pool,bed*support*platform)
	var sediment:float=clampf((w[3]+w[5]+w[13]*.6)*(1-exposure*.5)*(1-rise)*(1-stack),0,1)
	if profile:timings["coastal_fields_us"]=timings.get("coastal_fields_us",0)+Time.get_ticks_usec()-start
	return PackedFloat64Array([h,pool_water,influence,float(id)/15,exposure,sediment,original_d,frame.y,frame.z,rise,height,headland,platform,pool,stack,outlet,weather,connected_pool,river,0,0])
func _node(cell:Vector2i)->PackedFloat64Array:
	if _nodes.has(cell):return _nodes[cell]
	var result:PackedFloat64Array=_raw(Vector2(cell)*STEP)
	if _nodes.size()>=8192:_nodes.clear()
	_nodes[cell]=result;return result
func cubic(a:float,b:float,c:float,d:float,t:float)->float:return b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)))
func bounded_influence(value:float)->float:
	# Catmull-Rom may overshoot its endpoints. A hard clamp introduces a
	# derivative kink at zero/one; this narrow C1 shoulder has zero end slope.
	if value<.05:return maxf(value,0)*smoothstep(0,.05,value)
	if value>.95:return 1-maxf(1-value,0)*smoothstep(0,.05,1-value)
	return value
func sample(x:float,z:float,base:float,distance_hint:float,publish:bool=true)->float:
	if absf(distance_hint)>max_width()* (2 if beach!=null else 1) or (settings.coverage<=0 and beach==null):
		if publish:state=neutral
		return base
	# Keep global query coordinates double precision until the small cell
	# remainder. A Vector2(world_x, world_z) rounded centimetre probes at 200 km.
	var qx:float=x/STEP;var qz:float=z/STEP;var cell:=Vector2i(floori(qx),floori(qz));var f:=Vector2(qx-cell.x,qz-cell.y)
	if f==Vector2.ZERO:
		var exact:PackedFloat64Array=_node(cell).duplicate();exact[2]=bounded_influence(exact[2])
		if publish:state=exact
		return lerpf(base,exact[0],exact[2])

	var coefficients:PackedFloat64Array=_patch(cell);var s:=PackedFloat64Array();s.resize(CHANNELS)
	for k in range(3):
		var base_index:int=k*16;var column:=PackedFloat64Array()
		for i in range(4):
			var offset:int=base_index+i*4
			column.append(coefficients[offset]+f.y*(coefficients[offset+1]+f.y*(coefficients[offset+2]+f.y*coefficients[offset+3])))
		s[k]=column[0]+f.x*(column[1]+f.x*(column[2]+f.x*column[3]))
	for k in range(3,CHANNELS):
		var offset:int=48+(k-3)*4
		s[k]=coefficients[offset]+coefficients[offset+1]*f.x+coefficients[offset+2]*f.y+coefficients[offset+3]*f.x*f.y
	s[2]=bounded_influence(s[2]);s[3]=clampf(s[3],0,1);s[4]=clampf(s[4],0,1);s[5]=clampf(s[5],0,1);s[1]=maxf(s[1],0)
	if publish:state=s
	return lerpf(base,s[0],s[2])

func polynomial(a:float,b:float,c:float,d:float)->PackedFloat64Array:
	return PackedFloat64Array([b,(c-a)*.5,a-2.5*b+2*c-.5*d,-.5*a+1.5*b-1.5*c+.5*d])
func _patch(cell:Vector2i)->PackedFloat64Array:
	if _patches.has(cell):return _patches[cell]
	var nodes:Array[PackedFloat64Array]=[]
	for z in range(-1,3):
		for x in range(-1,3):nodes.append(_node(cell+Vector2i(x,z)))
	var result:=PackedFloat64Array();result.resize(48+(CHANNELS-3)*4)
	for k in range(3):
		var rows:Array[PackedFloat64Array]=[]
		for row in range(4):rows.append(polynomial(nodes[row*4][k],nodes[row*4+1][k],nodes[row*4+2][k],nodes[row*4+3][k]))
		for column in range(4):
			var p:PackedFloat64Array=polynomial(rows[0][column],rows[1][column],rows[2][column],rows[3][column])
			for j in range(4):result[k*16+column*4+j]=p[j]
	# Appearance fields are bounded bilinear controls, not geometric surfaces.
	for k in range(3,CHANNELS):
		var a:float=nodes[5][k];var b:float=nodes[6][k];var c:float=nodes[9][k];var d:float=nodes[10][k];var offset:int=48+(k-3)*4
		result[offset]=a;result[offset+1]=b-a;result[offset+2]=c-a;result[offset+3]=d-b-c+a
	if _patches.size()>=2048:_patches.clear()
	_patches[cell]=result;return result
