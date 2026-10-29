extends SceneTree
const BASE="res://tools/biome_extensions/artifacts/revisions/experiment_legacy_shader_policy_adoption_d95afe4b7828/sources/scripts/"
func block(source:String,begin:String,end:String)->String:
	assert(source.count(begin)==1 and source.count(end)==1)
	return source.substr(source.find(begin),source.find(end)-source.find(begin))
func _initialize()->void:
	var guards:Dictionary={};var results:Array=[]
	for item:Array in [
		["terrain_mesh_builder.gd","\tvar seed_value := _region_random(lane,0,93,541)","\tvar value := lane*spacing+(seed_value-0.5)*spacing*0.3 + broad*spacing*0.32 + bends*spacing*0.075"],
		["terrain_mesh_builder.gd","\tvar value:=Vector3(_grass_river_center(x,lane,spacing)","\tvar value:=Vector3(_grass_river_center(x,lane,spacing),(_grass_river_center(x+8.0,lane,spacing)-_grass_river_center(x-8.0,lane,spacing))/16.0,_grass_water_noise.get_noise_2d(x*0.6,lane*711.0))"],
		["mountain_sampler.gd","\tvar host:RefCounted=_host.get_ref();var scale:float=settings.ridge_scale","\tvar result:=Vector3(center,slope,0)"]]:
		var current:String="res://scripts/"+item[0];var frozen:String=BASE+item[0]+".txt"
		guards[current]=FileAccess.get_sha256(current);guards[frozen]=FileAccess.get_sha256(frozen)
		var a:String=FileAccess.get_file_as_string(current).replace("\r\n","\n");var b:String=FileAccess.get_file_as_string(frozen).replace("\r\n","\n")
		var before:String=block(b,item[1],item[2])+item[2];var after:String=block(a,item[1],item[2])+item[2]
		assert(before==after,"River numerical formula must remain byte-identical to the pre-fix production snapshot")
		results.append({"source":current,"formula_sha256":after.sha256_text(),"exact":true})
	guards["res://tools/biome_extensions/check_river_formula_contract.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_river_formula_contract.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_river_formula_contract.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"formulas":results,"scope":"Exact river center,column and Mountain carrier numerical statements versus the frozen immediately preceding production revision. Cache key/namespace policy alone changed;not a new river route formula."},"  "));print("RIVER_FORMULA_CONTRACT three exact frozen numerical blocks");quit()
