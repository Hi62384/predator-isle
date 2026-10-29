extends "res://tools/biome_extensions/surface_guided_junction_candidate.gd"
var membrane_enabled:bool=true
## Private paired arch/web guide; no production placement or rarity change.
func emit(g,builder,point:Vector2,directions:Array[Vector2],width:float,height:float,phase:float)->void:
	super.emit(g,builder,point,directions,width,height,phase)
	if not membrane_enabled:return
	var web=preload("res://tools/biome_extensions/surface_guided_membrane_candidate.gd").new();web.surface_guide_enabled=surface_guide_enabled
	web.emit(g,builder,point,directions[0],width,height,phase)
