extends "res://tools/biome_extensions/check_all.gd"
const Trial=preload("res://tools/biome_extensions/nerve_fibres_candidate.gd")
const Golden=preload("res://tools/biome_extensions/reference_pre_fibres_alien_sampler.gd")
func field_builder(seed_id:int,extent:float,height:float,reference:bool=false,partial:bool=false):
	var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=extent;b.settings.alien_infected.nerve_fibre_height=height
	if partial:b.settings.alien_infected_coverage=0;b.settings.forest_coverage=100;b.settings.alien_infected.overlay_strength=.8
	b._configure_noise()
	if reference:
		var field=Trial.new();field.fibre_height=height;field.configure(b.settings.alien_infected,seed_id,b,7);b._extras[7]=field
	return b
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/nerve_fibres_candidate.gd","res://tools/biome_extensions/reference_pre_fibres_alien_sampler.gd","res://tools/biome_extensions/check_production_nerve_fibres.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[]
	for seed_id:int in [73921,17,92881]:
		for extent:float in [.2,1,2]:
			var actual=field_builder(seed_id,extent,24);var reference=field_builder(seed_id,extent,24,true);var zero=field_builder(seed_id,extent,0)
			var frozen=Golden.new();frozen.configure(zero.settings.alien_infected,seed_id,zero,7)
			var probes:Array[Vector2]=[]
			for i in range(300):probes.append(Vector2(i*7919%180000-90000,i*11939%180000-90000))
			var node:Vector2=actual._extras[7].hive_node(Vector2i(-12,-11))
			for i in range(100):probes.append(node+Vector2(i*16-800,i%9*16-64)*extent)
			for p:Vector2 in probes:
				check(actual._extras[7].sample(p.x,p.y)==reference._extras[7].sample(p.x,p.y) and actual._extras[7].state==reference._extras[7].state,"Production field equals independent preserved trial")
				check(zero._extras[7].sample(p.x,p.y)==frozen.sample(p.x,p.y) and zero._extras[7].state==frozen.state,"Zero setting equals frozen original field and controls")
				check(actual._extras[7].network(p)==frozen.network(p),"Unchanged public network dictionary")
				check(actual._extras[7].nerve_fibre_relief(p)==reference._extras[7].nerve_fibre_relief(p),"Production raw overlay relief equals preserved trial")
			probes.reverse();actual._extras[7]._nodes.clear();actual._extras[7]._network_cache.clear()
			for p:Vector2 in probes:check(actual._extras[7].sample(p.x,p.y)==reference._extras[7].sample(p.x,p.y),"Reverse-order field/cache independence")
			for partial:bool in [false,true]:
				for height:float in [0,24,40]:
					var a=field_builder(seed_id,extent,height,false,partial);var b=field_builder(seed_id,extent,height,true,partial)
					for size:int in [256,2048]:
						a.chunk_size=size;b.chunk_size=size;var cell:=Vector2i(floori(node.x/size),floori(node.y/size))
						var arrays:Array=a.build(cell,16);var payload:PackedByteArray=a.built_extension_data.duplicate();var water:Array=a.build_swamp_water(arrays,16);var expected:Array=b.build(cell,16)
						check(arrays==expected and payload==b.built_extension_data and water==b.build_swamp_water(expected,16),"Full terrain/normals/control/water equality: pure or partial Forest infection, zero/default/maximum strength")
			# Shared signed lattice vertices across neighbouring chunks and LODs.
			actual.chunk_size=256;var cell:=Vector2i(floori(node.x/256),floori(node.y/256));var left:Array=actual.build(cell,16);var right:Array=actual.build(cell+Vector2i.RIGHT,16)
			for z in range(17):
				check(left[Mesh.ARRAY_VERTEX][z*17+16].y==right[Mesh.ARRAY_VERTEX][z*17].y,"Exact neighbouring fibre terrain height")
				check(left[Mesh.ARRAY_NORMAL][z*17+16].is_equal_approx(right[Mesh.ARRAY_NORMAL][z*17]),"Matching neighbouring fibre normals")
			actual.chunk_size=512;var parent_cell:=Vector2i(floori(node.x/512),floori(node.y/512));var parent:Array=actual.build(parent_cell,16);actual.chunk_size=256;var child:Array=actual.build(parent_cell*2,16)
			for z in range(9):
				for x in range(9):check(parent[Mesh.ARRAY_VERTEX][z*17+x].y==child[Mesh.ARRAY_VERTEX][z*34+x*2].y,"Exact common fibre LOD vertices")
			var used=actual._extras[7];used.configure(actual.settings.alien_infected,seed_id+1,actual,7)
			check(used._last_frame.is_empty() and used._last_frame_point==Vector2.INF and not used._want_frame,"Reconfiguration clears private fibre projection frame")
			var fresh=field_builder(seed_id+1,extent,24)
			for p:Vector2 in probes.slice(0,30):check(used.sample(p.x,p.y)==fresh._extras[7].sample(p.x,p.y),"Used sampler reconfiguration equals fresh seed")
			records.append({"seed":seed_id,"scale":extent,"probes":probes.size(),"full_array_comparisons":12,"adjacent_and_lod":true})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_production_nerve_fibres.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"source_sha256":hashes,"scope":"Production vs preserved fibre trial, exact frozen zero field, pure and partial Forest infection, zero/default/maximum strength, signed adjacent/LOD vertices, reverse query order and used-sampler reconfiguration. Does not certify native collision/walks, visual quality, full-surface completion or performance."},"  "))
	print("PRODUCTION_NERVE_FIBRES ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
