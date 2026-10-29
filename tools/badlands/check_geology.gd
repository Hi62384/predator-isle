extends SceneTree
## Focused regressions for canonical beds, cache ownership and drainage detail.
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func make_builder(seed_id:int):
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new()
	builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=seed_id
	builder.settings.beaches_enabled=false;builder.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:builder.settings.set(biome+"_coverage",0)
	builder.settings.badlands_coverage=100;builder._configure_noise();return builder
func _initialize()->void:
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var builder=make_builder(seed_id)
		var field=builder._badlands
		for i in range(120):
			var p:=Vector2(i*7919%180000-90000,i*11939%180000-90000)
			var h:float=field.sample(p.x,p.y,true)
			var state:PackedFloat64Array=field.state.duplicate()
			check(field.sample(p.x,p.y,false)==h,"Height-only path equals full publication")
			check(field.state==state,"Height-only probes preserve published state")
			var layer:Vector2=field.strata(p,h)
			check(layer.x>=0 and layer.x<5 and layer.y>=0 and layer.y<=1,"Bounded variable-thickness geology")
			var a:float=field.geological_coordinate(p,h)
			check(field.geological_coordinate(p,h+.1)>a,"Beds remain vertically ordered")
			check(absf(field.geological_coordinate(p+Vector2(.001,0),h)-a)<.0001,"Continuous dip/fold field")
		# Exact-node publication must not hand callers the mutable cached array.
		var h:float=field.sample(320,640)
		field.state[0]+=999;field.state[1]+=999
		check(field.sample(320,640)==h,"Published array cannot corrupt canonical cache")
		# Compare the optimized patch with an independent direct 4x4 stencil.
		for i in range(200):
			var p:=Vector2(i*713%20000-10000+.375,i*179%20000-10000+.625)
			var q:Vector2=p/field.STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
			var rows:=PackedFloat64Array();var water_rows:=PackedFloat64Array()
			for row in range(-1,3):
				var a:PackedFloat64Array=field._node(cell+Vector2i(-1,row));var b:PackedFloat64Array=field._node(cell+Vector2i(0,row))
				var c:PackedFloat64Array=field._node(cell+Vector2i(1,row));var d:PackedFloat64Array=field._node(cell+Vector2i(2,row))
				rows.append(field.cubic(a[0],b[0],c[0],d[0],f.x));water_rows.append(field.cubic(a[1],b[1],c[1],d[1],f.x))
			var expected:float=field.cubic(rows[0],rows[1],rows[2],rows[3],f.y)
			check(field.sample(p.x,p.y)==field.remnant_surface(p,expected,false),"Cached polynomial and analytic remnant composition match direct stencil")
			check(field.state[1]==field.cubic(water_rows[0],water_rows[1],water_rows[2],water_rows[3],f.y),"Cached water polynomial matches direct stencil")
		check(field._patches.size()<=1024,"Interpolation cache stays bounded")
		# Measure the actual bed thicknesses, rather than asserting a name.
		var widths:Array=[];var run:int=0;var inside:bool=false
		for i in range(12000):
			var hard:bool=field.strata(Vector2(320,640),i*.1).y>.5
			if hard:run+=1
			if inside and not hard:widths.append(run*.1);run=0
			inside=hard
		check(widths.size()>=4,"Several exposed hard beds over a vertical section")
		var shortest:float=INF;var longest:float=0
		for width:float in widths:shortest=minf(shortest,width);longest=maxf(longest,width)
		check(longest>shortest*1.4,"Hard beds have genuinely unequal thickness")
		var tree:Dictionary=field._tree(1,0,1);var fine_count:int=0
		for edge:Array in tree.edges:
			if edge[2]==4:fine_count+=1
		check(fine_count>0,"Fine source channels are part of the drainage graph")
		cases.append({"seed":seed_id,"hard_bed_widths_m":widths,"finest_connected_sources":fine_count})
		# A FIFO eviction removes only the oldest entry, not every recent node.
		field._nodes.clear();field._node_ring.clear();field._node_cursor=0
		for i in range(16384):
			var key:=Vector2i(100000+i,100000)
			field._nodes[key]=PackedFloat64Array([i]);field._node_ring.append(key)
		field._node(Vector2i(20,40))
		check(field._nodes.size()==16384,"Node cache remains bounded during eviction")
		check(not field._nodes.has(Vector2i(100000,100000)),"Oldest node evicted")
		check(field._nodes.has(Vector2i(116383,100000)),"Recent nodes survive eviction")
		check(field.sample(320,640)==h,"Eviction preserves the canonical height")
		field._nodes.clear();field._node_ring.clear();field._node_cursor=0
		field._patches.clear();field._patch_ring.clear();field._patch_cursor=0
		var expected_fractional:float=field.sample(320.375,640.625)
		for i in range(1025):field._patch(Vector2i(i*3,-20))
		check(field._patches.size()==1024,"Interpolation cache eviction cap")
		check(field.sample(320.375,640.625)==expected_fractional,"Evicted patch regenerates the same exact height")
		var config:Resource=field.settings
		config.fold_strength=0;config.strata_dip=Vector2.ZERO;config.thickness_variation=0
		var expected_bed:float=280.0/(config.strata_metres*.35)
		check(field.geological_coordinate(Vector2(0,0),280)==expected_bed and field.geological_coordinate(Vector2(-500000,400000),280)==expected_bed,"Zero dip/fold controls produce horizontal beds")
		config.strata_dip=Vector2(.03,-.02)
		check(absf(field.geological_coordinate(Vector2(100,200),280)-(280-1)/(config.strata_metres*.35))<.000001,"Configured dip controls actual geological coordinate")
		var uniforms:Dictionary=config.uniforms()
		check(uniforms.badlands_strata_dip==config.strata_dip and uniforms.badlands_fold_strength==0 and uniforms.badlands_thickness_variation==0,"Inspector controls reach production shader bindings")
	var result:Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"cases":cases,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"scope":"Numeric geology/cache/drainage regressions, not visual sign-off or runtime frame-time certification"}
	FileAccess.open("res://tools/badlands/artifacts/check_geology.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("BADLANDS_GEOLOGY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
