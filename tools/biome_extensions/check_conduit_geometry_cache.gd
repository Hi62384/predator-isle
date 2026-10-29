extends "res://tools/biome_extensions/check_integration.gd"
const Golden=preload("res://tools/biome_extensions/reference_pre_conduit_memo_structures.gd")
const Candidate=preload("res://tools/biome_extensions/conduit_geometry_cache_candidate.gd")
func artificial_sites(_bounds:Rect2,sites:Array)->Array:return sites
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/reference_pre_conduit_memo_structures.gd","res://scripts/biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/terrain_feature_meshes.gd","res://tools/biome_extensions/check_integration.gd","res://tools/biome_extensions/conduit_geometry_cache_candidate.gd","res://tools/biome_extensions/check_conduit_geometry_cache.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[]
	hashes["res://tools/biome_extensions/flat_conduit_builder.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/flat_conduit_builder.gd")
	var admission_path:String="res://tools/biome_extensions/artifacts/check_carapace_admission.json";hashes[admission_path]=FileAccess.get_sha256(admission_path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));check(admission.passed,"Real default-admitted geographic fixtures")
	for item:Dictionary in admission.cases:
		if int(item.habit)!=2:continue
		var seed_id:int=item.seed;var b=make_builder(7,seed_id);var p:=Vector2(item.position[0],item.position[1]);var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
		for variant in range(2):
			var grids:PackedFloat64Array=Structures.support_grids() if variant==0 else Structures.support_grids(128,96,20,7)
			for span:float in [4096,2048,256,8192,256]:
				b.chunk_size=span;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var reference:Array=Golden.new().build(b,cell,grids,guard.portal_sites)
				var candidate=Candidate.new();var actual:Array=candidate.build(b,cell,grids,guard.portal_sites)
				check(actual==reference,"Exact complete structure arrays across signed LOD origins and support grids")
				check(candidate.build(b,cell,grids,guard.portal_sites)==reference,"Cache reuse cannot mutate stored arrays")
				var memo:Dictionary=b.get_meta(Candidate.META_KEY);check(memo.bytes<=candidate.byte_budget and memo.entries.size()<=candidate.entry_budget,"Explicit worker cache bounds")
			var memo:Dictionary=b.get_meta(Candidate.META_KEY);check(memo.hits>0,"Actual LOD/repeated-primitive reuse exercised")
			var sites:Array=[{"position":p+Vector2(300,10),"half":96.0},{"position":p+Vector2(100000,100000),"half":96.0}]
			var provider:Callable=artificial_sites.bind(sites);var cell:=Vector2i(floori(p.x/b.chunk_size),floori(p.y/b.chunk_size))
			check(Candidate.new().build(b,cell,grids,provider)==Golden.new().build(b,cell,grids,provider),"Changed protected approaches and irrelevant distant sites preserve every array")
			# Same worker object after actual used-sampler reconfiguration.
			b.settings.alien_infected.nerve_height+=7;b._configure_noise()
			check(Candidate.new().build(b,cell,grids,provider)==Golden.new().build(b,cell,grids,provider),"Changed settings invalidate the memo")
			var limited=Candidate.new();limited.byte_budget=128*1024;limited.entry_budget=2
			check(limited.build(b,cell,grids,provider)==Golden.new().build(b,cell,grids,provider),"Eviction/bypass preserves geometry")
			memo=b.get_meta(Candidate.META_KEY);check(memo.bytes<=limited.byte_budget and memo.entries.size()<=2,"Eviction/bypass retains strict limits")
			records.append({"seed":seed_id,"variant":variant,"memo_hits":memo.hits,"memo_misses":memo.misses,"memo_bytes":memo.bytes,"memo_entries":memo.entries.size()})
	# Independently exercise the conservative protected-site filter near its
	# bound, including original reference switches and signed world origins.
	var flat=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();flat.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);flat.settings.alien_infected_coverage=100;flat._configure_noise()
	var a:=Vector2(-65536,131072);var end:Vector2=a+Vector2(2048,1024);var side:Vector2=Vector2(-(end-a).y,(end-a).x).normalized()
	for width:float in [8,20,40]:
		for reference_mode:int in range(3):
			for offset:float in [-width*2,0,32]:
				var site:Dictionary={"position":(a+end)*.5+side*(320+208+5.8*width+offset),"half":96.0}
				var original=Golden.new();var cached=Candidate.new()
				for g in [original,cached]:
					g.origin=Vector3(-65536,0,131072);g._support_steps=Structures.support_grids();g._protected_sites=[site,{"position":a+Vector2(100000,100000),"half":96.0}];g.conduit_aprons=reference_mode!=1;g.conduit_shoulders=reference_mode!=2
					g.conduit(flat,a,end,width,.47,Color(.34,.28,.26))
				check([cached.vertices,cached.normals,cached.colors,cached.uvs]==[original.vertices,original.normals,original.colors,original.uvs],"Conservative protected boundary and reference switches retain exact primitive arrays")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable experiment source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_conduit_geometry_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"experimental_only":true,"production_change_kept":false,"records":records,"source_sha256":hashes,"scope":"Experimental worker-owned conduit geometry memo, exact full-array comparisons across real signed LOD origins/default/custom support grids, repeated reuse, changed settings/protected sites and strict eviction/bypass bounds. Production pipeline is not changed. Performance/streaming/collision are separate."},"  "))
	print("CONDUIT_GEOMETRY_CACHE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
