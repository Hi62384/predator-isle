extends RefCounted
## Cheap, bounded main-carrier corridor heuristic for pure Tropical tiles.
## It does not discover every tributary/lake or certify an exact curve bound.
## A false positive only raises mesh density; canonical geometry is unchanged.
static func spacing(builder:RefCounted,bounds:Rect2,lod:int)->float:
	var config:Resource=builder.settings.tropical
	if config.river_detail_metres<=0 or lod<2 or lod>clampi(config.river_detail_max_lod,2,4):return 0
	if builder._tropical==null or not builder.settings.water_enabled or config.river_frequency<=0 or builder.settings.grass_river_frequency<=0:return 0
	var field:RefCounted=builder._tropical
	var lane_spacing:float=field._spacing()
	var first:int=floori(bounds.position.y/lane_spacing)-2
	var last:int=ceili(bounds.end.y/lane_spacing)+2
	var detail:float=clampf(config.river_detail_metres,16,64)
	# Parent water remains recognizable without sampling every outer tile at
	# the same density as nearby banks. The finer user setting remains available.
	if lod==4:detail*=2
	# Extreme custom river densities must not create unbounded planning loops.
	if last-first+1>8:return detail
	var margin:float=maxf(config.river_width*4,bounds.size.x/8)
	for lane in range(first,last+1):
		if field.random(lane,0,139)>config.river_frequency:continue
		for sample_index in range(9):
			var x:float=lerpf(bounds.position.x,bounds.end.x,float(sample_index)/8)
			var carrier:Vector3=field._carrier(x,lane)
			if carrier.x>=bounds.position.y-margin and carrier.x<=bounds.end.y+margin:return detail
	return 0
