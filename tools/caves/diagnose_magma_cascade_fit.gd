extends "res://tools/caves/check_frozen_features.gd"
class Heat extends RefCounted:
	func sample(_point:Vector3)->Dictionary:return {"heat":1.0,"id":"explicit_controlled_cascade_intrusion"}
func run()->void:
	var region:Dictionary=fixture();region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";region.pools[0]["fluid_kind"]="magma";region.pools[0]["thermal_source"]="explicit_controlled_cascade_intrusion";region.pools[0]["source_heat"]=1.0
	var source:String=FileAccess.get_file_as_string("res://scripts/caves/magma_cascades.gd")
	var marker:String="\t\t\t\tvar source:Dictionary=context.sample(point)\n"
	assert(source.count(marker)==1)
	source=source.replace(marker,marker+"\t\t\t\tprint(\"CASCADE_POINT row=\",row,\" side=\",side,\" point=\",point,\" air=\",field.sample(point),\" wall_back=\",field.sample(point-axis*.5),\" normal_back=\",field.sample(point-field.normal(point)*.6),\" alignment=\",axis.dot(-radial),\" patch=\",inside_patch(point,patch.arrays[Mesh.ARRAY_VERTEX]))\n")
	source=source.replace(marker,marker+"\t\t\t\tif row==18:print(\"CLOSE_BACK \",side,\" \",field.sample(point-field.normal(point)*.15),\" \",field.sample(point-field.normal(point)*.3))\n")
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK)
	var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var result:Dictionary=script.prepare(region,flat,0,{"molten_cascades":true,"molten_cascade_chance":1.0},400,10,Heat.new());print("CASCADE_DIAGNOSTIC_ADMITTED ",result.pools[0].has("molten_cascade"));quit()
