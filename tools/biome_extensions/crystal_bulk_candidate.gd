extends "res://scripts/lod_biome_extension_structures.gd"
## Private material metadata only;the real production emitter owns all shape.
func prism(builder,anchor:Vector3,width:float,height:float,habit:int,angle:float,tilt:Vector2,broken:bool,color:Color)->void:
	var begin:int=vertices.size()
	super.prism(builder,anchor,width,height,habit,angle,tilt,broken,color)
	var thickness:float=2*width*(.14 if habit==2 else 1.0)
	for index in range(begin,vertices.size()):
		var t:float=clampf((vertices[index].y+origin.y-anchor.y)/maxf(height,.001),0,1)
		uvs[index]=Vector2(habit+t*.25,thickness)
