extends SceneTree
func _initialize()->void:
	var fixture_path:String="res://tools/biome_extensions/artifacts/check_alien_tissue_transport.json";var fixture=JSON.parse_string(FileAccess.get_file_as_string(fixture_path));assert(fixture.passed)
	var guards:Dictionary=fixture.source_sha256.duplicate();guards[fixture_path]=FileAccess.get_sha256(fixture_path);guards["res://tools/biome_extensions/profile_alien_tissue_flow.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/profile_alien_tissue_flow.gd")
	var records:Array=[];var ratios:Array=[];var failures:Array=[]
	for repetition in range(3):
		for item:Dictionary in fixture.cases:
			if item.profile!=0:continue
			var pieces:PackedStringArray=String(item.cell).trim_prefix("(").trim_suffix(")").split(",");var cell:=Vector2i(int(pieces[0]),int(pieces[1]));var times:Dictionary={};var outputs:Dictionary={};var extra:int=0
			for enabled:bool in ([false,true] if repetition%2==0 else [true,false]):
				var b=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(int(item.seed),enabled);var started:int=Time.get_ticks_usec();var arrays:Array=b.build(cell,128);var water:Array=b.build_swamp_water(arrays,128)
				times[enabled]=float(Time.get_ticks_usec()-started)/1000;outputs[enabled]=[arrays,water,b.built_extension_data.duplicate(),b.built_badlands_palette.duplicate()]
				if enabled:extra=b.built_alien_tissue_flow.size()
			if outputs[false]!=outputs[true]:failures.append("Material flow changed benchmark geometry/ownership "+str(item.seed))
			var ratio:float=times[true]/maxf(times[false],.001);ratios.append(ratio);records.append({"seed":item.seed,"repetition":repetition,"cell":str(cell),"resolution":128,"off_ms":times[false],"on_ms":times[true],"ratio":ratio,"added_numeric_atlas_bytes":extra})
	for path:String in guards:
		if FileAccess.get_sha256(path)!=guards[path]:failures.append("Changed cost source "+path)
	ratios.sort();var result:Dictionary={"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"cases":records,"median_on_to_off_ratio":ratios[ratios.size()/2],"scope":"Nine serial alternating cold-builder near128 mesh/water/material-map pairs at three fixed admitted seeded paths. Complete geometry/water/ownership exact. Records added canonical material-map CPU work and numeric bytes,not a frame-rate speedup or isolated worker/GPU measurement."}
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_alien_tissue_flow.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("TISSUE_FLOW_COST median=",result.median_on_to_off_ratio," failures=",failures);quit(0 if failures.is_empty() else 1)
