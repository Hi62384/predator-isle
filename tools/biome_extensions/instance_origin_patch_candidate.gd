extends RefCounted
static var held:GDScript
static func apply()->void:
	held=load("res://scripts/chunk_terrain.gd")
	var source:String=held.source_code;var needle:String="node.position=Vector3(key.x*size,0,key.y*size)"
	assert(source.count(needle)==1)
	held.source_code=source.replace(needle,needle+'\n\tnode.set_instance_shader_parameter("terrain_instance_origin",node.global_position)')
	assert(held.reload()==OK)
