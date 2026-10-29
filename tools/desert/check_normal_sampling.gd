extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
func _initialize() -> void:
	var failures: Array=[];var rows: Array=[];var changed_desert: bool=false
	for coverage in [0.0,50.0,100.0]:
		for spec in [[Vector2i(-18,35),256.0,64],[Vector2i(-78,139),256.0,64],[Vector2i(0,1),16384.0,16]]:
			var meshes: Array=[];var times: Array=[]
			for fast in [false,true]:
				var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
				b.settings.grass_coverage=100.0-coverage;b.settings.desert_coverage=coverage
				b.settings.snow_coverage=0;b.settings.stone_coverage=0;b.settings.temperature_enabled=false
				b.settings.desert.fast_normal_sampling=fast;b.chunk_size=spec[1];b._configure_noise()
				var tick: int=Time.get_ticks_usec();meshes.append(b.build(spec[0],spec[2]));times.append((Time.get_ticks_usec()-tick)/1000.0)
			for channel in range(Mesh.ARRAY_MAX):
				if coverage>0.0 and channel in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV]:continue
				if meshes[0][channel]==null or meshes[1][channel]==null:
					if meshes[0][channel]!=meshes[1][channel]:failures.append(str(["Unexpected channel change",coverage,spec,channel]))
				elif meshes[0][channel].to_byte_array()!=meshes[1][channel].to_byte_array():failures.append(str(["Unexpected channel bytes",coverage,spec,channel]))
			for i in range(meshes[1][Mesh.ARRAY_NORMAL].size()):
				var n: Vector3=meshes[1][Mesh.ARRAY_NORMAL][i]
				if not n.is_finite() or absf(n.length()-1.0)>0.00001:failures.append("Invalid normal")
				if meshes[0][Mesh.ARRAY_TEX_UV][i].x!=meshes[1][Mesh.ARRAY_TEX_UV][i].x:failures.append("Water plane changed")
			if coverage==100.0 and meshes[0][Mesh.ARRAY_NORMAL]!=meshes[1][Mesh.ARRAY_NORMAL]:changed_desert=true
			rows.append({"desert_coverage":coverage,"coordinate":str(spec[0]),"span":spec[1],"central_ms":times[0],"fast_ms":times[1]})
	if not changed_desert:failures.append("Fast mode did not affect any Desert normal")
	var report: Dictionary={"failures":failures,"cases":rows,"note":"Vertex geometry, material payloads and water planes are exact across modes; pure Grass preserves EVERY channel. Desert lighting normals/unused Desert curvature intentionally differ. Existing hierarchy checks cover shared coordinates. Timing rows are diagnostic, not a streaming benchmark."}
	FileAccess.open("res://tools/desert/normal_sampling_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
