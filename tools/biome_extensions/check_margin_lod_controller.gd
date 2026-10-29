extends "res://tools/biome_extensions/check_all.gd"
const Controller=preload("res://scripts/lod_biome_extension_structures.gd")
const Prototype=preload("res://tools/biome_extensions/margin_retaining_lod_candidate.gd")
func attributes(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func clear_geometry(g)->void:
	g.vertices=PackedVector3Array();g.normals=PackedVector3Array();g.colors=PackedColorArray();g.uvs=PackedVector2Array()
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/forest_sampler.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/check_margin_lod_controller.gd","res://tools/biome_extensions/margin_retaining_lod_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	check(FileAccess.get_file_as_string("res://scripts/chunk_terrain.gd").contains('preload("res://scripts/lod_biome_extension_structures.gd").new().build'),"Actual worker dispatch uses this controller")
	var cases:Array=[];var reduced:int=0
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			for mode:String in ["mixed","coastal","alternate_noise"]:
				var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value
				if mode=="mixed":b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50
				if mode=="coastal":b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true
				b._configure_noise()
				if mode=="alternate_noise":b._extras[7]._macro.noise_type=FastNoiseLite.TYPE_PERLIN
				var field=b._extras[7];var a:Vector2=field.hive_node(Vector2i(-113,-103));var end:Vector2=field.hive_node(Vector2i(-112,-103));var width:float=24*scale_value
				var g=Controller.new();g.origin=Vector3(floorf(a.x/256)*256,0,floorf(a.y/256)*256);g._support_steps=Structures.support_grids();g._prepare_conduit_memo(b)
				for span:int in [256,8192,16384,256]:
					var owner:=Vector2i(floori(a.x/span),floori(a.y/span));var context:Dictionary={"bounds":Rect2(Vector2(owner)*span,Vector2.ONE*span),"ratio":.5,"floor":INF,"enabled":true}
					b.set_meta(g.CONTEXT,context);var expected=Prototype.new();expected.origin=g.origin;expected._support_steps=g._support_steps;expected.conduit(b,a,end,width,.47,Color(.34,.28,.26))
					clear_geometry(g);g.conduit(b,a,end,width,.47,Color(.34,.28,.26));check(attributes(g)==attributes(expected),"Complete cold registered mixed/coastal/noise LOD equals independent primitive prototype")
					var memo:Dictionary=b.get_meta(g.CONDUIT_MEMO_KEY);var old_hits:int=memo.hits
					clear_geometry(g);g.conduit(b,a,end,width,.47,Color(.34,.28,.26));check(attributes(g)==attributes(expected),"Complete warm detail-qualified registered arrays remain exact")
					check(memo.hits==old_hits+1,"Actual bounded mesh memo hit, not a bypass")
					check(memo.bytes<=8*1024*1024 and memo.entries.size()<=32,"Existing 8MiB/32-entry numerical bound retained")
					check(g._foundation_floor==INF and g._row_stride==1,"No retained-margin footer/detail state leaks into later landmarks")
					var detail:int=g.select_stride(a,end,width,context)
					if detail>1:reduced+=1
					cases.append({"seed":seed_id,"scale":scale_value,"mode":mode,"span_m":span,"detail":detail,"vertices":g.vertices.size(),"memo_bytes":memo.bytes,"memo_entries":memo.entries.size()})
				b.settings.alien_infected.hive_structure_lod_enabled=false;g._prepare_conduit_memo(b);clear_geometry(g)
				var owner:=Vector2i(floori(a.x/16384),floori(a.y/16384));b.set_meta(g.CONTEXT,{"bounds":Rect2(Vector2(owner)*16384,Vector2.ONE*16384),"ratio":.5,"floor":INF,"enabled":false});g.conduit(b,a,end,width,.47,Color(.34,.28,.26))
				var original=Structures.new();original.origin=g.origin;original._support_steps=g._support_steps;original.conduit(b,a,end,width,.47,Color(.34,.28,.26))
				check(attributes(g)==attributes(original),"Independent public disabled flag restores COMPLETE original unsupported-host arrays")
				b.settings.alien_infected.conduit_cache_mib=0;g._prepare_conduit_memo(b);check(not b.has_meta(g.CONDUIT_MEMO_KEY),"Zero mesh-cache budget immediately reclaims the bounded worker memo")
				b.remove_meta(g.CONTEXT)
	check(cases.size()==108 and reduced>0,"All declared cached near/medium/far/near host/seed/scale contexts")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable registered margin LOD source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_margin_lod_controller.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":true,"scope":"Registered numerical controller against the separately tested private retained-margin prototype: complete cold/warm arrays across three seeds/scales/unsupported hosts and near/medium/far/near contexts, real bounded memo hits, complete disabled arrays, immediate zero-budget reclaim and no footer/detail state leakage. Actual worker dispatch binding checked. Whole-node ownership, native mixed/coastal views/streaming and broad performance acceptance remain separate."},"  "))
	print("MARGIN_LOD_CONTROLLER ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
