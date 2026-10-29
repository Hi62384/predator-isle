extends "res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement208.gd"
## New caches, unchanged solver math, bounded cumulative coarse+refined work.
const Base208=preload("res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement208.gd")
const SlabPolicy=preload("res://alien_foundry/scripts/geometry/BlobSlabPolicy210.gd")
var prior_edges: int=0
var prior_queries: int=0

static func create_cumulative(callback: Callable,reference_cell: float,used_edges: int,used_queries: int)->RefCounted:
	var result: RefCounted=load("res://alien_foundry/scripts/geometry/BlobSlabEdge210.gd").new()
	var base: RefCounted=Base208.create(callback,reference_cell,"adaptive_field_gradient_v2")
	result.query=base.query;result.cell=base.cell;result.adaptive_normals=base.adaptive_normals
	result.stats=base.stats.duplicate(true);result.normal_stats=base.normal_stats.duplicate(true)
	result.per_edge_quota=base.per_edge_quota;result.prior_edges=used_edges;result.prior_queries=used_queries
	result.query_quota=SlabPolicy.QUERY_CAP-used_queries;result.stats.query_quota=result.query_quota
	if not base.error.is_empty():result.reject(base.error)
	if used_edges<0 or used_edges>=SlabPolicy.EDGE_CAP or used_queries<0 or used_queries>=SlabPolicy.QUERY_CAP:result.reject("210 cumulative extraction budget exhausted before new work.")
	return result

func solve(first: int,second: int,a: Vector3,b: Vector3,sample_a: float,sample_b: float)->Dictionary:
	if prior_edges+int(stats.unique_edges)>=SlabPolicy.EDGE_CAP:
		reject("210 cumulative unique-edge quota exceeded; no fallback.");return {"error":error}
	return super.solve(first,second,a,b,sample_a,sample_b)

func snapshot()->Dictionary:
	var result: Dictionary=super.snapshot()
	result["cumulative210"]={"prior_edges":prior_edges,"prior_queries":prior_queries,"edges":prior_edges+int(stats.unique_edges),"queries":prior_queries+int(stats.continuous_queries),"edge_cap":SlabPolicy.EDGE_CAP,"query_cap":SlabPolicy.QUERY_CAP}
	return result
