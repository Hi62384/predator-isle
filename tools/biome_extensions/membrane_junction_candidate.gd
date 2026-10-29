extends "res://tools/biome_extensions/junction_flutes_candidate.gd"
## Private morphology study only. No production registration or rarity change.
var membrane_enabled:bool=true
func emit(g,builder,point:Vector2,directions:Array[Vector2],width:float,height:float,phase:float)->void:
	super.emit(g,builder,point,directions,width,height,phase)
	if membrane_enabled:preload("res://tools/biome_extensions/membrane_geometry_candidate.gd").new().emit(g,builder,point,directions[0],width,height,phase)
