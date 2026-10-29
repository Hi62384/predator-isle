extends "res://scripts/lod_biome_extension_structures.gd"
## Test-only range/path recorder; both cold/warm production emitters untouched.
var conduit_ranges:Array[Vector2i]=[]
var path_identities:Array[String]=[]
func conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	var begin:int=vertices.size();super.conduit(builder,a,b,width,phase,color)
	conduit_ranges.append(Vector2i(begin,vertices.size()));path_identities.append(var_to_bytes([a,b,width,phase,color]).hex_encode())
