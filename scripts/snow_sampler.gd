extends RefCounted
## Worker-owned static Snow geography. One canonical 64 m Hermite field for
## every LOD; micro structure belongs in the material, not extra vertices.
enum Region { PLAINS,TUNDRA,ALPINE,GLACIAL,LAKES,ARCTIC,PLATEAU,VALLEY }
const NAMES=["Great snow plains","Windswept tundra","Alpine range","Glacial highlands","Frozen lake district","Rocky Arctic highlands","Snow plateau","Glacial valley"]
const COLORS=[Vector3(.75,.88,1),Vector3(.55,.65,.38),Vector3(.85,.25,.12),Vector3(.1,.7,.9),Vector3(.3,.4,.95),Vector3(.5,.35,.25),Vector3(.8,.6,.9),Vector3(.15,.8,.5)]
const STEP:float=64.0
const LIMIT:int=16384
var settings:SnowSettings
var seed_value:int
var phase:float
var _angle:float
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _structure:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _regions:Dictionary={}
var _sites:Dictionary={}
var _quad_cell:=Vector2i(2147483647,2147483647)
var _quad:Array=[]
var _raw_depth:float
var _raw_surface:=Vector4.ZERO
var _raw_flow:=Vector4.ZERO
var a:=Vector4.ZERO # region RGB, normalized depth
var b:=Vector4.ZERO # exposure, glacier, lake ice, river ice
var c:=Vector4.ZERO # rock, strain, encoded flow XY
var last_lowland:float=0.0
var last_moraine:float=0.0
var last_drift:float=0.0
func configure(config:SnowSettings,world_seed:int)->void:
	settings=config;seed_value=world_seed;phase=float(world_seed%10007)*.013
	_angle=deg_to_rad(settings.wind_degrees)
	for item in [[_macro,8111,1.0/2600.0,2],[_meso,8147,1.0/620.0,2],[_structure,8231,1.0/2100.0,1]]:
		var noise:FastNoiseLite=item[0];noise.seed=world_seed+int(item[1]);noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency=item[2];noise.fractal_type=FastNoiseLite.FRACTAL_FBM;noise.fractal_octaves=item[3];noise.fractal_gain=.4
	_nodes.clear();_regions.clear();_sites.clear()
	_quad.clear();_quad_cell=Vector2i(2147483647,2147483647)
