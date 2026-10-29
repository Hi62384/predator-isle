extends RefCounted
## Shared open breaches must stay outside the existing physical surface
## conduits/junctions and finite galleries. Does not remove those structures.
const Features=preload("res://scripts/terrain_feature_meshes.gd")
var builder
var _finite:Dictionary={}
func configure(owner)->void:builder=owner;_finite.clear()
func clear_point(point:Vector3,radius:float)->bool:
	if not point.is_finite():return false
	var field=builder._extras[7]
	if field==null:return true
	var p:=Vector2(point.x,point.z);var network:Dictionary=field.network(p);var junction:float=field.settings.hive_junction_width*field.settings.feature_scale*4+64
	# The whole external shoulder/fibre envelope,not just the narrow trunk
	# centerline. Enlarging an entrance does not silently cut a surface shell.
	if network.trunk_distance<240+radius or network.branch_distance<160+radius or network.center_distance<junction+radius:return false
	var cell:=Vector2i(floori(p.x/64),floori(p.y/64))
	if not _finite.has(cell):
		var features=Features.new();features.builder=builder
		if _finite.size()>=64:_finite.erase(_finite.keys()[0])
		_finite[cell]=features.portal_sites(Rect2(Vector2(cell)*64,Vector2.ONE*64).grow(400+radius))
	for site:Dictionary in _finite[cell]:
		if p.distance_to(site.position)<maxf(320,site.half*1.2)+radius:return false
	return true
func clear_access(edge:Dictionary)->bool:
	if builder._extras[7]==null:return true
	if edge.points.size()<2:return false
	var first:Vector3=edge.points[0];var direction:=Vector2(edge.points[1].x-first.x,edge.points[1].z-first.z).normalized()
	for station in range(6):
		var p:Vector3=first-Vector3(direction.x,0,direction.y)*station*8;p.y=builder._get_height(p.x,p.z)
		if p.y<=builder.get_water_surface_height(p.x,p.z)+2 or not clear_point(p,edge.half_width):return false
	for p:Vector3 in edge.points:
		if builder._get_height(p.x,p.z)-p.y<=64 and not clear_point(p,edge.half_width):return false
	return true
