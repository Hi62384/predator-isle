extends SceneTree
const CASES="res://tools/biome_extensions/artifacts/revisions/experiment_badlands_fan_apron_adoption_505e5ee259a6/sources/tools/badlands/artifacts/check_fan_geometry.json.txt"
func _initialize()->void:
	var guards:Dictionary={}
	for path:String in [CASES,"res://tools/badlands/profile_fan_gradient.gd","res://tools/badlands/check_fan_gradient.gd","res://tools/badlands/check_fan_geometry.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/badlands_sampler.gd","res://scripts/badlands_settings.gd","res://scripts/badlands_fan_geometry.gd"]:guards[path]=FileAccess.get_sha256(path)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(CASES));var records:Array=[];var ratios:Array=[]
	for repetition in range(3):
		for item:Dictionary in fixture.cases:
			var seed_id:int=item.seed;var site:Dictionary=item.floor_cases[repetition]
			var locator=preload("res://tools/badlands/check_fan_gradient.gd").builder(seed_id,0);var tree:Dictionary=locator._badlands._tree(int(site.index),int(site.lane),1)
			var root:Vector3=tree.root;var cell:=Vector2i(floori(root.x/256),floori(root.z/256));var times:Dictionary={};var vertices:int=0
			for gradient:float in ([0,.025] if repetition%2==0 else [.025,0]):
				var b=preload("res://tools/badlands/check_fan_gradient.gd").builder(seed_id,gradient)
				var start:int=Time.get_ticks_usec();var arrays:Array=b.build(cell,128);b.build_swamp_water(arrays,128);times[gradient>0]=float(Time.get_ticks_usec()-start)/1000;vertices=arrays[Mesh.ARRAY_VERTEX].size()
			var ratio:float=times[true]/maxf(times[false],.001);ratios.append(ratio)
			records.append({"repetition":repetition,"seed":seed_id,"index":site.index,"lane":site.lane,"cell":str(cell),"resolution":128,"vertices":vertices,"zero_ms":times[false],"graded_ms":times[true],"ratio":ratio})
	for path:String in guards:assert(FileAccess.get_sha256(path)==guards[path])
	ratios.sort();var result:Dictionary={"passed":true,"failures":[],"source_sha256":guards,"cases":records,"median_graded_to_zero_ratio":ratios[ratios.size()/2],"scope":"Nine alternating-order cold-builder near128 fan-root mesh/water pairs,three seeds/nine fixed logical fan sites,one engine. This records the added sampling cost,not a speedup claim or isolated runtime frame/streaming benchmark. Workers,mesh density and shader unchanged."}
	FileAccess.open("res://tools/badlands/artifacts/profile_fan_gradient.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("FAN_GRADIENT_COST median ratio=",result.median_graded_to_zero_ratio);quit()
