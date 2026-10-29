extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Exposed granite plains","Limestone benches","Slate highlands","Sandstone excavation","Basalt bedrock","Gravel basins"]
var _ramp_plans:Dictionary={}
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	_ramp_plans.clear();super.configure(config,seed_id,host,family_id)
func ramp_plan(d:Dictionary)->Dictionary:
	if _ramp_plans.has(d.id):return _ramp_plans[d.id]
	var plan:Dictionary={}
	if d.kind%2==0 and d.chance<=settings.excavation_frequency:
		var factor:float=1+.08*sin(-PI*3+d.angle)+.05*sin(-PI*7+.4)
		var start:Vector2=d.position+Vector2(-.22*d.radius*factor,0).rotated(d.angle)
		var end:Vector2=d.position+Vector2(-1.3*d.radius*factor,0).rotated(d.angle)
		# Probe the unmodified canonical field, not a different regional roof
		# approximation. The upper endpoint is outside the excavation blend.
		var low:float=super.sample(start.x,start.y,false);var high:float=super.sample(end.x,end.y,false)
		var turns:int=maxi(1,ceili(absf(high-low)/maxf(settings.ramp_grade*.55*TAU*.22*d.radius/1.25,.001)))
		var width:float=minf(48,d.radius*1.08/turns*.32)
		# A road must not cross a nearest-excavation ownership boundary. Its
		# conservative swept bounding circle must fit inside this site's cell.
		var clearance:bool=true;var span:float=3200*settings.feature_scale
		var cell:=Vector2i(floori(d.position.x/span),floori(d.position.y/span))
		var required:float=1.3*1.13*d.radius+width*1.35+16
		for dz in range(-2,3):
			for dx in range(-2,3):
				if dx==0 and dz==0:continue
				var other:Dictionary=descriptor(cell+Vector2i(dx,dz),span)
				if d.position.distance_to(other.position)<required*2:clearance=false
		if turns<=12 and width>=24 and clearance:plan={"start":start,"end":end,"low":low,"high":high,"turns":turns,"half_width":width}
	if _ramp_plans.size()>=256:_ramp_plans.clear()
	_ramp_plans[d.id]=plan;return plan
func sample(x:float,z:float,publish:bool=true)->float:
	var h:float=super.sample(x,z,publish);var p:=Vector2(x,z);var d:Dictionary=nearby(p,3200*settings.feature_scale)
	var q:Vector2=local(p,d)
	if q.length()<d.radius*1.65:
		var plan:Dictionary=ramp_plan(d)
		if not plan.is_empty():
			var radius:float=d.radius*(1+.08*sin(q.angle()*3+d.angle)+.05*sin(q.angle()*7+.4))
			var r:float=Vector2(q.x,q.y*1.25).length()/radius;var angle_t:float=(q.angle()+PI)/TAU
			var best:float=0;var target:float=h
			for turn in range(-1,plan.turns+1):
				var t:float=(turn+angle_t)/plan.turns;var path_radius:float=.22+1.08*t
				var cap:float=plan.half_width/maxf(plan.turns*TAU*.22*d.radius,.001)
				var influence:float=(1-smoothstep(plan.half_width,plan.half_width*1.35,absf(r-path_radius)*radius))*smoothstep(-cap,0,t)*(1-smoothstep(1,1+cap,t))
				if influence>best:best=influence;target=lerpf(plan.low,plan.high,clampf(t,0,1))
			# Protect the actual world-space walking grade AFTER canonical node
			# interpolation and excavation blending, which otherwise reintroduced
			# bench walls and regional relief across the reserved ramp centreline.
			h=lerpf(h,target,best)
	if publish:state[0]=h
	return h
func terraces(t:float,age:float)->float:
	# Nonuniform bench spacing; finite wall widths, no height discontinuities.
	var q:float=clampf(t,0,1);var result:float=0
	var count:int=clampi(roundi(settings.pit_depth/maxf(settings.bench_height,10)),3,10)
	for i in range(1,count+1):
		var threshold:float=float(i)/(count+1)+.024*sin(i*2.31)
		result+=smoothstep(threshold-.012-age*.012,threshold+.012+age*.018,q)/count
	return result
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var d:Dictionary=nearby(p,3200*settings.feature_scale);var q:Vector2=local(p,d);var age:float=d.age*settings.weathering
	var natural:float=280+macro(p)*100+pow(1-absf(macro(p*.7+Vector2(710,49))),3)*([45,90,240,130,170,15][id])+noise(p)*6
	var radius:float=d.radius*(1+.08*sin(q.angle()*3+d.angle)+.05*sin(q.angle()*7+.4))
	var r:float=Vector2(q.x,q.y*1.25).length()/radius
	var excavation:float=1-smoothstep(.95,1.25,r)
	if d.chance>settings.excavation_frequency:excavation=0
	var depth:float=settings.pit_depth*(.55+d.age*.8)
	# A retained basin's elevation is descriptor-owned, not a per-region colour blend.
	var roof:float=280+macro(d.position)*100+pow(1-absf(macro(d.position*.7+Vector2(710,49))),3)*60
	var level:float=maxf(25,roof-depth)
	var bench:float=terraces((r-.18)/.85,age)
	var floor_h:float=level+noise(p)*2+(macro(p*2)+.5)*3
	var cut:float=floor_h+bench*depth
	var h:float=lerpf(natural,minf(natural,cut),excavation)
	var water:float=0
	if d.chance<settings.water_frequency and excavation>0:
		water=(level+depth*.15)*(1-smoothstep(.84,1.1,r))
	return PackedFloat64Array([h,water,clampf(.25+excavation*.4,0,1),0,excavation])
