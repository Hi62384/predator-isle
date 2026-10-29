extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://tools/caves/cave_network_candidate.gd")
func run()->void:
	var n=Network.new();n.configure(func(_x:float,_z:float)->float:return 120,func(_x:float,_z:float)->float:return 0,92881);n.activity=1;var cell:=Vector2i(4,-7);var data:Dictionary=n.region(cell);print("FLAT_ORIGINAL ",data.nodes.size(),"/",data.edges.size()," conflict=",n.last_support_conflict)
	var first:Dictionary=data.nodes[1];var center:Vector2=data.center;var angle:float=n.random(cell,3)*TAU;var node:Dictionary=n.node_floor(Vector2(first.point.x,first.point.z),136);node.id="test";var a:=Vector2(first.point.x,first.point.z);var b:=Vector2(node.point.x,node.point.z)
	for alternative in range(8):
		var winding:=PackedVector2Array([a]);var turn:float=angle+float(alternative/2)*PI*.5;var clockwise:float=1 if alternative%2==0 else -1
		for corner_id in range(4):winding.append(center+Vector2(-450,-450).rotated(turn+clockwise*corner_id*PI*.5))
		winding.append(b);var edge:Dictionary=n.route(first,node,winding);print("ALTERNATIVE ",alternative," valid=",not edge.is_empty()," support=",n.supported_join(edge,data.edges) if not edge.is_empty() else false," conflict=",n.last_support_conflict)
	var builder=make_builder(3,73921);n.configure(builder._get_height,builder.get_water_surface_height,73921);var actual:Dictionary=n.region(Vector2i(9,-3));print("ACTUAL_ORIGINAL ",actual.nodes.size(),"/",actual.edges.size()," conflict=",n.last_support_conflict);quit()
