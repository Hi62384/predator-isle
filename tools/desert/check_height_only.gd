extends SceneTree
## Compare the optimized derivative path with full-payload canonical queries.
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
class FullPayloadBuilder extends "res://scripts/terrain_mesh_builder.gd":
	func _sample_normal_height(x: float,z: float) -> float:
		return _sample_grid_height(x,z)

func _initialize() -> void:
	var failures: Array=[]
	var rows: Array=[]
	for coverage in [0.0,50.0,100.0]:
		for spec in [[Vector2i(-18,35),256.0,64],[Vector2i(72,115),256.0,64],[Vector2i(-78,139),256.0,64],[Vector2i(0,1),16384.0,16]]:
			var arrays: Array=[]
			var times: Array=[]
			var optimized: RefCounted
			for full in [true,false]:
				var builder=FullPayloadBuilder.new() if full else Builder.new()
				builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
				builder.settings.grass_coverage=100.0-coverage
				builder.settings.desert_coverage=coverage
				builder.settings.snow_coverage=0;builder.settings.stone_coverage=0
				builder.settings.temperature_enabled=false
				builder.chunk_size=spec[1];builder._configure_noise()
				var tick: int=Time.get_ticks_usec()
				arrays.append(builder.build(spec[0],spec[2]))
				if not full:optimized=builder
				times.append((Time.get_ticks_usec()-tick)/1000.0)
				if builder._normal_height_cache.size()>8192:failures.append("Normal cache bound")
			for channel in range(Mesh.ARRAY_MAX):
				if arrays[0][channel]==null or arrays[1][channel]==null:
					if arrays[0][channel]!=arrays[1][channel]:failures.append(str([coverage,spec,channel]))
				elif arrays[0][channel].to_byte_array()!=arrays[1][channel].to_byte_array():failures.append(str([coverage,spec,channel]))
			# Independently reconstruct the previous loop-based packing from the
			# actual canonical sampler, not a second copy of the optimized formula.
			if arrays[1][Mesh.ARRAY_CUSTOM1]!=null:
				for z in range(0,int(spec[2])+1,4):
					for x in range(0,int(spec[2])+1,4):
						var wx: float=(spec[0].x+float(x)/spec[2])*spec[1]
						var wz: float=(spec[0].y+float(z)/spec[2])*spec[1]
						optimized._get_height(wx,wz)
						var r:=Vector4i.ZERO;var s:=Vector4i.ZERO;var w:=Vector4i.ZERO
						for c in range(4):
							r[c]=roundi(clampf(optimized._last_desert_region[c],0.0,1.0)*255.0)
							s[c]=roundi(clampf(optimized._last_desert_surface[c],0.0,1.0)*255.0)
							var wind: float=optimized._last_desert_wind[c]
							if c<2:wind=wind*0.5+0.5
							w[c]=roundi(clampf(wind,0.0,1.0)*255.0)
						var expected: Array=[r.x+r.y*256+r.z*65536,r.w+s.x*256+s.y*65536,s.z+s.w*256+w.x*65536,w.y+w.z*256+w.w*65536]
						# Zero-weight/underwater samples retain neutral wind (0.5).
						var index: int=(z*(int(spec[2])+1)+x)*4
						for c in range(4):
							if arrays[1][Mesh.ARRAY_CUSTOM1][index+c]!=expected[c]:failures.append("Scalar packing mismatch "+str([coverage,spec,x,z,c]))
			rows.append({"desert_coverage":coverage,"coordinate":str(spec[0]),"span":spec[1],"full_payload_ms":times[0],"height_only_ms":times[1]})
	var report: Dictionary={"failures":failures,"cases":rows,"note":"Every returned mesh channel must be byte-identical. Same process, cold builders; timings diagnostic, not a streaming benchmark."}
	FileAccess.open("res://tools/desert/height_only_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
