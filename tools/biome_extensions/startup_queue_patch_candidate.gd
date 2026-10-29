extends RefCounted
static var held:GDScript
static func apply()->void:
	held=load("res://scripts/chunk_terrain.gd")
	var source:String=held.source_code
	var needle:String='\t_queued_at.clear()\n\tfor key in _pending_chunks:'
	var patch:String='\t_pending_chunks.sort_custom(func(a:Vector3i,b:Vector3i)->bool:\n\t\tvar da:float=_partition.distance_to(a,_last_plan_position);var db:float=_partition.distance_to(b,_last_plan_position)\n\t\tvar na:bool=da<chunk_size*4;var nb:bool=db<chunk_size*4\n\t\tif na or nb:return da<db if na and nb else na\n\t\tvar wa:int=_estimated_sampling_work(_mesh_key(a));var wb:int=_estimated_sampling_work(_mesh_key(b))\n\t\treturn wa>wb if wa!=wb else da<db)\n'+needle
	assert(source.count(needle)==1);held.source_code=source.replace(needle,patch);assert(held.reload()==OK)
