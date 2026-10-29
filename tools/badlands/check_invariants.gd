extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func builder(seed_value:int=73921):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=seed_value;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:b.settings.set(biome+"_coverage",0)
	b.settings.badlands_coverage=100;b._configure_noise();return b
func _initialize()->void:
	var start:int=Time.get_ticks_msec()
	for i in range(-1000,1001):
		var value:float=float(i)/250;var restored:float=float(roundi(clampf(value,-.5,.5)*254))/254
		check(absf(smoothstep(.03,.35,value)-smoothstep(.03,.35,restored))<.01 and absf(smoothstep(.03,.35,-value)-smoothstep(.03,.35,-restored))<.01,"Bounded Grass curvature-mask quantization error")
	# Pre-change full-array hashes; never regenerate them in this test.
	var baseline=JSON.parse_string(FileAccess.get_file_as_string("res://data/pre_badlands_mesh_hashes.json"))
	for record:Dictionary in baseline.records:
		var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.badlands_coverage=0
		var preset:String=record.preset
		if preset!="saved_world":
			for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:b.settings.set(biome+"_coverage",0)
			b.settings.beaches_enabled=preset=="coast";b.settings.rocky_coast_enabled=preset=="coast";b.settings.tropical_coverage=100 if preset!="mountain" else 0
			if preset=="mountain":b.settings.mountain_coverage=100
			if preset=="mixed_tropical":b.settings.forest_coverage=50;b.settings.forest_region_size=14000
		b._configure_noise();var mesh:Array=b.build(Vector2i(record.cell[0],record.cell[1]),16)
		for channel in range(Mesh.ARRAY_MAX):
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(mesh[channel]));check(hash.finish().hex_encode()==record.hashes[channel],"Pre-Badlands exact array "+preset+" / "+str(channel))
	for seed_value:int in [73921,17,92881]:
		var b=builder(seed_value);var samples:Array=[]
		for i in range(140):
			var p:=Vector2(i*7919%160000-80000,i*11939%160000-80000);var h:float=b._sample_grid_height(p.x,p.y)
			check(is_finite(h) and is_finite(b._last_swamp_water),"Finite land/water");check(h==b._get_height(p.x,p.y,false),"Full/height-only agreement")
			b._get_height(p.x,p.y);samples.append([p,h,b._last_badlands,b._last_swamp_water])
		b._height_grid_cache.clear();b._badlands._nodes.clear();b._badlands._patches.clear();b._badlands._patch_ring.clear();b._badlands._patch_cursor=0;b._badlands._regions.clear();b._badlands._trees.clear();b._badlands._carriers.clear();samples.reverse()
		for sample:Array in samples:
			check(sample[1]==b._sample_grid_height(sample[0].x,sample[0].y) and sample[2]==b._last_badlands and sample[3]==b._last_swamp_water,"Cache/order determinism")
		for x:float in [-128,0,256]:
			for z:float in [-128,0,256]:
				var h:float=b._badlands.sample(x,z);var left:float=(h-b._badlands.sample(x-.02,z))/.02;var right:float=(b._badlands.sample(x+.02,z)-h)/.02
				check(absf(left-right)<.015,"C1 height lattice")
		check(b._badlands._nodes.size()<=16384 and b._badlands._trees.size()<=512 and b._badlands._regions.size()<=2048,"Bounded caches")
	var b=builder();var a:Array=b.build(Vector2i(21,17),64);var right:Array=b.build(Vector2i(22,17),64)
	for z in range(65):
		var i:int=z*65+64;var j:int=z*65
		check(a[Mesh.ARRAY_VERTEX][i].y==right[Mesh.ARRAY_VERTEX][j].y,"Adjacent height");check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(right[Mesh.ARRAY_NORMAL][j]),"Adjacent normals");check(a[Mesh.ARRAY_TEX_UV][i]==right[Mesh.ARRAY_TEX_UV][j],"Adjacent water/payload")
	for lod in range(1,7):
		b.chunk_size=256*float(1<<lod);var parent:Array=b.build(Vector2i.ONE,16);b.chunk_size*=.5;var child:Array=b.build(Vector2i(2,2),16)
		for z in range(9):
			for x in range(9):
				var i:int=z*17+x;var j:int=z*2*17+x*2
				check(parent[Mesh.ARRAY_VERTEX][i].y==child[Mesh.ARRAY_VERTEX][j].y,"LOD height");check(parent[Mesh.ARRAY_NORMAL][i].is_equal_approx(child[Mesh.ARRAY_NORMAL][j]),"LOD normals")
	var mixed=builder()
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:mixed.settings.set(biome+"_coverage",20)
	mixed._configure_noise()
	for i in range(1000):
		var w:Vector4=mixed._biome_weights(i*7919%1000000-500000,i*11939%1000000-500000)
		check(absf(w.x+w.y+w.z+w.w+mixed._jungle_weight+mixed._mountain_weight+mixed._tropical_weight+mixed._badlands_weight-1)<.00001,"Eight-owner normalization")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:
		mixed=builder();mixed.settings.badlands_coverage=50;mixed.settings.set(biome+"_coverage",50);mixed.settings.set(biome+"_region_size",14000);mixed._configure_noise()
		var f:Dictionary=manifest.features[biome+"_badlands_transition"];var cell:=Vector2i(floori(f.x/256),floori(f.z/256));var mesh:Array=mixed.build(cell,16)
		check(mesh[Mesh.ARRAY_CUSTOM0].size()==mesh[Mesh.ARRAY_VERTEX].size()*4,"Signed Jungle wrapper has explicit RGBA stride")
		for i in range(0,17*17,7):
			var p:Vector3=mesh[Mesh.ARRAY_VERTEX][i]+Vector3(cell.x*256,0,cell.y*256);mixed._get_height(p.x,p.z)
			var bank:PackedFloat32Array=mesh[Mesh.ARRAY_CUSTOM0]
			check(bank[i*4+3]<0 and int(-bank[i*4+3]-1)==int(mixed._last_jungle),"All Jungle ecology and ownership bytes preserved")
			var packed:int=int(mesh[Mesh.ARRAY_TEX_UV][i].y)
			check((packed&255)==roundi(mixed._last_badlands.x*255),"Badlands ownership byte")
			check(((packed>>8)&255)==roundi(mixed._last_badlands.z*255),"Badlands regional byte")
			var expected:Array=[mixed._last_forest,mixed._last_savanna,mixed._last_swamp]
			for k in range(3):
				var actual=mesh[Mesh.ARRAY_CUSTOM1+k]
				if actual==null:continue
				var old:PackedFloat32Array=expected[k];var first:float=actual[i*4]
				check((int(-first-1) if first<0 else int(first))&65535==int(old[0])&65535,"Old ecology low bytes")
				for j in range(1,4):check(actual[i*4+j]==old[j],"Complete ecological channel retained")
			if biome=="mountain":
				check(bank[i*4+1]==mixed._last_mountain[0] and bank[i*4+2]==mixed._last_mountain[1],"Mountain packed geology/ownership retained")
	b=builder();b.chunk_size=256;var pool:Dictionary=manifest.features.rare_pool
	var land:Array=b.build(Vector2i(floori(pool.x/256),floori(pool.z/256)),64);var water:Array=b.build_swamp_water(land,64)
	check(not water.is_empty(),"Actual rare pool shares existing water grid")
	for i:int in water[Mesh.ARRAY_INDEX]:
		check(water[Mesh.ARRAY_COLOR][i].b==0 and water[Mesh.ARRAY_TEX_UV2][i].y<0,"Badlands pool excludes Swamp flood displacement")
		check(water[Mesh.ARRAY_VERTEX][i].y==land[Mesh.ARRAY_TEX_UV][i].x,"Water uses canonical sampled surface")
	# Tree children start on their parent edge and rise toward the source.
	for lane in range(-2,3):
		for index in range(-4,5):
			for side in [-1,1]:
				var tree:Dictionary=b._badlands._tree(index,lane,side);var edges:Array=tree.edges
				for k in range(edges.size()):
					var edge:Array=edges[k];check(edge[1].y>edge[0].y,"Descriptor drainage grades descend toward parent")
					if k==0:continue
					var connected:bool=false
					for j in range(k):
						var origin:Vector3=edges[j][0];var d:Vector3=edges[j][1]-origin;var t:float=clampf((edge[0]-origin).dot(d)/d.length_squared(),0,1)
						if (origin+d*t).distance_to(edge[0])<.01:connected=true;break
					check(connected,"Every tributary connects to an existing parent")
	var stress=preload("res://tools/badlands/all_owner_builder.gd").new();stress.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);stress.settings.beaches_enabled=false;stress.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]:stress.settings.set(biome+"_coverage",20)
	stress._configure_noise();var all_mesh:Array=stress.build(Vector2i(21,17),16)
	for i in range(0,17*17,11):
		var p:Vector3=all_mesh[Mesh.ARRAY_VERTEX][i]+Vector3(21*256,0,17*256);stress._get_height(p.x,p.z)
		var bank:PackedFloat32Array=all_mesh[Mesh.ARRAY_CUSTOM0]
		check(int(-bank[i*4+3]-1)==int(stress._last_jungle),"Stress Jungle signed wrapper")
		check(bank[i*4+1]==stress._last_mountain[0] and bank[i*4+2]==stress._last_mountain[1],"Stress Mountain channels coexist")
		var others:Array=[stress._last_forest,stress._last_savanna,stress._last_swamp]
		for k in range(3):
			var payload:PackedFloat32Array=all_mesh[Mesh.ARRAY_CUSTOM1+k]
			check((int(-payload[i*4]-1)&65535)==(int(others[k][0])&65535),"Stress ecological bytes survive both extensions")
			for j in range(1,4):check(payload[i*4+j]==others[k][j],"Stress complete ecological channels")
		check((int(all_mesh[Mesh.ARRAY_TEX_UV][i].y)&255)==32,"Stress Badlands ownership byte")
		check(((int(-all_mesh[Mesh.ARRAY_CUSTOM2][i*4]-1)>>16)&255)==32,"Stress Tropical ownership byte")
	# Force every new cache through its eviction branch, preserving canonical results.
	var field=b._badlands;var expected:float=field.sample(320,640)
	field._nodes.clear();field._regions.clear();field._carriers.clear();field._trees.clear()
	for i in range(16384):field._nodes[Vector2i(10000000+i,10000000)]=PackedFloat64Array()
	for i in range(2048):field._regions[Vector2i(10000000+i,10000000)]=PackedFloat32Array();field._carriers[Vector2i(10000000+i,10000000)]=0
	for i in range(512):field._trees[Vector3i(10000000+i,10000000,1)]={}
	check(field.sample(320,640)==expected,"Eviction preserves height")
	check(field._nodes.size()<=16384 and field._regions.size()<=2048 and field._carriers.size()<=2048 and field._trees.size()<=512,"All cache limits after forced eviction")
	var report:Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"elapsed_ms":Time.get_ticks_msec()-start,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"collision":"Not exercised by this numeric test; production collision has separate streamed-walk acceptance"}
	FileAccess.open("res://tools/badlands/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("BADLANDS_INVARIANTS_","PASS " if failures.is_empty() else "FAIL ",report);quit(0 if failures.is_empty() else 1)
