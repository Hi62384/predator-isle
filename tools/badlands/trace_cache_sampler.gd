extends "res://scripts/badlands_sampler.gd"
## Diagnostic subclass only: count analytic work without changing cache policy.
var counters:Dictionary={}
func _tree(index:int,lane:int,side:int)->Dictionary:
	var miss:bool=not _trees.has(Vector3i(index,lane,side))
	counters.tree_queries=int(counters.get("tree_queries",0))+1
	if miss:
		counters.tree_builds=int(counters.get("tree_builds",0))+1
		if _trees.size()>=512:counters.tree_flushes=int(counters.get("tree_flushes",0))+1
	return super._tree(index,lane,side)
func _raw(p:Vector2)->PackedFloat64Array:
	counters.raw_nodes=int(counters.get("raw_nodes",0))+1
	return super._raw(p)
func _region(cell:Vector2i)->PackedFloat32Array:
	if not _regions.has(cell):
		counters.region_builds=int(counters.get("region_builds",0))+1
		if _regions.size()>=2048:counters.region_flushes=int(counters.get("region_flushes",0))+1
	return super._region(cell)
