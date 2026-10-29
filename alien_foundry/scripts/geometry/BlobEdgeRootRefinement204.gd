extends RefCounted
const AdaptiveNormal=preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal207.gd")
##204 fixed bounded reconstruction, never a new anatomical field or free projection.
const SETTING:="blob_isosurface_refinement_mode"
const MODE:="bracketed_field_edges_v1"
const OFF:="off"
const PIN:="505802d0b619bd74bf45c312800eda4e16e0a802de3a92d10397f73f2d80ca02"
const ITERATIONS:=16
const NORMAL_CELL_FRACTION:=0.05
const RESIDUAL_CELL_FRACTION:=1.0/4096.0
const MAX_EDGES:=60000
const MAX_QUERIES:=1500000
const MAX_QUERIES_PER_EDGE:=25
var query: Callable
var adaptive_normals:=false
var query_quota:=MAX_QUERIES
var per_edge_quota:=MAX_QUERIES_PER_EDGE
var normal_stats: Dictionary={}
var cell:=0.0
var error:=""
var endpoints: Dictionary={}
var stats: Dictionary={"mode":MODE,"pin":PIN,"unique_edges":0,"continuous_queries":0,"endpoint_queries":0,"endpoint_cache_hits":0,"bisection_queries":0,"residual_queries":0,"normal_queries":0,"maximum_queries_per_edge":0,"maximum_first_order_residual_m":0.0,"maximum_bracket_span_m":0.0,"iterations_per_edge":ITERATIONS,"normal_cell_fraction":NORMAL_CELL_FRACTION,"edge_quota":MAX_EDGES,"query_quota":MAX_QUERIES,"fallbacks":0,"repairs":0,"normal_replacements":0}
static func selection(options: Dictionary) -> Dictionary:
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,MODE]: return {"error":"Invalid explicit204 edge refinement selector."}
	if mode==MODE and options.get("blob_mass_reprofile_mode")!="whole_mass_silhouette_v1": return {"error":"204 initially requires the unchanged203 body program."}
	return {"mode":mode}
static func validate(dna: Dictionary) -> Dictionary:
	if not dna.get("settings",{}) is Dictionary: return {"ok":false,"error":"204 selector requires a settings dictionary."}
	var selected:=selection(dna.get("settings",{}))
	if selected.has("error"): return {"ok":false,"error":selected.error}
	if selected.mode==OFF: return {"ok":true}
	if not dna.get("metadata",{}) is Dictionary: return {"ok":false,"error":"204 enabled selector requires stage metadata."}
	if dna.get("type")!="Blob" or int(dna.get("metadata",{}).get("iteration_index",0))<2: return {"ok":false,"error":"204 applies only to developed Blob geometry, never Stage1."}
	return {"ok":true}
static func create(callback: Callable,cell_size: float,normal_mode: String=AdaptiveNormal.OFF) -> RefCounted:
	var result=load("res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement204.gd").new()
	result.query=callback;result.cell=cell_size
	if normal_mode not in [AdaptiveNormal.OFF,AdaptiveNormal.MODE]: result.reject("207 invalid explicit normal mode.")
	if normal_mode==AdaptiveNormal.MODE:
		result.adaptive_normals=true;result.query_quota=AdaptiveNormal.MAX_QUERIES;result.per_edge_quota=AdaptiveNormal.MAX_QUERIES_PER_EDGE;result.stats.query_quota=result.query_quota
		result.normal_stats={"mode":AdaptiveNormal.MODE,"pin":AdaptiveNormal.PIN,"levels_cap":AdaptiveNormal.LEVELS,"angle_degrees":AdaptiveNormal.ANGLE_DEGREES,"required_consecutive":AdaptiveNormal.REQUIRED_CONSECUTIVE,"level_histogram":[0,0,0,0,0,0,0,0],"converged_edges":0,"rejected_edges":0,"maximum_selected_level":0,"maximum_final_angle_degrees":0.0,"maximum_preceding_angle_degrees":0.0,"edge_records":[]}
	if not callback.is_valid() or not is_finite(cell_size) or cell_size<=0.0: result.reject("204 requires a valid complete-field callback and positive finite cell.")
	return result
func reject(reason: String) -> void:
	if error.is_empty(): error=reason
func _query(point: Vector3,category: String) -> float:
	if not error.is_empty(): return NAN
	if not point.is_finite(): reject("204 nonfinite query point.");return NAN
	if int(stats.continuous_queries)>=query_quota: reject("204 continuous-field query quota exceeded; no fallback.");return NAN
	stats.continuous_queries+=1;stats[category]+=1
	var result: Variant=query.call(point)
	if not (result is float or result is int) or not is_finite(float(result)): reject("204 nonfinite or nonnumeric complete field.");return NAN
	return float(result)
func _endpoint(index: int,point: Vector3) -> float:
	if endpoints.has(index):
		var saved: Dictionary=endpoints[index]
		if saved.point!=point: reject("204 shared grid endpoint changed coordinates.");return NAN
		stats.endpoint_cache_hits+=1;return float(saved.value)
	var value:=_query(point,"endpoint_queries")
	if error.is_empty(): endpoints[index]={"point":point,"value":value}
	return value
