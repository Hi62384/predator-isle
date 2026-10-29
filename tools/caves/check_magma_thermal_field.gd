extends "res://tools/caves/check_crystal_features.gd"
const OriginalField:String="res://tools/biome_extensions/artifacts/revisions/experiment_cave_crystal_registered_checkpoint_3c7ec7dc5c1e/sources/scripts/caves/field.gd.txt"
func run()->void:
	var guards:Dictionary={OriginalField:FileAccess.get_sha256(OriginalField)}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	var original:=GDScript.new();original.source_code=FileAccess.get_file_as_string(OriginalField);check(original.reload()==OK,"Full immutable registered pre-Magma field loads independently")
	var region:Dictionary=fixture();var height:Callable=func(_x:float,_z:float)->float:return 200.0
	region.cave_biome_regions.candidates.append({"id":"A/crystal","biome_id":"crystal","distances":{"A":0.0,"B":112.0},"reach_m":350.0,"transition_m":32.0});var annotated:Dictionary=region.duplicate(true);annotated["cave_thermal_sources"]=[{"id":"diagnostic/actual_source_mechanism_tested_separately","point":Vector3(32,20,32),"radius":40.0,"height":40.0,"heat":1.0,"surface_source":"explicit_controlled_fixture"}]
	var before=original.new();var cold=Field.new();var hot=Field.new();var off=Field.new();cold.include_surface_air=false;hot.include_surface_air=false;off.include_surface_air=false;off.enable_thermal_sources=false
	check(before.compile([region],height,[],region.cave_biome_regions) and cold.compile([region],height,[],region.cave_biome_regions) and hot.compile([annotated],height,[],region.cave_biome_regions) and off.compile([annotated],height,[],region.cave_biome_regions),"Independent old,cold,controlled thermal and independent OFF volumes compile")
	var errors:int=0;var probes:int=0
	for x in range(-12,97,4):
		for z in range(12,57,4):
			for y:float in [18.0,20.0,20.95,24.0,32.0,48.0]:
				var point:=Vector3(x,y,z);probes+=1;errors+=int(before.sample(point)!=cold.sample(point) or before.sample(point)!=hot.sample(point) or before.normal(point)!=hot.normal(point) or before.biome_weights_at(point,["frozen","crystal"])!=cold.biome_weights_at(point,["frozen","crystal"]) or before.biome_weights_at(point,["frozen","crystal"])!=off.biome_weights_at(point,["frozen","crystal"]))
	check(errors==0,"All controlled heat sources preserve entire original rock scalar/normals;empty/OFF entire prior biome weights exact")
	var center:=Vector3(32,20.95,32);var weights:Vector4=hot.biome_weights_at(center,["frozen","crystal"]);check(weights.x==0 and weights.y==1,"Actual source heat removes incompatible ice and renormalizes remaining mineral influence without false Default bleed")
	check(hot.heat_at(center)==1 and hot.heat_at(Vector3(90,20.95,32))==0 and hot.hot_bounds(AABB(center-Vector3.ONE,Vector3.ONE*2)) and not hot.hot_bounds(AABB(Vector3(128,20,128),Vector3.ONE*2)),"Finite localized heat and conservative whole-feature hot-bounds admission")
	check(absf(hot.heat_at(Vector3(63.999,20.95,32))-hot.heat_at(Vector3(64.001,20.95,32)))<.001,"Sparse heat field continuous across64m cell boundary")
	for key:Vector3i in [Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0)]:check(var_to_bytes(Mesher.new().build(before,key,2))==var_to_bytes(Mesher.new().build(hot,key,2)),"Entire native rock positions/normals/indices/colors unchanged by thermal compatibility")
	for family:int in [6,7]:
		var biological:Dictionary=annotated.duplicate(true);biological.cave_family=family;var locked=Field.new();locked.include_surface_air=false;check(locked.compile([biological],height,[],biological.cave_biome_regions) and locked.thermal_sources.is_empty() and locked.heat_at(center)==0,"Biological cave ownership rejects injected generic thermal sources")
	var invalid:Dictionary=annotated.duplicate(true);invalid.cave_thermal_sources[0].heat=NAN;var rejected=Field.new();check(not rejected.compile([invalid],height,[],invalid.cave_biome_regions) and rejected.thermal_sources.is_empty() and rejected.thermal_bins.is_empty(),"Malformed nonfinite heat rejected atomically with all caches cleared")
	check(cold.numeric_bytes()==before.numeric_bytes() and hot.thermal_sources.size()==1 and hot.thermal_references<=64,"Zero cold numeric overhead;one bounded numeric source,not a second cave/worker system")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable thermal field source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_thermal_field.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"probes":probes,"mismatches":errors,"controlled_hot_weights":weights,"source_count":hot.thermal_sources.size(),"source_bin_references":hot.thermal_references,"scope":"Controlled normalized intrusion compatibility field versus full immutable pre-Magma field. Same original SDF/normals/three whole native rock arrays;zero-source/OFF biome weights and numeric bytes exact. Local source removes incompatible ice while preserving normalized remainder,whole-feature bounds,cell continuity,biological locks,nonfinite atomic rejection and numeric bounds. Actual source mechanism separately tested against real retained surface lava. Not yet Magma geometry/provider integration or native hot-cave rendering/traversal."},"  "));print("MAGMA_THERMAL_FIELD ",checks," probes=",probes," mismatches=",errors," weights=",weights," failures=",failures);quit(0 if failures.is_empty() else 1)
