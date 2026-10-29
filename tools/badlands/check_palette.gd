extends SceneTree
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func make_builder(mixed:bool):
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.beaches_enabled=false;builder.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:builder.settings.set(biome+"_coverage",0)
	builder.settings.badlands_coverage=50 if mixed else 100
	if mixed:builder.settings.quarry_coverage=50
	builder._configure_noise();return builder
func _initialize()->void:
	var records:Array=[]
	for mixed:bool in [false,true]:
		var builder=make_builder(mixed);var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
		var point:=Vector2(manifest.features.hoodoo_cluster.x,manifest.features.hoodoo_cluster.z)
		if mixed:
			var found:bool=false
			for i in range(1000):
				point=Vector2(i*7919%160000-80000,i*11939%160000-80000);builder._biome_weights(point.x,point.y)
				if builder._badlands_weight>.15 and builder._badlands_weight<.85 and builder._extra_weights[0]>.15 and builder._island_mask(point.x,point.y)>.1:found=true;break
			check(found,"Actual Badlands/Quarry transition located")
		var cell:=Vector2i(floori(point.x/256),floori(point.y/256));var arrays:Array=builder.build(cell,32)
		var bytes:PackedByteArray=builder.built_extension_data;var row:int=33;var slot:int=builder.built_badlands_palette_slot
		check(slot==(8 if mixed else 0),"Shared atlas uses the expected regional palette slot")
		var width:int=bytes.size()/(row*4)
		check(width==row*(9 if mixed else 1),"Only required numeric slots are allocated")
		if slot<0 or bytes.is_empty():continue
		for z in range(row):
			for x in range(row):
				var p:=Vector2(cell.x*256+x*8,cell.y*256+z*8)
				var palette:Vector4=builder._badlands.material_palette(p);var offset:int=(z*width+slot*row+x)*4
				for channel in range(4):check(bytes[offset+channel]==roundi(palette[channel]*255),"Continuous regional weights survive worker transport exactly")
				if mixed:
					builder._get_height(p.x,p.y)
					for family in range(8):
						var e:Vector4=builder._last_extras[family];var expected:=Vector4(e.x,e.z*e.x,e.y*e.x,e.w*e.x)
						var index:int=(z*width+family*row+x)*4
						for channel in range(4):check(bytes[index+channel]==roundi(clampf(expected[channel],0,1)*255),"All existing extension channels retained in expanded atlas")
		# Exercises the shared liquid consumer for one-slot and nine-slot layouts.
		var water:Array=builder.build_swamp_water(arrays,32)
		check(water.is_empty() or water.size()==Mesh.ARRAY_MAX,"Shared liquid builder accepts variable-width atlas")
		records.append({"mixed":mixed,"cell":cell,"slot":slot,"atlas_width":width,"rows":row,"numeric_bytes":bytes.size()})
	var disabled=make_builder(false);disabled.settings.badlands_coverage=0;disabled.settings.grass_coverage=100;disabled._configure_noise();disabled.build(Vector2i.ONE,16)
	check(disabled.built_badlands_palette.is_empty() and disabled.built_extension_data.is_empty(),"Disabled Badlands allocates no numeric atlas")
	var result:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"cases":records,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"builder_sha256":FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd")}
	FileAccess.open("res://tools/badlands/artifacts/check_palette.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_PALETTE ",result);quit(0 if failures.is_empty() else 1)