func solve(first: int,second: int,a: Vector3,b: Vector3,sample_a: float,sample_b: float) -> Dictionary:
	if not error.is_empty(): return {"error":error}
	if int(stats.unique_edges)>=MAX_EDGES: reject("204 unique-edge quota exceeded; no fallback.");return {"error":error}
	if first==second or not a.is_finite() or not b.is_finite() or a==b or not is_finite(sample_a) or not is_finite(sample_b): reject("204 degenerate or nonfinite original edge.");return {"error":error}
	stats.unique_edges+=1
	var before: int=stats.continuous_queries
	var fa:=_endpoint(first,a);var fb:=_endpoint(second,b)
	if not error.is_empty(): return {"error":error}
	if fa==0.0 or fb==0.0 or (fa<0.0)==(fb<0.0) or (fa<0.0)!=(sample_a<0.0) or (fb<0.0)!=(sample_b<0.0): reject("204 genuine complete-field bracket/sign mismatch; no linear fallback.");return {"error":error}
	var negative_first:=fa<0.0
	var low:=0.0;var high:=1.0
	for iteration in range(ITERATIONS):
		var mid: float=(low+high)*0.5
		var value:=_query(a.lerp(b,mid),"bisection_queries")
		if not error.is_empty(): return {"error":error}
		if (value<=0.0)==negative_first: low=mid
		else: high=mid
	var t: float=(low+high)*0.5;var point:=a.lerp(b,t)
	var raw:=_query(point,"residual_queries")
	var epsilon: float=NORMAL_CELL_FRACTION*cell
	var gradient:=Vector3.ZERO
	for axis in range(3):
		var delta:=Vector3.ZERO;delta[axis]=epsilon
		var plus:=_query(point+delta,"normal_queries");var minus:=_query(point-delta,"normal_queries")
		gradient[axis]=(plus-minus)/(2.0*epsilon)
	if not error.is_empty(): return {"error":error}
	var length: float=gradient.length()
	if not gradient.is_finite() or not is_finite(length) or length<=0.0: reject("204 degenerate full-field gradient; no normal replacement.");return {"error":error}
	var residual: float=absf(raw)/length
	if not is_finite(residual) or residual>cell*RESIDUAL_CELL_FRACTION: reject("204 fixed local first-order residual budget failed.");return {"error":error}
	var output_normal: Vector3=gradient/length
	if adaptive_normals:
		var normal_before: int=stats.normal_queries
		var refined: Dictionary=AdaptiveNormal.refine(point,cell,gradient,Callable(self,"_query").bind("normal_queries"))
		var record: Dictionary={"edge_ordinal":int(stats.unique_edges)-1,"first":first,"second":second,"levels":refined.levels,"selected_level":refined.get("selected_level",-1),"normal_queries":6+int(stats.normal_queries)-normal_before,"additional_normal_queries":int(stats.normal_queries)-normal_before,"complete_queries":int(stats.continuous_queries)-before,"angles":refined.angles,"final_angle_degrees":refined.get("final_angle_degrees"),"preceding_angle_degrees":refined.get("preceding_angle_degrees"),"first_order_residual_m":residual,"ok":refined.ok,"error":refined.error}
		normal_stats.edge_records.append(record)
		if not refined.ok:
			normal_stats.rejected_edges+=1;reject(str(refined.error));return {"error":error}
		output_normal=refined.normal
		normal_stats.converged_edges+=1;normal_stats.level_histogram[int(refined.selected_level)]+=1
		normal_stats.maximum_selected_level=maxi(int(normal_stats.maximum_selected_level),int(refined.selected_level))
		normal_stats.maximum_final_angle_degrees=maxf(float(normal_stats.maximum_final_angle_degrees),float(refined.final_angle_degrees))
		normal_stats.maximum_preceding_angle_degrees=maxf(float(normal_stats.maximum_preceding_angle_degrees),float(refined.preceding_angle_degrees))
	var used: int=int(stats.continuous_queries)-before
	if used>per_edge_quota: reject("204 per-edge query budget violated.");return {"error":error}
	stats.maximum_queries_per_edge=maxi(int(stats.maximum_queries_per_edge),used)
	stats.maximum_first_order_residual_m=maxf(float(stats.maximum_first_order_residual_m),residual)
	stats.maximum_bracket_span_m=maxf(float(stats.maximum_bracket_span_m),a.distance_to(b)*(high-low))
	return {"point":point,"normal":output_normal,"t":t,"raw_value":raw,"first_order_residual_m":residual,"bracket_parameter_width":high-low,"continuous_queries":used}
func snapshot() -> Dictionary:
	var result:=stats.duplicate(true);
	if adaptive_normals:
		result["adaptive_normal207"]=normal_stats.duplicate(true);result["per_edge_query_quota"]=per_edge_quota
	result["error"]=error;result["endpoint_cache_entries"]=endpoints.size();result["global_metric_distance_claimed"]=false
	return result
