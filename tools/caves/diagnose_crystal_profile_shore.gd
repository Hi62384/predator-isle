extends "res://tools/caves/check_crystal_profiles_native.gd"
## Counterfactual only: SAME declared large-basin ring with Crystal colliders
## disabled AFTER all renders. Never a production acceptance claim.
func profile_styles()->Array[String]:return ["large_basin"]
func native_report_name()->String:return "diagnose_cave_crystal_profile_shore"
func before_profile_walk(_style:String,cells:Dictionary)->void:
	var count:int=0
	for node:Node in cells.values():
		for shape:CollisionShape3D in node.find_children("BiomeCollision_crystal_*","CollisionShape3D",true,false):shape.disabled=true;count+=1
	check(count>0,"Positive actual mineral colliders disabled ONLY for counterfactual diagnostic")
