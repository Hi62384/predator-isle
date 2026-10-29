extends RefCounted
## Pure numerical coastal deposition, evaluated on the existing 8 m coast lattice.
## Ocean-connected lagoons use the ocean, not overlapping local water meshes.
const NAMES=["wide_beach","narrow_beach","dune_field","high_foredunes","backdunes","parabolic_dunes","sandy_cove","barrier_beach","sand_spit","lagoon","tidal_flat","sandy_estuary","low_sandy_island","storm_scarps","mixed_rock_sand","sandbars"]
var settings:Resource
var _coast:WeakRef
var _wind:=FastNoiseLite.new()
var _shore_nodes:Dictionary={}
var _shore_patches:Dictionary={}
func configure(config:Resource,coast:RefCounted)->void:
	settings=config;_coast=weakref(coast);_wind.seed=coast.seed_value+61441;_wind.frequency=1.0/9000;_wind.fractal_octaves=2
func wind_angle(p:Vector2)->float:
	# Same slowly varying analytic wind in CPU geometry and GPU ripple projection.
	return deg_to_rad(settings.wind_degrees)+deg_to_rad(settings.wind_variation)*sin(p.x/18000+sin(p.y/21000))
func _shore_node(cell:Vector2i)->float:
	if _shore_nodes.has(cell):return _shore_nodes[cell]
	var coast:RefCounted=_coast.get_ref();var host:RefCounted=coast._host.get_ref();var p:=Vector2(cell)*256
	var value:float=host._island_mask(p.x,p.y)*maxf(host.settings.island_size*.5,8)
	if _shore_nodes.size()>=4096:_shore_nodes.clear()
	_shore_nodes[cell]=value;return value
func shore_distance(p:Vector2)->float:
	# Smooth the SAME warped island boundary, not a new circular shoreline.
	# A fixed 256 m carrier suppresses small gradient-normalization lumps in dune
	# profiles; the final surface is still sampled on the canonical 8 m lattice.
	var q:=p/256;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	if not _shore_patches.has(cell):
		var coast:RefCounted=_coast.get_ref();var rows:Array[PackedFloat64Array]=[]
		for z in range(-1,3):rows.append(coast.polynomial(_shore_node(cell+Vector2i(-1,z)),_shore_node(cell+Vector2i(0,z)),_shore_node(cell+Vector2i(1,z)),_shore_node(cell+Vector2i(2,z))))
		var coefficients:=PackedFloat64Array();coefficients.resize(16)
		for i in range(4):
			var column:PackedFloat64Array=coast.polynomial(rows[0][i],rows[1][i],rows[2][i],rows[3][i])
			for j in range(4):coefficients[i*4+j]=column[j]
		if _shore_patches.size()>=2048:_shore_patches.clear()
		_shore_patches[cell]=coefficients
	var coefficients:PackedFloat64Array=_shore_patches[cell];var result:float=0
	for i in range(3,-1,-1):
		var k:int=i*4;result=result*f.x+coefficients[k]+f.y*(coefficients[k+1]+f.y*(coefficients[k+2]+f.y*coefficients[k+3]))
	return result
