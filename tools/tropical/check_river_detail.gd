extends SceneTree
const Detail=preload("res://scripts/tropical_river_detail.gd")
var checks:int=0
var cases:Array=[]
func verify(ok:bool,label:String)->void:
	assert(ok,label);checks+=1
static func create(seed_id:int):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for owner:String in ["grass","forest","jungle","savanna","swamp","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(owner+"_coverage",0)
	b.settings.tropical_coverage=100;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.island_size=100400;b.settings.island_spacing=585;b._configure_noise();return b
func triangle_value(arrays:Array,resolution:int,local:Vector2,channel:int,span:float=2048)->float:
	var step:float=span/resolution;var grid:Vector2=local/step;var x:int=clampi(floori(grid.x),0,resolution-1);var z:int=clampi(floori(grid.y),0,resolution-1);var f:Vector2=grid-Vector2(x,z);var a:int=z*(resolution+1)+x
	var ids:Array[int];var weights:Vector3
	if f.x+f.y<=1:ids=[a,a+1,a+resolution+1];weights=Vector3(1-f.x-f.y,f.x,f.y)
	else:ids=[a+1,a+resolution+2,a+resolution+1];weights=Vector3(1-f.y,f.x+f.y-1,1-f.x)
	var value:float=0
	for i in range(3):value+=weights[i]*(arrays[Mesh.ARRAY_VERTEX][ids[i]].y if channel==0 else arrays[Mesh.ARRAY_TEX_UV][ids[i]].x)
	return value
func _initialize()->void:call_deferred("run")
func run()->void:
	var old_error:float=0;var new_error:float=0;var old_wet_errors:int=0;var new_wet_errors:int=0;var points:int=0
	var max_normal_difference:float=0
	var old_parent_error:float=0;var new_parent_error:float=0
	for seed_id:int in [73921,17,92881]:
		var b=create(seed_id);var controller=preload("res://scripts/chunk_terrain.gd").new();controller._sampler=b;controller._settings_snapshot=b.settings
		var selected:Array=[];var used:Dictionary={}
		for lane in range(-24,25):
			if b._tropical.random(lane,0,139)>b.settings.tropical.river_frequency:continue
			for i in range(48):
				var x:float=i*4096-98304;var p:=Vector2(x,b._tropical._carrier(x,lane).x)
				var h:float=b._get_height(p.x,p.y);var key:=Vector2i(floori(p.x/2048),floori(p.y/2048))
				if used.has(key) or b._island_mask(p.x,p.y)<.05 or b._last_swamp_water<h+.5:continue
				used[key]=true;selected.append({"p":p,"cell":key,"lane":lane})
				if selected.size()==3:break
			if selected.size()==3:break
		verify(selected.size()==3,"Three actual wet main-river sites per seed")
		for site:Dictionary in selected:
			var key:=Vector3i(site.cell.x,site.cell.y,3);var bounds:=Rect2(Vector2(site.cell)*2048,Vector2.ONE*2048)
			var state:PackedFloat64Array=b._tropical.state.duplicate();verify(Detail.spacing(b,bounds,3)==32,"Actual carrier admits32m detail");verify(state==b._tropical.state,"Planning does not overwrite canonical sample state")
			b.settings.tropical.river_detail_metres=0;controller._tropical_mesh_tiles.clear();var old_resolution:int=controller._tile_resolution(key)
			b.settings.tropical.river_detail_metres=32;controller._tropical_mesh_tiles.clear();var resolution:int=controller._tile_resolution(key)
			verify(resolution==64 and resolution>old_resolution,"Default LOD3 main-river spacing32m")
			verify(controller._tile_resolution(key)==resolution,"Cached policy remains identical")
			for lod:int in [0,1,5,6]:
				var other:=Vector3i(floori(site.p.x/(256*(1<<lod))),floori(site.p.y/(256*(1<<lod))),lod)
				var before:int=controller._tile_resolution(other);b.settings.tropical.river_detail_metres=0;controller._tropical_mesh_tiles.clear();verify(controller._tile_resolution(other)==before,"Near/far untouched outside bounded LOD2/3 policy");b.settings.tropical.river_detail_metres=32;controller._tropical_mesh_tiles.clear()
			b.chunk_size=2048;var begin:int=Time.get_ticks_usec();var original:Array=b.build(site.cell,old_resolution);var old_ms:float=(Time.get_ticks_usec()-begin)/1000.0
			begin=Time.get_ticks_usec();var detailed:Array=b.build(site.cell,resolution);var new_ms:float=(Time.get_ticks_usec()-begin)/1000.0
			var ratio:int=resolution/old_resolution
			var parent:=Vector2i(floori(site.cell.x/2.0),floori(site.cell.y/2.0));var parent_key:=Vector3i(parent.x,parent.y,4)
			var parent_resolution:int=controller._tile_resolution(parent_key);verify(parent_resolution==64,"Default outer LOD4 river corridor uses64m spacing")
			b.chunk_size=4096;var old_parent:Array=b.build(parent,16);var parent_arrays:Array=b.build(parent,parent_resolution);b.chunk_size=2048
			var ox:int=(site.cell.x-parent.x*2)*parent_resolution/2;var oz:int=(site.cell.y-parent.y*2)*parent_resolution/2
			for z in range(0,resolution+1,4):
				for x in range(0,resolution+1,4):
					var child:int=z*(resolution+1)+x;var pi:int=(oz+z/2)*(parent_resolution+1)+ox+x/2
					verify(detailed[Mesh.ARRAY_VERTEX][child].y==parent_arrays[Mesh.ARRAY_VERTEX][pi].y,"LOD3/4 shared canonical height exact")
					verify(detailed[Mesh.ARRAY_TEX_UV][child].x==parent_arrays[Mesh.ARRAY_TEX_UV][pi].x,"LOD3/4 shared water exact")
			for z in range(old_resolution+1):
				for x in range(old_resolution+1):
					var a:int=z*(old_resolution+1)+x;var c:int=z*ratio*(resolution+1)+x*ratio
					verify(original[Mesh.ARRAY_VERTEX][a]==detailed[Mesh.ARRAY_VERTEX][c],"Shared LOD vertex exact")
					# Existing sparse probes retain float64 heights; the dense32m
					# lattice stores float32 first. Both use the same +/-32m stencil,
					# but normals are not bit-exact across that storage transition.
					var difference:float=original[Mesh.ARRAY_NORMAL][a].distance_to(detailed[Mesh.ARRAY_NORMAL][c]);max_normal_difference=maxf(max_normal_difference,difference)
					verify(difference<.00002,"Shared normal float32 probe precision")
					verify(original[Mesh.ARRAY_TEX_UV][a].x==detailed[Mesh.ARRAY_TEX_UV][c].x,"Shared canonical water exact")
			var before_error:float=0;var after_error:float=0;var count:int=0;var old_wet:int=0;var new_wet:int=0
			for xi in range(33):
				var x:float=bounds.position.x+(xi+.25)*bounds.size.x/33;var y:float=b._tropical._carrier(x,site.lane).x
				for offset:float in [-80,-40,-20,0,20,40,80]:
					var p:=Vector2(x,y+offset)
					if not bounds.has_point(p):continue
					var h:float=b._get_height(p.x,p.y);var water:float=b._last_swamp_water;var local:Vector2=p-bounds.position
					var old_h:float=triangle_value(original,old_resolution,local,0);var new_h:float=triangle_value(detailed,resolution,local,0)
					before_error+=absf(h-old_h);after_error+=absf(h-new_h);count+=1
					var parent_local:Vector2=p-Vector2(parent)*4096
					old_parent_error+=absf(h-triangle_value(old_parent,16,parent_local,0,4096));new_parent_error+=absf(h-triangle_value(parent_arrays,parent_resolution,parent_local,0,4096))
					if (triangle_value(original,old_resolution,local,1)>old_h)!=(water>h):old_wet+=1
					if (triangle_value(detailed,resolution,local,1)>new_h)!=(water>h):new_wet+=1
			verify(count>30,"Actual channel/bank probes inside tile")
			old_error+=before_error;new_error+=after_error;old_wet_errors+=old_wet;new_wet_errors+=new_wet;points+=count
			cases.append({"seed":seed_id,"cell":site.cell,"lane":site.lane,"point":site.p,"old_resolution":old_resolution,"new_resolution":resolution,"sample_points":count,"old_mean_vertical_error":before_error/count,"new_mean_vertical_error":after_error/count,"old_water_sign_errors":old_wet,"new_water_sign_errors":new_wet,"cold_original_build_ms":old_ms,"subsequent_detailed_build_ms":new_ms})
			b.chunk_size=256
		# Independent opt-outs and dense custom-settings planning bound.
		var bounds:=Rect2(Vector2.ZERO,Vector2.ONE*2048)
		b.settings.water_enabled=false;verify(Detail.spacing(b,bounds,3)==0,"Water disabled");b.settings.water_enabled=true
		b.settings.tropical.river_frequency=0;verify(Detail.spacing(b,bounds,3)==0,"Rivers disabled");b.settings.tropical.river_frequency=.8
		b.settings.grass_river_frequency=1000;verify(Detail.spacing(b,bounds,3)==32,"Extreme custom density bounded fallback")
		controller.free()
	verify(new_error<old_error*.5,"Declared nine-site aggregate vertical error at least halved")
	verify(new_wet_errors<old_wet_errors,"Declared bank wet/dry interpolation mismatches reduced")
	verify(new_parent_error<old_parent_error*.5,"Lighter outer LOD4 still halves aggregate interpolation error")
	var report:Dictionary={"passed":true,"failures":[],"assertions":checks,"cases":cases,"summary":{"sample_points":points,"old_mean_vertical_error":old_error/points,"new_mean_vertical_error":new_error/points,"old_water_sign_errors":old_wet_errors,"new_water_sign_errors":new_wet_errors,"max_shared_normal_difference":max_normal_difference,"normal_precision_bound":.00002},"source_sha256":{},"scope":"Bounded pure Tropical main-carrier LOD2–4 refinement,128 maximum grid resolution. Exact canonical heights/water,LOD3/4 common vertices and opt-outs; shared sparse/dense normals within the declared float32 probe-storage bound, not bit-exact. Nine wet sites over three seeds. Bank signs compare vertex interpolation, not a full water-fragment raster certificate. Build times are cold-old/subsequent-new, not fair performance comparisons. No universal tributary/distant-river improvement claim."}
	report.summary["old_parent_mean_vertical_error"]=old_parent_error/points;report.summary["new_parent_mean_vertical_error"]=new_parent_error/points
	report["default_spacing_metres"]={"lod2":32,"lod3":32,"lod4":64}
	for path:String in ["res://scripts/tropical_river_detail.gd","res://scripts/tropical_settings.gd","res://scripts/tropical_sampler.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://tools/tropical/check_river_detail.gd"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/tropical/artifacts/check_river_detail.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TROPICAL_RIVER_DETAIL_PASS ",checks," summary=",report.summary);quit()