func _hash(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _site(cell:Vector2i)->Vector4:
	if _sites.has(cell):return _sites[cell]
	var q:float=_hash(cell.x,cell.y,31)
	var p:float=clampf(settings.plains_frequency,0,1);var t:float=clampf(settings.tundra_frequency,0,1)
	var m:float=clampf(settings.alpine_frequency,0,1);var g:float=clampf(settings.glacial_frequency,0,1)
	var total:float=maxf(1.0,p+t+m+g+.29)
	q*=total
	var id:int
	if q<p:id=0
	elif q<p+t:id=1
	elif q<p+t+m:id=2
	elif q<p+t+m+g:id=3
	else:id=4+clampi(int((q-p-t-m-g)/maxf(total-p-t-m-g,.0001)*4.0),0,3)
	var span:float=maxf(settings.region_metres,4000)
	var site:=Vector4((cell.x+.2+_hash(cell.x,cell.y,37)*.6)*span,(cell.y+.2+_hash(cell.x,cell.y,41)*.6)*span,id,_hash(cell.x,cell.y,43))
	if _sites.size()>=256:_sites.clear()
	_sites[cell]=site;return site
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var span:float=maxf(settings.region_metres,4000)
	var p:=Vector2(cell)*512.0
	var q:Vector2=p+Vector2(_macro.get_noise_2d(p.x*.25,p.y*.25),_macro.get_noise_2d(p.x*.25+9473,p.y*.25-2191))*span*.12
	var center:=Vector2i(floori(q.x/span),floori(q.y/span))
	var sites:Array[Vector4]=[];var distances:PackedFloat32Array=[];var nearest:float=INF
	for z in range(-1,2):
		for x in range(-1,2):
			var site:Vector4=_site(center+Vector2i(x,z));sites.append(site)
			var distance:float=q.distance_to(Vector2(site.x,site.y));distances.append(distance);nearest=minf(nearest,distance)
	var result:=PackedFloat32Array();result.resize(9);var sum:float=0.0
	for i in range(9):
		var weight:float=1.0-smoothstep(0,span*.23,distances[i]-nearest)
		result[int(sites[i].z)]+=weight;result[8]+=sites[i].w*weight;sum+=weight
	for i in range(9):result[i]/=maxf(sum,.0001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=result;return result
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/512.0;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var aa:PackedFloat32Array=_region_node(cell)
	if f==Vector2.ZERO:return aa
	var bb:PackedFloat32Array=_region_node(cell+Vector2i.RIGHT);var cc:PackedFloat32Array=_region_node(cell+Vector2i.DOWN);var dd:PackedFloat32Array=_region_node(cell+Vector2i.ONE)
	if aa==bb and aa==cc and aa==dd:return aa
	# Do not ease every regional grid cell independently: forcing every 512 m
	# boundary tangent to zero produced repeated shelves across alpine slopes.
	# The canonical Hermite heightfield supplies C1 surface continuity instead.
	var result:=PackedFloat32Array();result.resize(9)
	for i in range(9):result[i]=lerpf(lerpf(aa[i],bb[i],f.x),lerpf(cc[i],dd[i],f.x),f.y)
	return result
func wind_coordinates(p:Vector2)->Vector2:
	return p.rotated(-_angle)+Vector2(sin(p.x/12000.0+phase)*cos(p.y/15000.0-phase),cos(p.x/17000.0-phase)*sin(p.y/11000.0+phase))*settings.wind_variation*400.0
func _shape(p:Vector2,w:PackedFloat32Array,publish:bool)->float:
	var macro:float=_macro.get_noise_2d(p.x,p.y)
	var meso:float=_meso.get_noise_2d(p.x,p.y)
	# Prevailing wind changes deposits, not the position of mountain chains.
	var terrain_angle:float=phase*.13+.37
	var q:Vector2=p.rotated(-terrain_angle)
	var ridge:float=0;var mountain:float=0;var gully:float=0
	# Exact zero-weight pruning: plains/lakes/plateaus never evaluate unused
	# mountain chains or glaciers. Transition weights retain the complete field.
	if w[2]>0 or w[3]>0 or w[5]>0 or w[7]>0:
		var spine:float=sin(q.x/5700.0+phase)*1300.0+sin(q.x/2300.0-phase*.7)*270.0
		var across:float=fposmod(q.y-spine+8000.0,16000.0)-8000.0
		var ridge_width:float=lerpf(1900.0,450.0,settings.ruggedness)
		ridge=exp(-pow(absf(across)/ridge_width,1.6))
		var peaks:float=.7+.35*_macro.get_noise_2d(q.x*.7+3191,q.y*.08)
		var ribs:float=1.0-absf(_structure.get_noise_2d(q.x*.7,q.y*1.8))
		mountain=settings.mountain_height*(ridge*peaks+pow(ribs,3)*ridge*.14*settings.ruggedness)
		# Narrower alpine backbones and irregular rock spurs, not white rolling
		# hills. Reuse the existing structural field; no extra octave evaluation.
		mountain+=settings.mountain_height*pow(ribs,8)*ridge*.5*settings.ruggedness
		gully=(1.0-smoothstep(.04,.28,absf(meso)))*smoothstep(.1,.7,ridge)
		mountain-=gully*24.0*settings.ruggedness
	var lateral:float=2;var reach:float=0;var floor_height:float=0;var uvalley:float=0;var glacial_height:float=0;var glacier:float=0;var moraine:float=0;var strain:float=0
	if w[3]>0 or w[7]>0:
		var flow_t:float=fposmod(q.x,maxf(settings.glacier_length,6000.0))/maxf(settings.glacier_length,6000.0)
		var flow_bend:float=sin(q.x/3100.0+phase)*420.0+sin(q.x/7300.0-phase)*650.0
		var valley_across:float=fposmod(q.y-flow_bend+8000.0,16000.0)-8000.0
		var width:float=maxf(settings.glacier_width,400.0)*lerpf(1.25,.45,flow_t)*(1.0+meso*.16)
		lateral=absf(valley_across)/width
		reach=smoothstep(.02,.10,flow_t)*(1.0-smoothstep(.83,.99,flow_t))
		floor_height=lerpf(510.0,45.0,flow_t)+meso*2.0
		uvalley=floor_height+pow(minf(lateral*.55,1.6),2.0)*settings.mountain_height*.64
		glacial_height=lerpf(100.0+mountain,uvalley,reach*(1.0-smoothstep(1.4,2.6,lateral)))
		glacier=(w[3]+w[7]*.85)*reach*(1.0-smoothstep(.72,1.04,lateral))
		moraine=(w[3]+w[7])*reach*(1.0-smoothstep(.06,.22,absf(lateral-1.07)))
		strain=glacier*clampf(.25+absf(cos(q.x/3100.0+phase))*.4+smoothstep(.75,.25,width/maxf(settings.glacier_width,400))*.3,0,1)
	var plateau:float=65.0+smoothstep(-.17,.13,macro)*(280.0+w[8]*220.0)+meso*8.0 if w[6]>0 else 0.0
	var h:float=w[0]*(22.0+macro*7.0+meso*.7)+w[1]*(40.0+macro*42.0+meso*10.0)
	h+=w[2]*(55.0+mountain)+w[3]*glacial_height+w[4]*(18.0+macro*6.0+meso*1.0)
	h+=w[5]*(65.0+mountain*.48+meso*26.0)+w[6]*plateau+w[7]*(uvalley*reach+(45.0+mountain*.7)*(1.0-reach))
	h+=moraine*12.0
	h=lerpf(h,floor_height+18.0+meso*3.0,glacier)
	# Finite depressions, not tunnels or traversable holes. Same height query
	# is used by meshes and future collision; small fractures are shader-only.
	var transverse_fracture:float=absf(sin(q.x/180.0+meso*3.0))
	h-=glacier*strain*settings.crevasse_amount*(1.0-smoothstep(.1,.5,transverse_fracture))*5.0
	var exposure:float=clampf(w[1]*.55+w[5]*.65+ridge*(w[2]+w[3])*.75+w[6]*.2,0,1)*settings.wind_exposure
	var shelter:float=clampf(gully*(w[2]+w[5])*.6+(1.0-ridge)*(w[2]+w[5])*.35+(w[7]+w[3])*(1.0-smoothstep(.7,1.4,lateral))*.65,0,1)
	var depth:float=settings.snow_depth*(.45+w[0]*.9+w[4]*.6+shelter*settings.sheltered_accumulation*1.8)*(1.0-exposure*.82)
	depth*=lerpf(.75,1.2,smoothstep(-.35,.35,_macro.get_noise_2d(p.x*2600.0/maxf(settings.accumulation_metres,300.0),p.y*2600.0/maxf(settings.accumulation_metres,300.0))))
	var wind:Vector2=wind_coordinates(p)
	var drift_gate:float=smoothstep(.05,.40,meso)*settings.drift_frequency*(shelter+w[0]*.3+w[6]*.4)
	var length:float=maxf(settings.drift_length,120);var drift_width:float=maxf(settings.drift_width,40)
	var carrier:float=sin(wind.y/drift_width+meso*1.6)*.5+.5
	var crest:float=pow(carrier,3.0)*(0.5+0.5*cos(wind.x/length+macro))
	var drift:float=crest*drift_gate*settings.drift_height
	h+=depth*.55+drift
	if publish:
		_raw_depth=depth+drift
		_raw_surface=Vector4(exposure,glacier,clampf((w[2]+w[3]*.85+w[5]*.8+w[6]*.4+w[7]*.7)*settings.rock_exposure,0,1),strain)
		var tangent:=Vector2(1.0,cos(q.x/3100.0+phase)*420.0/3100.0+cos(q.x/7300.0-phase)*650.0/7300.0).rotated(terrain_angle).normalized()
		_raw_flow=Vector4(tangent.x,tangent.y,moraine,drift)
	return h
func _node(cell:Vector2i)->Array:
	if _nodes.has(cell):return _nodes[cell]
	var p:=Vector2(cell)*STEP;var w:PackedFloat32Array=region_weights(p)
	var h:float=_shape(p,w,true)
	var surface:Vector4=_raw_surface;var flow:Vector4=_raw_flow;var depth:float=_raw_depth
	# Derivatives must include regional blending. Holding w fixed gave every
	# 64 m knot an artificially flat tangent through region transitions, making
	# the exact Hermite normal reveal a regular ladder/grill on smooth slopes.
	var px:Vector2=p+Vector2(16,0);var pz:Vector2=p+Vector2(0,16)
	var dx:float=(_shape(px,region_weights(px),false)-h)/16.0
	var dz:float=(_shape(pz,region_weights(pz),false)-h)/16.0
	var slope:float=1.0-1.0/sqrt(1.0+dx*dx+dz*dz)
	var facing:float=(dx*cos(_angle)+dz*sin(_angle))/sqrt(1.0+dx*dx+dz*dz)
	var settled:float=depth*(1.0-smoothstep(.12,.65,slope*settings.slope_influence)*.85)
	settled*=1.0+maxf(-facing,0)*settings.sheltered_accumulation*.6
	settled*=1.0+clampf(h/maxf(settings.mountain_height,300),0,1)*.2
	# Accumulation already contributes geometry in _shape. Retention modifies
	# the material depth, not node heights after their derivatives were computed.
	depth=settled
	surface.x=clampf(surface.x+maxf(facing,0)*settings.wind_exposure*.3,0,1)
	var color:=Vector3.ZERO
	for i in range(8):color+=COLORS[i]*w[i]
	var lowland:float=clampf(w[0]+w[1]*.65+w[4],0,1)
	var value:Array=[Vector4(h,dx,dz,depth),surface,Vector4(color.x,color.y,color.z,lowland),flow]
	if _nodes.size()>=LIMIT:_nodes.clear()
	_nodes[cell]=value;return value
func _hermite(v0:float,v1:float,d0:float,d1:float,t:float)->float:
	var t2:float=t*t;var t3:float=t2*t
	return (2*t3-3*t2+1)*v0+(t3-2*t2+t)*d0+(-2*t3+3*t2)*v1+(t3-t2)*d1
func _hermite_d(v0:float,v1:float,d0:float,d1:float,t:float)->float:
	return (6*t*t-6*t)*v0+(3*t*t-4*t+1)*d0+(-6*t*t+6*t)*v1+(3*t*t-2*t)*d1
func gradient(x:float,z:float)->Vector2:
	# Exact derivative of the SAME Hermite heightfield, not another noise field.
	# At sparse parent vertices this needs one existing node, not four extra
	# neighbouring height queries and their otherwise-unused control payloads.
	var q:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var av:Vector4=_node(cell)[0]
	if f==Vector2.ZERO:return Vector2(av.y,av.z)
	var bv:Vector4=_node(cell+Vector2i.RIGHT)[0];var cv:Vector4=_node(cell+Vector2i.DOWN)[0];var dv:Vector4=_node(cell+Vector2i.ONE)[0]
	var sx:float=f.x*f.x*(3.0-2.0*f.x);var dsx:float=6*f.x*(1-f.x)
	var hx0:float=_hermite(av.x,bv.x,av.y*STEP,bv.y*STEP,f.x);var hx1:float=_hermite(cv.x,dv.x,cv.y*STEP,dv.y*STEP,f.x)
	var dx0:float=_hermite_d(av.x,bv.x,av.y*STEP,bv.y*STEP,f.x)/STEP;var dx1:float=_hermite_d(cv.x,dv.x,cv.y*STEP,dv.y*STEP,f.x)/STEP
	return Vector2(_hermite(dx0,dx1,(bv.z-av.z)*dsx,(dv.z-cv.z)*dsx,f.y),_hermite_d(hx0,hx1,lerpf(av.z,bv.z,sx)*STEP,lerpf(cv.z,dv.z,sx)*STEP,f.y)/STEP)
func sample(x:float,z:float,publish:bool=true)->float:
	var q:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var aa:Array=_quad[0] if cell==_quad_cell else _node(cell)
	if f==Vector2.ZERO:
		var av:Vector4=aa[0];var surface:Vector4=aa[1];var region:Vector4=aa[2];var flow:Vector4=aa[3]
		last_lowland=region.w
		b=Vector4(surface.x,surface.y,0,0) if publish else Vector4.ZERO
		if publish:
			a=Vector4(region.x,region.y,region.z,clampf(av.w/12.0,0,1))
			c=Vector4(surface.z,surface.w,flow.x*.5+.5,flow.y*.5+.5)
			last_moraine=flow.z;last_drift=flow.w
		return av.x
	if cell!=_quad_cell:
		_quad=[aa,_node(cell+Vector2i.RIGHT),_node(cell+Vector2i.DOWN),_node(cell+Vector2i.ONE)]
		_quad_cell=cell
	var bb:Array=_quad[1];var cc:Array=_quad[2];var dd:Array=_quad[3]
	var av:Vector4=aa[0];var bv:Vector4=bb[0];var cv:Vector4=cc[0];var dv:Vector4=dd[0]
	var hx0:float=_hermite(av.x,bv.x,av.y*STEP,bv.y*STEP,f.x)
	var hx1:float=_hermite(cv.x,dv.x,cv.y*STEP,dv.y*STEP,f.x)
	var blend_x:float=f.x*f.x*(3.0-2.0*f.x)
	var h:float=_hermite(hx0,hx1,lerpf(av.z,bv.z,blend_x)*STEP,lerpf(cv.z,dv.z,blend_x)*STEP,f.y)
	if not publish:
		var region:Vector4=(aa[2] as Vector4).lerp(bb[2],f.x).lerp((cc[2] as Vector4).lerp(dd[2],f.x),f.y)
		last_lowland=region.w
		b=Vector4.ZERO
		return h
	var surface:Vector4=(aa[1] as Vector4).lerp(bb[1],f.x).lerp((cc[1] as Vector4).lerp(dd[1],f.x),f.y)
	var region:Vector4=(aa[2] as Vector4).lerp(bb[2],f.x).lerp((cc[2] as Vector4).lerp(dd[2],f.x),f.y)
	var flow:Vector4=(aa[3] as Vector4).lerp(bb[3],f.x).lerp((cc[3] as Vector4).lerp(dd[3],f.x),f.y)
	var depth:float=lerpf(lerpf(av.w,bv.w,f.x),lerpf(cv.w,dv.w,f.x),f.y)
	a=Vector4(region.x,region.y,region.z,clampf(depth/12.0,0,1));b=Vector4(surface.x,surface.y,0,0)
	c=Vector4(surface.z,surface.w,flow.x*.5+.5,flow.y*.5+.5)
	last_lowland=region.w;last_moraine=flow.z;last_drift=flow.w
	return h
func freeze(p:Vector2,coverage:float,cold:float)->float:
	if coverage<=0 or cold<=0:return 0.0
	if coverage>=1:return cold
	var field:float=.5+_macro.get_noise_2d(p.x*.65+2719,p.y*.65-919)*.35+_meso.get_noise_2d(p.x+1931,p.y-711)*.45
	return (1.0-smoothstep(coverage-.035,coverage+.035,field))*cold
func pack()->PackedFloat32Array:
	return PackedFloat32Array([
		roundi(clampf(a.x,0,1)*255.0)+roundi(clampf(a.y,0,1)*255.0)*256+roundi(clampf(a.z,0,1)*255.0)*65536,
		roundi(clampf(a.w,0,1)*255.0)+roundi(clampf(b.x,0,1)*255.0)*256+roundi(clampf(b.y,0,1)*255.0)*65536,
		roundi(clampf(b.z,0,1)*255.0)+roundi(clampf(b.w,0,1)*255.0)*256+roundi(clampf(c.x,0,1)*255.0)*65536,
		roundi(clampf(c.y,0,1)*255.0)+roundi(clampf(c.z,0,1)*255.0)*256+roundi(clampf(c.w,0,1)*255.0)*65536])
