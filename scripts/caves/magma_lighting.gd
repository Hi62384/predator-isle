extends RefCounted
## Main-thread controller:ONE shadowed approximation for the nearest actual
## uploaded molten source. No per-pool light nodes or worker-side scene work.
var settings:Dictionary={}
var light:OmniLight3D
var source_id:String=""
var source_key:=Vector3i(2147483647,2147483647,2147483647)
var _last_point:=Vector3.INF
var _last_usec:int=0
func configure(configuration:Dictionary)->void:settings=configuration.duplicate(true);_last_point=Vector3.INF;_last_usec=0
func uploaded(stream,key:Vector3i,pool_id:String)->bool:
	var node=stream._cells.get(key)
	if not is_instance_valid(node) or not node.is_visible_in_tree():return false
	var molten=node.get_node_or_null("CaveBiome_magma_molten_volcanic")
	return is_instance_valid(molten) and molten.is_visible_in_tree() and molten.get_meta("source_basins",[]).has(pool_id)
func update(stream,point:Vector3)->void:
	if not point.is_finite() or stream._bundle.is_empty() or not settings.get("lava_lighting",true) or float(settings.get("lava_light_energy",.9))<=0:
		if is_instance_valid(light):light.visible=false
		return
	if is_instance_valid(light) and not uploaded(stream,source_key,source_id):light.visible=false
	var now:int=Time.get_ticks_usec()
	if _last_point.is_finite() and _last_point.distance_squared_to(point)<1 and now-_last_usec<250000:return
	_last_point=point;_last_usec=now;var best:Dictionary={};var distance:float=INF
	for region:Dictionary in stream._bundle.get("regions",[]):
		for pool:Dictionary in region.get("pools",[]):
			if pool.get("fluid_kind","")!="magma" or float(pool.get("source_heat",0))<.5 or str(pool.get("thermal_source","")).is_empty():continue
			var p:=Vector3(pool.center.x,pool.water_y,pool.center.z);var reach:float=minf(80,maxf(48,float(pool.radius)*3+24));var squared:float=point.distance_squared_to(p)
			if squared>reach*reach or squared>distance:continue
			var key:=Vector3i(floori(p.x/64),floori(p.y/64),floori(p.z/64))
			if not uploaded(stream,key,str(pool.id)) or (squared==distance and not best.is_empty() and str(pool.id)>=str(best.id)):continue
			best=pool;distance=squared;source_key=key
	if best.is_empty():
		if is_instance_valid(light):light.visible=false
		source_id="";return
	if not is_instance_valid(light):
		light=OmniLight3D.new();light.name="CaveNearestMoltenLight";light.light_color=Color(1,.23,.035);light.shadow_enabled=true;stream.add_child(light)
	light.position=Vector3(best.center.x,best.water_y+.9,best.center.z);light.omni_range=clampf(float(best.radius)*3,12,48);light.light_energy=float(settings.get("lava_light_energy",.9))*lerpf(.5,1,clampf(float(best.source_heat),0,1));light.shadow_enabled=not is_instance_valid(stream.host) or stream.host.get("terrain_shadows")!=false;light.visible=true;source_id=str(best.id);light.set_meta("source_pool",source_id);light.set_meta("source_id",best.thermal_source);light.set_meta("source_kind",best.get("heat_source_kind","explicit_diagnostic_intrusion"))
func release()->void:
	if is_instance_valid(light):light.free()
	light=null;source_id="";_last_point=Vector3.INF;_last_usec=0
