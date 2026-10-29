extends "res://scripts/caves/surface_context.gd"
func controls(id:String,point:Vector2)->PackedFloat32Array:
	var result:PackedFloat32Array=super.controls(id,point)
	if result.is_empty():
		var parent:Dictionary=parents.get(id,{});print("MAGMA_PAYLOAD_BOUNDARY id=",id," point=",point," parent_origin=",parent.get("origin",Vector3.INF)," span=",parent.get("span",0)," actual_point_owner=",owner_at(point))
	return result
