extends "res://tools/caves/render_crystal_lake.gd"
func inspection_name()->String:return "diagnose_crystal_lake_colliders"
func selection_label()->String:return super.selection_label()+" DIAGNOSTIC ONLY:Crystal feature colliders disabled for the fixed dry-bank circuit,not a production pass. Original rock/cave/Default formation/water meshes,drawn minerals and route remain unchanged."
func walk(route:Array[Vector3],label:String)->Dictionary:
	if label.contains("full fixed dry lake-bank"):
		await process_frame
		var shapes:Array=root.find_children("BiomeCollision_crystal_*","CollisionShape3D",true,false);check(not shapes.is_empty(),"Positive original Crystal colliders available for ONLY collision-off diagnostic")
		for shape:CollisionShape3D in shapes:shape.disabled=true
		await physics_frame;await physics_frame
	return await super.walk(route,label+" [Crystal-collision-off diagnostic]" if label.contains("full fixed dry lake-bank") else label)
