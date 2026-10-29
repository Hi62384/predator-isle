extends RefCounted
## Private route feasibility prototype. A valid graph is NOT a native mesh or
## capsule-traversal certificate. No production cave is enabled by this file.
## Bounds are propagated in both directions before choosing any floor height;
## greedy endpoint clamping can otherwise create an unavoidable steep return.
static func solve(stations:PackedVector2Array,surface:Callable,half_width:float,headroom:float,roof:float,maximum_depth:float,grade:float,start_floor:float,end_floor:float,cover:PackedFloat32Array=PackedFloat32Array(),flat_start_metres:float=0,flat_end_metres:float=0)->Dictionary:
	var reject:Dictionary={"valid":false,"points":PackedVector3Array(),"reason":"invalid_input"}
	if not surface.is_valid() or stations.size()<2 or stations.size()>4096:return reject
	for number:float in [half_width,headroom,roof,maximum_depth,grade,start_floor,end_floor,flat_start_metres,flat_end_metres]:
		if not is_finite(number):return reject
	if half_width<=0 or headroom<=0 or roof<0 or maximum_depth<=roof+headroom+2 or grade<=0 or grade>.5 or flat_start_metres<0 or flat_end_metres<0:return reject
	if not cover.is_empty() and cover.size()!=stations.size():return reject
	var lower:=PackedFloat64Array();var upper:=PackedFloat64Array();var distances:=PackedFloat64Array();var cumulative:=PackedFloat64Array();var lengths:float=0;var field_bounds:Array=[]
	for i in range(stations.size()):
		var point:Vector2=stations[i]
		if not point.is_finite():return reject
		var tangent:Vector2=(stations[mini(i+1,stations.size()-1)]-stations[maxi(i-1,0)]).normalized()
		if tangent.length_squared()<.5:return reject
		var side:=Vector2(-tangent.y,tangent.x);var lowest:float=INF;var highest:float=-INF
		for fraction:float in [-1.0,-.5,0.0,.5,1.0]:
			var q:Vector2=point+side*(half_width+2)*fraction;var h:float=surface.call(q.x,q.y)
			if not is_finite(h):return reject
			lowest=minf(lowest,h);highest=maxf(highest,h)
		var coverage:float=cover[i] if not cover.is_empty() else 1.0
		if not is_finite(coverage) or coverage<0 or coverage>1:return reject
		# Four metres of planner reserve leave a two-metre extraction allowance
		# after between-station curvature/float storage, rather than consuming
		# the whole allowance at the sparse sampled stations themselves.
		lower.append(highest-maximum_depth+4);upper.append(lowest-(roof+headroom)*coverage);field_bounds.append(Vector2(lowest,highest))
		var distance:float=stations[i].distance_to(stations[i-1]) if i>0 else 0
		if i>0 and distance<.01:return reject
		distances.append(distance);lengths+=distance;cumulative.append(lengths)
	if start_floor<lower[0] or start_floor>upper[0] or end_floor<lower[-1] or end_floor>upper[-1]:reject.reason="endpoint_outside_depth_roof_envelope";return reject
	if flat_start_metres+flat_end_metres>=lengths:return reject
	# A chamber/route union must share one floor through the chamber footprint.
	# Without this, the room itself can cut metres off a rising access ramp.
	for i in range(stations.size()):
		var fixed:float=NAN
		if cumulative[i]<=flat_start_metres:fixed=start_floor
		if cumulative[i]>=lengths-flat_end_metres:fixed=end_floor
		if is_finite(fixed):
			if fixed<lower[i] or fixed>upper[i]:reject.reason="flat_junction_outside_envelope";return reject
			lower[i]=fixed;upper[i]=fixed
	lower[0]=start_floor;upper[0]=start_floor;lower[-1]=end_floor;upper[-1]=end_floor
	for i in range(1,stations.size()):
		var rise:float=distances[i]*grade;lower[i]=maxf(lower[i],lower[i-1]-rise);upper[i]=minf(upper[i],upper[i-1]+rise)
		if lower[i]>upper[i]+.0000001:reject.reason="forward_slope_envelope_empty";return reject
	for i in range(stations.size()-2,-1,-1):
		var rise:float=distances[i+1]*grade;lower[i]=maxf(lower[i],lower[i+1]-rise);upper[i]=minf(upper[i],upper[i+1]+rise)
		if lower[i]>upper[i]+.0000001:reject.reason="backward_slope_envelope_empty";return reject
	var points:=PackedVector3Array();var previous:float=start_floor;var maximum_grade:float=0;var min_cover:float=INF;var max_depth:float=0
	for i in range(stations.size()):
		var t:float=clampf((cumulative[i]-flat_start_metres)/(lengths-flat_start_metres-flat_end_metres),0,1);var desired:float=lerpf(start_floor,end_floor,t*t*(3-2*t));var low:float=lower[i];var high:float=upper[i]
		if i>0:low=maxf(low,previous-distances[i]*grade);high=minf(high,previous+distances[i]*grade)
		if low>high+.0000001:reject.reason="selected_floor_envelope_empty";return reject
		var floor_height:float=clampf(desired,low,maxf(low,high));var point:=Vector3(stations[i].x,floor_height,stations[i].y);points.append(point)
		if i>0:maximum_grade=maxf(maximum_grade,absf(floor_height-previous)/distances[i])
		previous=floor_height;min_cover=minf(min_cover,field_bounds[i].x-floor_height-headroom);max_depth=maxf(max_depth,field_bounds[i].y-floor_height)
	return {"valid":true,"points":points,"reason":"","maximum_grade":maximum_grade,"minimum_measured_roof_m":min_cover,"maximum_measured_depth_m":max_depth,"horizontal_length_m":lengths,"sample_count":stations.size(),"lateral_samples_per_station":5}
