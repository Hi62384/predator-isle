extends "res://tools/biome_extensions/check_all.gd"
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Definition=preload("res://scripts/caves/biome_definition.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/biome_regions.gd","res://scripts/caves/biome_definition.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://config/world/terrain_settings.tres","res://config/caves/cave_biome_regions.tres"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config:Resource=Fixture.registry(load("res://config/caves/cave_biome_regions.tres"),definition);var records:Array=[];var positives:int=0;var sand_positives:int=0;var legacy:Resource=load("res://config/caves/cave_biome_regions.tres")
	for beaches:bool in [false,true]:
		for seed_id:int in [73921,17,92881]:
			var b=make_builder(0,seed_id);b.settings.rocky_coast_enabled=true;b.settings.rocky_coast.coverage=1;b.settings.beaches_enabled=beaches;b._configure_noise();var planner=Regions.new();planner.configure(b,config,seed_id);var old=Regions.new();old.configure(b,legacy,seed_id)
			for i in range(16):
				var p:=Vector2((i*7919)%160000-80000,(i*11939)%160000-80000)
				for j in range(5):var f:Vector3=b._coast.coast_frame(p);p-=Vector2(f.y,f.z)*clampf(f.x,-40000,40000)
				p+=Vector2.from_angle(i*1.73)*350;var point:=Vector3(p.x,0,p.y);var underlying:Dictionary=old.surface_mix(point);check(not underlying.has("rocky_coast") and not underlying.has("desert") and not underlying.has("snow"),"Default+Frozen-only surface mix remains its original16-owner table,without dormant owners")
				var hint:float=b._island_mask(p.x,p.y)*maxf(b.settings.island_size*.5,8);b._coast.sample(p.x,p.y,0,hint,true);var state:PackedFloat64Array=b._coast.state.duplicate();var amount:float=clampf(state[2],0,1)*(1-clampf(state[19],0,1));var mixed:Dictionary=planner.surface_mix(point)
				check(is_equal_approx(float(mixed.get("rocky_coast",0)),amount),"Crystal Rocky Coast uses actual canonical ROCK overlay minus retained beach fraction")
				for name:String in underlying:check(is_equal_approx(float(mixed[name]),float(underlying[name])*(1-amount)),"Actual underlying owner remains normalized beneath coastal overlay")
				var sum:float=0
				for value in mixed.values():sum+=float(value)
				check(absf(sum-1)<.000001,"Coastal affinity mix has one normalized total,not double-counted rock+underlying surface")
				var expected:float=.65*(1-amount)+.1*amount;check(absf(Definition.preference(definition.surface_preferences,mixed)-expected)<.000001,"Requested Quarry65/RockyCoast10 affinity blended by actual overlay,not seventeenth owner or Desert replacement")
				b._last_coast=Vector4(999,999,999,999);b._sample_normal_height(p.x,p.y);planner.surface_mix(point+Vector3(8000,0,-8000));check(var_to_bytes(planner.surface_mix(point))==var_to_bytes(mixed),"Height cache/state poisoning and reversed query restore exact canonical coast suitability")
				if amount>0:positives+=1
				if beaches and state[19]>.05:sand_positives+=1
				records.append({"seed":seed_id,"beaches":beaches,"point":str(p),"coast_influence":state[2],"sand_fraction":state[19],"actual_rock_mix":amount,"affinity":Definition.preference(definition.surface_preferences,mixed)})
			b.settings.rocky_coast_enabled=false;b._configure_noise();check(var_to_bytes(planner.surface_mix(Vector3.ZERO))==var_to_bytes(old.surface_mix(Vector3.ZERO)),"Independent rocky-overlay-off restores original numeric mix even if beaches stay enabled")
	check(positives>0 and sand_positives>0,"Fixed96actual geographic probes include positive rock and positive retained beach controls")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable canonical Crystal coast source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_coast.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"positive_rock":positives,"positive_sand":sand_positives,"scope":"Actual canonical Rocky Coast and retained beach overlay suitability over96fixed probes/three seeds/with and without beaches,normalized real Quarry underneath,positive rock/sand,stale height-cache payload poisoning,exact independent overlay-off and unchanged legacy16-owner mixes. No new Desert/Snow/coast owner. Not Crystal cave native traversal,art or complete-world coverage."},"  "));print("CRYSTAL_COAST ",checks," rock=",positives," sand=",sand_positives," failures=",failures);quit(0 if failures.is_empty() else 1)
