extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	assert(ok,label)
func builder(seed_value:int=73921):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.world_seed=seed_value
	for biome:String in ["grass","forest","savanna","jungle","swamp","mountain"]:b.settings.set(biome+"_coverage",0)
	b.settings.tropical_coverage=100;b._configure_noise();return b
func _initialize()->void:
	var start:int=Time.get_ticks_msec()
	for seed_value:int in [73921,17,92881]:
		var b=builder(seed_value);var samples:Array=[]
		for i in range(160):
			var p:=Vector2((i*7919)%160000-80000,(i*11939)%160000-80000)
			var h:float=b._sample_grid_height(p.x,p.y);samples.append([p,h,b._last_tropical,b._last_swamp_water])
			check(is_finite(h) and is_finite(b._last_swamp_water),"Finite land and water")
			check(h==b._get_height(p.x,p.y,false),"Height-only query identical")
		b._height_grid_cache.clear();b._tropical._nodes.clear();b._tropical._regions.clear();b._tropical._carriers.clear();b._tropical._structural_nodes.clear()
		samples.reverse()
		for a:Array in samples:check(a[1]==b._sample_grid_height(a[0].x,a[0].y) and a[2]==b._last_tropical and a[3]==b._last_swamp_water,"Order/cache independent land water controls")
		for x:float in [-128,0,256,1024]:
			for z:float in [-128,0,256]:
				var h:float=b._tropical.sample(x,z);var left:float=(h-b._tropical.sample(x-.02,z))/.02;var right:float=(b._tropical.sample(x+.02,z)-h)/.02
				check(absf(left-right)<.01,"C1 canonical height")
		for x:float in [-2048,0,2048]:
			for lane in range(-1,2):
				var center:float=b._tropical._structural_center(x,lane)
				var dl:float=(center-b._tropical._structural_center(x-.02,lane))/.02;var dr:float=(b._tropical._structural_center(x+.02,lane)-center)/.02
				check(absf(dl-dr)<.005,"C1 broad carrier, independent of mesh LOD")
		check(b._tropical._nodes.size()<=16384 and b._tropical._regions.size()<=2048 and b._tropical._carriers.size()<=2048 and b._tropical._structural_nodes.size()<=2048,"Bounded numerical caches")
	var b=builder();var a:Array=b.build(Vector2i(21,17),64);var right:Array=b.build(Vector2i(22,17),64)
	for z in range(65):
		var i:int=z*65+64;var j:int=z*65
		check(a[Mesh.ARRAY_VERTEX][i].y==right[Mesh.ARRAY_VERTEX][j].y,"Adjacent height")
		check(a[Mesh.ARRAY_TEX_UV][i].x==right[Mesh.ARRAY_TEX_UV][j].x,"Adjacent water")
		check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(right[Mesh.ARRAY_NORMAL][j]),"Adjacent canonical normals")
		for bank in [Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
			for k in range(4):check(a[bank][i*4+k]==right[bank][j*4+k],"Adjacent packed controls")
	for lod in range(1,7):
		b.chunk_size=256*float(1<<lod);var large:Array=b.build(Vector2i.ONE,16)
		b.chunk_size=256*float(1<<(lod-1));var small:Array=b.build(Vector2i(2,2),16)
		for z in range(9):
			for x in range(9):
				var i:int=z*17+x;var j:int=z*2*17+x*2
				check(large[Mesh.ARRAY_VERTEX][i].y==small[Mesh.ARRAY_VERTEX][j].y,"LOD height "+str(lod))
				check(large[Mesh.ARRAY_TEX_UV][i].x==small[Mesh.ARRAY_TEX_UV][j].x,"LOD water "+str(lod))
				check(large[Mesh.ARRAY_NORMAL][i].is_equal_approx(small[Mesh.ARRAY_NORMAL][j]),"LOD normals "+str(lod))
	var mixed=builder();mixed.settings.grass_coverage=50;mixed.settings.forest_coverage=20;mixed.settings.savanna_coverage=20;mixed.settings.swamp_coverage=20;mixed.settings.jungle_coverage=20;mixed.settings.mountain_coverage=20;mixed._configure_noise()
	for i in range(1000):
		var w:Vector4=mixed._biome_weights(i*7919%1000000-500000,i*11939%1000000-500000)
		check(absf(w.x+w.y+w.z+w.w+mixed._jungle_weight+mixed._mountain_weight+mixed._tropical_weight-1)<.00001,"Seven normalized inland owners")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_previews.json"))
	b=builder();b.chunk_size=256
	var flooded:Dictionary=manifest.features.freshwater_lake
	var land:Array=b.build(Vector2i(floori(flooded.x/256),floori(flooded.z/256)),64);var water:Array=b.build_swamp_water(land,64)
	check(not water.is_empty(),"Actual lake produces shared local water")
	for i:int in water[Mesh.ARRAY_INDEX]:
		check(water[Mesh.ARRAY_VERTEX][i].y==land[Mesh.ARRAY_TEX_UV][i].x,"Shared canonical lake height")
		check(water[Mesh.ARRAY_COLOR][i].b==0 and water[Mesh.ARRAY_TEX_UV2][i].y<0,"Tropical water cannot receive Swamp flood stage")
	for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]:
		mixed=builder();mixed.settings.tropical_coverage=50;mixed.settings.set(biome+"_coverage",50);mixed.settings.set(biome+"_region_size",14000);mixed._configure_noise()
		var f:Dictionary=manifest.features[biome+"_tropical_transition"];var cell:=Vector2i(floori(f.x/256),floori(f.z/256));var mesh:Array=mixed.build(cell,16)
		check(mesh[Mesh.ARRAY_CUSTOM2]!=null and mesh[Mesh.ARRAY_CUSTOM2][0]<0,"Mixed mesh uses signed extension")
		for i in range(0,17*17,11):
			var p:Vector3=mesh[Mesh.ARRAY_VERTEX][i]+Vector3(cell.x*256,0,cell.y*256)
			mixed._get_height(p.x,p.z)
			var old:Array=[mixed._last_forest,mixed._last_savanna,mixed._last_swamp]
			for bank in range(3):
				var encoded:float=mesh[Mesh.ARRAY_CUSTOM1+bank][i*4]
				check(encoded<0 and (int(-encoded-1)&65535)==(int(old[bank][0])&65535),"Existing ecological bytes survive Tropical mixing")
			var tw:float=float((int(-mesh[Mesh.ARRAY_CUSTOM2][i*4]-1)>>16)&255)/255
			check(absf(tw-mixed._last_tropical.x)<=.5/255+.00001,"Canonical Tropical ownership byte")
	# Tropical=0 keeps the entire archived six-inland mesh layout and values.
	var reference=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/rocky_coast/baseline/builder.gd").new()
	for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]:
		b=builder();b.settings.tropical_coverage=0;b.settings.set(biome+"_coverage",100);b._configure_noise();reference.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);reference._configure_noise()
		var before:Array=reference.build(Vector2i(21,17),16);var after:Array=b.build(Vector2i(21,17),16)
		for channel in range(Mesh.ARRAY_MAX):check(before[channel]==after[channel],"Disabled Tropical preserves "+biome+" array "+str(channel))
	print("TROPICAL_INVARIANTS_PASS ",checks," checks; ",Time.get_ticks_msec()-start," ms")
	FileAccess.open("res://tools/tropical/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":true,"elapsed_ms":Time.get_ticks_msec()-start,"sampler_sha256":FileAccess.get_sha256("res://scripts/tropical_sampler.gd"),"collision":"not installed"},"\t"))
	quit()
