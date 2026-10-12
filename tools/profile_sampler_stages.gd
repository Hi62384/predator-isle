extends SceneTree

# Diagnostic subclass only: timestamp overhead is absent from game samplers.
class Profiled extends "res://scripts/terrain_mesh_builder.gd":
	var timings: Dictionary={}
	func record(stage: String,start: int) -> void:
		timings[stage]=timings.get(stage,0)+Time.get_ticks_usec()-start
	func _island_mask(x: float,z: float) -> float:
		var start:=Time.get_ticks_usec()
		var result:=super._island_mask(x,z)
		record("island",start)
		return result
	func _biome_weights(x: float,z: float) -> Vector4:
		var start:=Time.get_ticks_usec()
		var result:=super._biome_weights(x,z)
		record("biome",start)
		return result
	func _grass_sample(x: float,z: float) -> Vector3:
		var start:=Time.get_ticks_usec()
		var result:=super._grass_sample(x,z)
		record("grass_relief_including_water",start)
		return result
	func _river_column(x: float,lane: int,spacing: float) -> Vector3:
		var start:=Time.get_ticks_usec()
		var result:=super._river_column(x,lane,spacing)
		record("river_descriptor_queries_nested_in_grass",start)
		return result
	func _lake_sites(cell: Vector2i,pitch: float) -> Array[Vector4]:
		var start:=Time.get_ticks_usec()
		var result:=super._lake_sites(cell,pitch)
		record("lake_descriptor_queries_nested_in_grass",start)
		return result

func _initialize() -> void:
	var sampler:=Profiled.new()
	sampler.settings=load("res://terrain_settings.tres").duplicate(true)
	sampler.settings.grass_coverage=100
	sampler.settings.desert_coverage=0
	sampler.settings.snow_coverage=0
	sampler.settings.stone_coverage=0
	sampler._configure_noise()
	sampler.profile_build=true
	var records: Dictionary={}
	for resolution in [8,16,64,128]:
		sampler.timings.clear()
		sampler.field_timings.clear()
		sampler.build(Vector2i.ZERO,resolution)
		var record:=sampler.last_build_profile.duplicate()
		record["nested_field_timings_us"]=sampler.field_timings.duplicate()
		for stage in sampler.timings:
			record[stage+"_ms"]=sampler.timings[stage]/1000.0
		records[str(resolution)]=record
	print(JSON.stringify(records))
	FileAccess.open("res://tools/sampler_stages.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit()
