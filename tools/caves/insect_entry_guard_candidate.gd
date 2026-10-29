extends RefCounted
## PRIVATE shared-cave admission study. Conservative full-complex mound
## footprints,not visible geometry or a second cave system. No source edits.
const Features=preload("res://scripts/terrain_feature_meshes.gd")
var builder
var _roots:Dictionary={}
var _finite:Dictionary={}
func configure(owner)->void:builder=owner;_roots.clear();_finite.clear()
func roots_near(point:Vector2,radius:float)->Dictionary:
	var sampler=builder._extras[6]
	if sampler==null or sampler.settings.structure_density<=0:return {"valid":true,"roots":[]}
	var span:float=2100*sampler.settings.feature_scale;var rounding_pad:float=1+maxf(absf(point.x),absf(point.y))*.000002;var reach:float=sampler.settings.nest_height*1.45*1.344+radius+8+rounding_pad
	if not is_finite(reach) or not is_finite(span) or span<=0:return {"valid":false,"roots":[]}
	var ring:int=ceili(reach/span)
	if ring>8:return {"valid":false,"roots":[]}
	var cell:=Vector2i(floori(point.x/span),floori(point.y/span));var key:=Vector3i(cell.x,cell.y,ring)
	if _roots.has(key):return _roots[key]
	var result:Array=[]
	for z in range(cell.y-ring,cell.y+ring+1):
		for x in range(cell.x-ring,cell.x+ring+1):
			var descriptor:Dictionary=sampler.descriptor(Vector2i(x,z),span);var p:Vector2=descriptor.position
			if descriptor.chance>sampler.settings.structure_density or builder._island_mask(p.x,p.y)<.03:continue
			builder._biome_weights(p.x,p.y)
			if builder._extra_weights[6]<.55:continue
			var kind:int=clampi(roundi(sampler.region(p)),0,5)
			if kind==1:continue
			var ground:float=builder._get_height(p.x,p.y)
			if ground<builder.get_water_surface_height(p.x,p.y)+2:continue
			var scale:float=sampler.settings.nest_height*(.45+descriptor.age)*(1-.35*float(kind==4));var dome:bool=kind==3 and sampler.settings.nest_broad_domes;var footprint:float=scale*(1.344 if dome else .8)
			result.append({"id":descriptor.id,"point":p,"radius":footprint,"scale":scale,"archetype":kind,"phase":descriptor.angle,"ground":ground,"broad_dome":dome})
	if _roots.size()>=32:_roots.erase(_roots.keys()[0])
	var data:Dictionary={"valid":true,"roots":result};_roots[key]=data;return data
func clear_mounds(point:Vector3,radius:float)->bool:
	if not point.is_finite() or not is_finite(radius) or radius<0:return false
	var p:=Vector2(point.x,point.z);var data:Dictionary=roots_near(p,radius)
	if not data.valid:return false
	var rounding_pad:float=1+maxf(absf(p.x),absf(p.y))*.000002
	for root:Dictionary in data.roots:
		if p.distance_to(root.point)<root.radius+radius+8+rounding_pad:return false
	return true
func clear_finite(point:Vector3,radius:float)->bool:
	var cell:=Vector2i(floori(point.x/64),floori(point.z/64))
	if not _finite.has(cell):
		var features=Features.new();features.builder=builder;var sites:Array=features.portal_sites(Rect2(Vector2(cell)*64,Vector2.ONE*64).grow(384+radius))
		if _finite.size()>=64:_finite.erase(_finite.keys()[0])
		_finite[cell]=sites
	for site:Dictionary in _finite[cell]:
		if Vector2(point.x,point.z).distance_to(site.position)<maxf(320,site.half*1.2)+radius:return false
	return true
func clear_access(edge:Dictionary)->bool:
	if builder._extras[6]==null:return true
	for point:Vector3 in edge.points:
		if float(builder._get_height(point.x,point.z))-point.y>64:continue
		if not clear_mounds(point,edge.half_width) or not clear_finite(point,edge.half_width):return false
	return true
