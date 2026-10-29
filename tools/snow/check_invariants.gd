extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func make_builder(seed_value:int,biome:int):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=seed_value
	b.settings.grass_coverage=100 if biome==0 else (50 if biome==3 else 0);b.settings.desert_coverage=100 if biome==1 else (50 if biome==3 else 0);b.settings.snow_coverage=100 if biome==2 else 0;b.settings.stone_coverage=100 if biome==4 else 0;b.settings.temperature_enabled=false
	b._configure_noise();return b
func _initialize()->void:
	var start:int=Time.get_ticks_msec()
	for seed_value in [73921,17,92881]:
		var b=make_builder(seed_value,2);var sampler=b._snow
		var points:Array[Vector2]=[];var values:Array=[]
		for i in range(160):
			var p:=Vector2((i*7139)%80000-40000,(i*11939)%80000-40000);points.append(p)
			var h:float=b._sample_grid_height(p.x,p.y);var packed:PackedFloat32Array=b._last_snow.duplicate();values.append([h,packed])
			check(is_finite(h),"Finite height")
			check(h==b._get_height(p.x,p.y,false),"Height-only query exactness")
			for value in packed:check(value==floorf(value) and value>=0 and value<=16777215,"Exact 24-bit control")
		# Force worker-local cache eviction, then reverse query order.
		sampler._nodes.clear();sampler._regions.clear();sampler._sites.clear();b._height_grid_cache.clear();b._normal_height_cache.clear()
		for i in range(points.size()-1,-1,-1):
			var p:Vector2=points[i];var h:float=b._sample_grid_height(p.x,p.y)
			check(h==values[i][0] and b._last_snow==values[i][1],"Order/cache-independent output")
		for i in range(20):
			var x:float=i*64.0-640;var z:float=i*41.7
			var left:float=sampler.sample(x-.01,z);var center:float=sampler.sample(x,z);var right:float=sampler.sample(x+.01,z)
			check(absf(right-left)<2,"Continuous canonical lattice")
			check(absf((right-center)-(center-left))<.03,"C1 lattice derivative")
			var derivative:Vector2=sampler.gradient(x,z)
			var finite:=Vector2((sampler.sample(x+.125,z)-sampler.sample(x-.125,z))/.25,(sampler.sample(x,z+.125)-sampler.sample(x,z-.125))/.25)
			check(derivative.distance_to(finite)<.035,"Analytic derivative matches canonical heightfield")
		# Regression: regional transitions previously generated 64 m ladders
		# and 512 m shelves despite the Hermite field itself being continuous.
		for i in range(30):
			var p:=Vector2(floorf(float((i*7919)%160000-80000)/64)*64,floorf(float((i*13513)%160000-80000)/64)*64)
			var node:Vector4=sampler._node(Vector2i(p/64))[0]
			var h:float=sampler._shape(p,sampler.region_weights(p),false)
			var px:Vector2=p+Vector2(16,0);var pz:Vector2=p+Vector2(0,16)
			var expected:=Vector2((sampler._shape(px,sampler.region_weights(px),false)-h)/16,(sampler._shape(pz,sampler.region_weights(pz),false)-h)/16)
			# Node height is stored in Vector4 (float32), raw scalar is float64.
			check(absf(node.x-h)<=maxf(.00001,absf(h)*1.2e-7),"No height correction after tangent computation")
			check(Vector2(node.y,node.z).distance_to(expected)<.00001,"Knot tangents include regional weight gradients")
		b.chunk_size=256
		var land_coordinate:=Vector2i.ZERO
		for p in points:
			if b._island_mask(p.x,p.y)>.05:
				land_coordinate=Vector2i(floori(p.x/256),floori(p.y/256));break
		var dense:Array=b.build(land_coordinate,64);var sparse:Array=b.build(land_coordinate,16)
		for z in range(17):
			for x in range(17):
				var a:int=z*17+x;var d:int=z*4*65+x*4
				check(dense[Mesh.ARRAY_VERTEX][d]==sparse[Mesh.ARRAY_VERTEX][a],"Shared LOD height")
				check(dense[Mesh.ARRAY_NORMAL][d].distance_to(sparse[Mesh.ARRAY_NORMAL][a])<.00001,"Shared LOD normal")
				for channel in range(4):check(dense[Mesh.ARRAY_CUSTOM3][d*4+channel]==sparse[Mesh.ARRAY_CUSTOM3][a*4+channel],"Shared LOD control")
		b.settings.water_enabled=false;b._configure_noise()
		for p in points:
			b._get_height(p.x,p.y);check(b._snow.b.z==0 and b._snow.b.w==0 and b._snow_frozen==0,"Water disabled: no frozen bodies")
		check(sampler.freeze(Vector2.ZERO,0,1)==0 and sampler.freeze(Vector2.ZERO,1,1)==1 and sampler.freeze(Vector2.ZERO,1,0)==0,"Freeze endpoint controls")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/snow_previews.json"))
	var ordinary=make_builder(73921,2);var evicting=make_builder(73921,2);evicting.cache_dense_payloads=true
	var a_arrays:Array=ordinary.build(Vector2i.ZERO,128);var b_arrays:Array=evicting.build(Vector2i.ZERO,128)
	for channel in range(Mesh.ARRAY_MAX):check(a_arrays[channel]==b_arrays[channel],"Normal eligibility survives mid-build payload-cache eviction")
	check(manifest.features.size()==17,"Seventeen reproducible Snow previews")
	var water=make_builder(73921,2)
	water.settings.snow.lake_ice_coverage=1;water.settings.snow.river_ice_coverage=1;water._configure_noise()
	var lake:Dictionary=manifest.features.frozen_lakes;var tested:int=0
	for z in range(-32,33,8):
		for x in range(-32,33,8):
			var h:float=water._get_height(float(lake.x)+x,float(lake.z)+z)
			if water._snow_water_mask.x>.99999:
				tested+=1;check(h>water.water_level+absf(water.settings.wave_height)*.31,"Solid ice above water wave envelope")
	check(tested>0,"Frozen lake test used actual water interior")
	var bank_normals:int=0
	var tile:=Vector2i(floori(float(lake.x)/256),floori(float(lake.z)/256))
	for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
		var key:Vector2i=tile+offset;var arrays:Array=water.build(key,16)
		for z in range(0,17,2):
			for x in range(0,17,2):
				var wx:float=key.x*256+x*16;var wz:float=key.y*256+z*16
				var h:float=water._get_height(wx,wz)
				if water._snow_water_mask.x>0 and h>8:
					var heights:=PackedFloat32Array([h,water._get_height(wx+32,wz,false),water._get_height(wx,wz+32,false)])
					var expected:=Vector3((heights[0]-heights[1])*2,64,(heights[0]-heights[2])*2).normalized()
					check(expected.distance_to(arrays[Mesh.ARRAY_NORMAL][z*17+x])<.00001,"Lake banks use carved-height normals, never raw Snow derivatives")
					bank_normals+=1
	check(bank_normals>0,"Bank-normal comparison exercised actual lake banks")
	for z in range(-320,321,16):
		for x in range(-320,321,16):
			var h:float=water._get_height(float(lake.x)+x,float(lake.z)+z)
			if water._snow_water_mask.x>.05:check(h>=water.water_level,"Full freezing must not create an annular water moat")
	water.settings.snow.lake_ice_coverage=.5;water._configure_noise()
	var partial:Dictionary=manifest.features.partial_lake;var open_count:int=0;var solid_count:int=0
	for z in range(-160,161,16):
		for x in range(-160,161,16):
			var h:float=water._get_height(float(partial.x)+x,float(partial.z)+z)
			if water._snow_water_mask.x>.9:
				if h<water.water_level-.5:open_count+=1
				if h>water.water_level+absf(water.settings.wave_height)*.31:solid_count+=1
	check(open_count>0 and solid_count>0,"Partial lake has actual open water and solid ice")
	water.settings.snow.lake_ice_coverage=0;water.settings.snow.river_ice_coverage=0;water.settings.snow.coastal_ice=0;water._configure_noise()
	water._get_height(float(lake.x),float(lake.z));check(water._snow.b.z==0 and water._snow.b.w==0,"Ice coverage controls disable frozen bodies")
	# This local snapshot was captured before ANY Snow edits. It is ignored,
	# not a second production implementation or a required runtime asset.
	if FileAccess.file_exists("res://tools/snow/baseline/snow_sampler_before_optimization.gd"):
		for seed_value in [73921,17,92881]:
			var current=preload("res://scripts/snow_sampler.gd").new();var reference=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/snow/baseline/snow_sampler_before_optimization.gd").new()
			# The snapshot predates glacial-wall rock exposure. Isolate exact
			# landform pruning with rock disabled; validate that new control below.
			var config:=SnowSettings.new();config.rock_exposure=0;config.ruggedness=0
			current.configure(config,seed_value);reference.configure(config,seed_value)
			for i in range(240):
				var p:=Vector2((i*7919)%160000-80000,(i*13513)%160000-80000)
				# Compare the optimized raw landform, not the Hermite interpolation:
				# current tangents now correctly include regional weight gradients.
				var h:float=current._shape(p,current.region_weights(p),true)
				var old_h:float=reference._shape(p,current.region_weights(p),true)
				check(h==old_h and current._raw_surface==reference._raw_surface and current._raw_depth==reference._raw_depth,"Zero-weight pruning preserves raw Snow landform")
	var rock_sampler=preload("res://scripts/snow_sampler.gd").new();rock_sampler.configure(SnowSettings.new(),73921)
	var glacier_site:Dictionary=manifest.features.valley_glacier
	rock_sampler.sample(float(glacier_site.x),float(glacier_site.z))
	check(rock_sampler.c.x>.3,"Glacial valley walls have a nonzero rock-exposure control")
	if FileAccess.file_exists("res://tools/snow/baseline/builder.gd"):
		for biome in [0,1,3,4]:
			var b=make_builder(73921,biome);var old=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/snow/baseline/builder.gd").new()
			old.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old.world_seed=b.world_seed;old._configure_noise()
			for coordinate in [Vector2i.ZERO,Vector2i(-11,7)]:
				var a:Array=b.build(coordinate,16);var c:Array=old.build(coordinate,16)
				for channel in range(Mesh.ARRAY_MAX):check(a[channel]==c[channel],"Pure Grass/Desert exact baseline channel "+str(channel))
	var result:Dictionary={"checks":checks,"failures":failures,"elapsed_s":(Time.get_ticks_msec()-start)/1000.0,"seeds":[73921,17,92881],"pre_snow_snapshot_available":FileAccess.file_exists("res://tools/snow/baseline/builder.gd"),"optimization_snapshot_available":FileAccess.file_exists("res://tools/snow/baseline/snow_sampler_before_optimization.gd"),"collision_note":"Project has no terrain collision generator. Heightfield checks do not certify collision."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/snow/artifacts"))
	var file:=FileAccess.open("res://tools/snow/artifacts/invariants.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("SNOW_INVARIANTS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
