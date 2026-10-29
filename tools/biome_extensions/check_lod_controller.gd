extends "res://tools/biome_extensions/check_all.gd"
const Controller=preload("res://scripts/lod_biome_extension_structures.gd")
const Prototype=preload("res://tools/biome_extensions/far_conduit_lod_candidate.gd")
func attributes(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func clear_mesh(g)->void:
	g.vertices=PackedVector3Array();g.normals=PackedVector3Array();g.colors=PackedColorArray();g.uvs=PackedVector2Array()
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	hashes["res://scripts/chunk_terrain.gd"]=FileAccess.get_sha256("res://scripts/chunk_terrain.gd")
	check(FileAccess.get_file_as_string("res://scripts/chunk_terrain.gd").contains('preload("res://scripts/lod_biome_extension_structures.gd").new().build'),"Production worker registers this controller")
	for source:String in ["res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/far_conduit_lod_candidate.gd","res://tools/biome_extensions/check_lod_controller.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value;b._configure_noise();var field=b._extras[7];var a:Vector2=field.hive_node(Vector2i(-113,-103));var end:Vector2=field.hive_node(Vector2i(-112,-103))
			var g=Controller.new();g.origin=Vector3(floorf(a.x/256)*256,0,floorf(a.y/256)*256);g._support_steps=Structures.support_grids();g._prepare_conduit_memo(b)
			var profiles:Dictionary={}
			for span:int in [256,8192,16384,256]:
				var owner:=Vector2i(floori(a.x/span),floori(a.y/span));var context:Dictionary={"bounds":Rect2(Vector2(owner)*span,Vector2.ONE*span),"ratio":.5,"floor":g.global_floor(b)}
				b.set_meta(g.CONTEXT,context);b.set_meta(Prototype.CONTEXT,context)
				var trial=Prototype.new();trial.origin=g.origin;trial._support_steps=g._support_steps;trial.conduit(b,a,end,24,.47,Color(.34,.28,.26));var expected:Array=attributes(trial)
				clear_mesh(g);g.conduit(b,a,end,24,.47,Color(.34,.28,.26));check(attributes(g)==expected,"Complete cold production controller equals the preserved independent prototype")
				var previous_hits:int=b.get_meta(g.CONDUIT_MEMO_KEY).hits
				clear_mesh(g);g.conduit(b,a,end,24,.47,Color(.34,.28,.26));check(attributes(g)==expected,"Complete warm detail-qualified memo arrays remain exact")
				check(b.get_meta(g.CONDUIT_MEMO_KEY).hits==previous_hits+1,"Actual warm hit, not a disabled reuse path")
				var detail:int=g.select_stride(a,end,24,context);profiles[str(detail)]=true
				var memo:Dictionary=b.get_meta(g.CONDUIT_MEMO_KEY);check(memo.bytes<=8*1024*1024 and memo.entries.size()<=32,"Existing byte/entry budget retained across detail switches")
				cases.append({"seed":seed_id,"scale":scale_value,"span":span,"detail":detail,"vertices":g.vertices.size(),"memo_bytes":memo.bytes,"memo_entries":memo.entries.size()})
			b.remove_meta(g.CONTEXT);b.remove_meta(Prototype.CONTEXT)
			check(g._foundation_floor==INF and g._row_stride==1,"No distant-conduit state leaks into later biological landmarks")
			if scale_value==.2:check(profiles.size()>1,"Same conduit switches between near/far keys and back without stale geometry")
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable controller source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_lod_controller.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":true,"scope":"Registered worker controller against the independent private LOD prototype: complete cold/warm vertices/normals/colors/UV arrays across near/medium/far/near contexts, three seeds/scales, real memo hits, same byte/entry bounds and no landmark footing-state leak. Full-node zero mode and native runtime/render/physics remain separate."},"  "))
	print("LOD_CONTROLLER_CHECK ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
