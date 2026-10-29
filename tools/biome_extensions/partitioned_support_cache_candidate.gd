extends "res://scripts/lod_biome_extension_structures.gd"
## Private, unregistered exact cache policy. Same 16,384 dictionary-entry cap;
## reserve one metadata entry and divide cached values between support grids.
## Fine-grid churn cannot clear all coarser-grid corners at once. Shared state
## lives in the existing dictionary passed to primitive memo builders.
const STATE_KEY="private_partitioned_support_fifo_v1"
const TOTAL_ENTRIES:int=16384
func _grid_height(builder,x:int,z:int,index:int,step:float)->float:
	var cacheable:bool=absi(x)<=2147483647 and absi(z)<=2147483647
	if not cacheable:return builder._sample_normal_height(float(x)*step,float(z)*step)
	var key:=Vector3i(x,z,index)
	if _support_heights.has(key):return _support_heights[key]
	var height:float=builder._sample_normal_height(float(x)*step,float(z)*step)
	if not _support_heights.has(STATE_KEY):
		# This cache object is new/worker-owned, never imported from another
		# policy. Keeping this explicit avoids untracked entries without a FIFO.
		assert(_support_heights.is_empty())
		_support_heights[STATE_KEY]={"grids":[]}
	var state:Dictionary=_support_heights[STATE_KEY]
	while state.grids.size()<=index:state.grids.append({"ring":[],"cursor":0})
	var grid:Dictionary=state.grids[index]
	var capacity:int=maxi(1,(TOTAL_ENTRIES-1)/maxi(_support_steps.size(),1))
	if grid.ring.size()<capacity:grid.ring.append(key)
	else:
		_support_heights.erase(grid.ring[grid.cursor]);grid.ring[grid.cursor]=key;grid.cursor=(grid.cursor+1)%capacity
	_support_heights[key]=height
	assert(_support_heights.size()<=TOTAL_ENTRIES)
	return height
