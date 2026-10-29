extends "res://scripts/terrain_mesh_builder.gd"
## Private exact height-only cache capacity trial, no production registration.
var cache_limit:int=65536
var height_cache_hits:int=0
var height_cache_misses:int=0
var height_cache_resets:int=0
func _sample_normal_height(x:float,z:float)->float:
	if absf(x)>2000000000.0 or absf(z)>2000000000.0 or x!=floorf(x) or z!=floorf(z):
		height_cache_misses+=1;return _get_height(x,z,false)
	var key:=Vector2i(int(x),int(z))
	if _height_grid_cache.has(key):height_cache_hits+=1;return _height_grid_cache[key][0]
	if _normal_height_cache.has(key):height_cache_hits+=1;return _normal_height_cache[key]
	height_cache_misses+=1;var height:float=_get_height(x,z,false)
	if _normal_height_cache.size()>=cache_limit:_normal_height_cache.clear();height_cache_resets+=1
	_normal_height_cache[key]=height;return height