func evaluate(p:Vector2,frame:Vector3,w:PackedFloat32Array,a:float,b:float,c:float,river_distance:float)->PackedFloat64Array:
	var coast:RefCounted=_coast.get_ref();var n:=Vector2(frame.y,frame.z);var tangent:=Vector2(-n.y,n.x)
	var selector:float=_wind.get_noise_2d(p.x,p.y)*.5+.5
	var amount:float=1-smoothstep(settings.coverage-.12,settings.coverage+.12,selector)
	if settings.coverage>=.999:amount=1
	if settings.coverage<=0:amount=0
	var id:int=0
	for i in range(1,16):
		if w[i]>w[id]:id=i
	# Partial burial of bedrock, rather than a solid sand coat in mixed shores.
	amount*=1-w[14]*smoothstep(-.25,.45,b)*.85
	var width:float=settings.beach_width*(1+settings.width_variation*(a*.7+w[0]*1.4-w[1]*.7+w[10]*1.7-w[6]*.3))
	var dune_country:float=clampf(w[2]+w[3]+w[4]+w[5]+w[13]*.7,0,1)*settings.dune_frequency
	var flat:float=w[10]*settings.tidal_flat_frequency
	var barrier:float=(w[7]+w[9])*settings.barrier_frequency
	var lagoon:float=w[9]*settings.lagoon_frequency
	var wind:=Vector2.from_angle(wind_angle(p));var alignment:float=wind.dot(n)
	var exposure:float=clampf(.5-.35*n.dot(Vector2(.8,-.6))+a*.1-w[6]*.2,0,1)
	var shift:float=a*80*settings.shoreline_irregularity+w[6]*b*160
	# A spit extends from the same shore, with irregular hooked tip and a finite
	# alongshore depositional window. No unrelated line stamped into deep ocean.
	var spit:float=w[8]*settings.spit_frequency*smoothstep(-.1,.35,b)
	shift+=spit*(160+100*a)
	var d:float=shore_distance(p)+shift
	var slope:float=settings.beach_slope*(1+w[1]*1.8-w[0]*.4-flat*.85)
	var beach:float=d*slope
	if d<0:beach=d*(.035-flat*.025)+maxf(d+600,0)*.001
	var upper:float=width*slope
	if d>width:beach=upper+(d-width)*.008
	var berm:float=settings.berm_height*exp(-pow((d-width*.72)/(35+width*.12),2))*(.65+.35*b)*(1-flat)
	beach+=berm
	var crest:float=width+settings.foredune_width*(.9+a*.35+b*.1*settings.crest_irregularity)
	var q:float=d-crest;var scale:float=settings.foredune_width*(1+settings.asymmetry*alignment*(.35 if q<0 else -.35))
	# Gaussian shoulders, variable width and linked ridges, never vertical sand.
	var fore:float=exp(-pow(q/maxf(scale,80),2))
	var height:float=settings.foredune_height*(.55+w[3]*1.5+w[5]*.5)*(1+a*.25+b*.15)
	var blow:float=(1-smoothstep(.05,.45,absf(coast._meso.get_noise_2d(p.x*.4+921,p.y*.4-317))))*settings.blowouts*(w[2]+w[5]+w[13])
	fore*=1-blow*.65
	var dunes:float=fore*height
	for k in range(1,4):
		var center:float=crest+float(k)*settings.foredune_width*(1.7+float(k)*.17+a*.35)
		var ridge:float=exp(-pow((d-center)/(settings.foredune_width*(.8+float(k)*.15)),2))
		dunes+=ridge*height*(.65/float(k))*settings.secondary_dunes*(.7+b*.25)*(1-blow*.4)
	var back:float=smoothstep(crest,crest+400,d)*(1-smoothstep(1500,2300,d))
	dunes+=back*settings.backdune_relief*height*(.5+a*.3+b*.2)
	# Parabolic arms bend across an irregular wind-oriented corridor. They exist
	# only behind an actual coast and are gated to the parabolic regional family.
	# Do not multiply a changing regional angle by unbounded world coordinates:
	# that would compress arm wavelengths as exploration moves farther away.
	var prevailing:=Vector2.from_angle(deg_to_rad(settings.wind_degrees))
	var along:float=p.dot(Vector2(-prevailing.y,prevailing.x))/700+a*.6
	var arm:float=absf(sin(along+b*.3));var parabola:float=crest+350+arm*arm*450
	dunes+=w[5]*height*.8*exp(-pow((d-parabola)/180,2))*smoothstep(.2,.65,arm)
	var storm:float=w[13]*settings.storm_erosion*smoothstep(-.2,.3,b)
	var scarp_width:float=maxf(scale*1.8,height*4)
	dunes*=lerpf(1,smoothstep(crest-scarp_width*.75,crest+scarp_width*.25,d),storm)
	beach+=dunes*dune_country
	# Small embryo accumulations are broad relative to the sampling lattice.
	beach+=exp(-pow((d-width*.95)/100,2))*maxf(b+c*.3,0)*3*dune_country
	var basin:float=(barrier+lagoon)*exp(-pow((d-width-420)/(260+lagoon*180),2))
	var inlet:float=(1-smoothstep(.035,.12,absf(b)))*maxf(barrier,flat)
	beach=lerpf(beach,-1.5,clampf(maxf(basin,inlet*(1-smoothstep(width+700,width+1000,d))),0,1))
	# Broaden the inherited carrier through tall dune belts. A narrow Grass
	# incision applied unchanged to a 100 m dune creates impossible sand walls.
	var river_bank:float=100+height*(1+settings.secondary_dunes)*4*dune_country
	var river:float=1-smoothstep(18,river_bank,river_distance)
	var channel:float=maxf(river,(1-smoothstep(.02,.10,absf(b+c*.1)))*flat)
	beach=lerpf(beach,-1.6+maxf(d,0)*.0008,channel*(1-smoothstep(1300,2100,maxf(d,0))))
	# Uncommon damp slacks, mostly above mean sea level. No random inland pools.
	var slack:float=w[4]*back*(1-smoothstep(.03,.3,absf(a)))
	beach=lerpf(beach,2.0,slack)
	var bar:float=exp(-pow((d+200+a*80)/(80+flat*150),2))*(.4+.6*smoothstep(-.3,.3,b))*settings.sandbar_frequency*(w[15]+w[0]*.4+flat*.5)
	if d<0:beach+=bar*6
	var range_width:float=maxf(2500,crest+1600)
	amount*=1-smoothstep(range_width*.68,range_width,absf(d))
	var sediment:float=clampf(w[14]+w[1]*.4+w[11]*.6,0,1)
	return PackedFloat64Array([beach,amount,float(id)/15,exposure,sediment,width,fore,back,blow,slack,basin,bar,channel,wind.x,wind.y,storm,spit])
