extends "res://scripts/biome_extension_structures.gd"
## Exact old full-detail emitter, with numerical range instrumentation only.
var conduit_ranges:Array[Vector2i]=[]
func _init()->void:conduit_cache_enabled=false
func _conduit_uncached(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	var begin:int=vertices.size();super._conduit_uncached(builder,a,b,width,phase,color);conduit_ranges.append(Vector2i(begin,vertices.size()))
