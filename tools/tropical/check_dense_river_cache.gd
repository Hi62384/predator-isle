extends SceneTree
var checks:int=0
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func digest(b,arrays:Array,resolution:int)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(arrays));h.update(var_to_bytes(b.build_swamp_water(arrays,resolution)))
	if not b.built_extension_data.is_empty():h.update(b.built_extension_data)
	return h.finish().hex_encode()
func builder(seed_id:int,enabled:bool):
	var b=preload("res://tools/tropical/check_river_detail.gd").create(seed_id);b.settings.tropical.dense_river_node_cache=enabled
	var counter=preload("res://tools/tropical/river_cache_counter.gd").new();counter.configure(b.settings.tropical,seed_id,b);b._tropical=counter;return b
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(FileAccess.get_file_as_string("res://scripts/tropical_sampler.gd").contains("func set_node_capacity("),"Rejected cache trial is archived; restore its frozen sources before replay, not production")
	var records:Array=[];var total_old:int=0;var total_new:int=0
	var sites=JSON.parse_string(FileAccess.get_file_as_string("res://tools/tropical/artifacts/check_river_detail.json"));assert(sites.passed)
	for seed_id:int in [73921,17,92881]:
		var site:Dictionary={}
		for item:Dictionary in sites.cases:
			if int(item.seed)==seed_id:site=item;break
		var components:PackedStringArray=String(site.cell).trim_prefix("(").trim_suffix(")").split(",")
		var cell:=Vector2i(floori(int(components[0])/2.0),floori(int(components[1])/2.0))
		var a=builder(seed_id,false);var b=builder(seed_id,true);a.chunk_size=4096;b.chunk_size=4096
		var started:int=Time.get_ticks_usec();var original:Array=a.build(cell,128);var original_ms:float=(Time.get_ticks_usec()-started)/1000.0;var old_raw:int=a._tropical.raw_evaluations
		started=Time.get_ticks_usec();var current:Array=b.build(cell,128);var current_ms:float=(Time.get_ticks_usec()-started)/1000.0;var new_raw:int=b._tropical.raw_evaluations
		verify(digest(a,original,128)==digest(b,current,128),"Complete terrain/water/payload arrays unchanged")
		verify(a._tropical._node_capacity==16384 and b._tropical._node_capacity==32768,"Independent policy control")
		verify(a._tropical._nodes.size()<=16384 and b._tropical._nodes.size()<=32768,"Numeric memo bounds")
		print("DENSE_RIVER_CACHE_COUNTS seed=",seed_id," raw=",old_raw,"/",new_raw," retained=",a._tropical._nodes.size(),"/",b._tropical._nodes.size())
		verify(new_raw<old_raw,"Fewer actual canonical raw evaluations in declared dense workload")
		total_old+=old_raw;total_new+=new_raw
		var bytes:int=var_to_bytes(b._tropical._nodes).size();var retained:int=b._tropical._nodes.size()
		b.chunk_size=256;var fine:Array=b.build(Vector2i(cell.x*16,cell.y*16),16)
		verify(b._tropical._node_capacity==16384 and b._tropical._nodes.size()<=16384,"Immediate shrink on fine re-use")
		a.chunk_size=256;verify(digest(a,a.build(Vector2i(cell.x*16,cell.y*16),16),16)==digest(b,fine,16),"Complete subsequent fine output unchanged")
		b._tropical.set_node_capacity(32768)
		for i in range(17000):b._tropical._nodes[Vector2i(i,-i)]=PackedFloat64Array([float(i)])
		b._tropical.set_node_capacity(16384);verify(b._tropical._nodes.is_empty(),"Retained oversize clears immediately")
		b._tropical.set_node_capacity(32768);b._tropical.configure(b.settings.tropical,seed_id,b);verify(b._tropical._node_capacity==16384 and b._tropical._nodes.is_empty(),"Reconfiguration resets original bound")
		records.append({"seed":seed_id,"cell":cell,"original_raw_evaluations":old_raw,"current_raw_evaluations":new_raw,"original_ms_ordered":original_ms,"current_ms_ordered":current_ms,"retained_entries":retained,"serialized_numeric_bytes":bytes})
	# Non-admitted dimensions, disabled water and independent feature zero.
	for size:int in [256,2048,4096,8192]:
		for resolution:int in [8,16]:
			var b=builder(73921,true);b.chunk_size=size;b.build(Vector2i.ZERO,resolution);verify(b._tropical._node_capacity==16384,"Unrelated grid retains original budget")
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"assertions":checks,"cases":records,"total_original_raw_evaluations":total_old,"total_current_raw_evaluations":total_new,"source_sha256":{},"production_default_enabled":false,"scope":"REJECTED opt-in32768-node memo: complete outputs/lifecycle checked, but fewer raw evaluations are required before adoption. Cold dense terrain already reuses its captured normal heights, so retaining more sampler nodes does not necessarily save work. Ordered times are not isolated; serialized bytes are not heap/RSS. No gain claimed."}
	for path:String in ["res://scripts/tropical_settings.gd","res://scripts/tropical_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://tools/tropical/check_dense_river_cache.gd","res://tools/tropical/river_cache_counter.gd","res://tools/tropical/check_river_detail.gd"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/tropical/artifacts/check_dense_river_cache.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open("res://tools/biome_extensions/artifacts/dense_river_cache_trial.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DENSE_RIVER_CACHE_RESULT ",checks," raw=",total_old," -> ",total_new," failures=",failures);quit(0 if failures.is_empty() else 1)
