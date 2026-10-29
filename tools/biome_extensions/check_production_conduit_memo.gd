extends "res://tools/biome_extensions/check_integration.gd"
const Candidate=preload("res://scripts/biome_extension_structures.gd")
const Golden=preload("res://tools/biome_extensions/reference_uncached_current_structures.gd")
func artificial_sites(_bounds:Rect2,sites:Array)->Array:return sites
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/terrain_feature_meshes.gd","res://tools/biome_extensions/check_integration.gd","res://tools/biome_extensions/check_production_conduit_memo.gd"]:hashes[path]=FileAccess.get_sha256(path)
	hashes["res://scripts/biome_extension_settings.gd"]=FileAccess.get_sha256("res://scripts/biome_extension_settings.gd")
	hashes["res://tools/biome_extensions/reference_uncached_current_structures.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/reference_uncached_current_structures.gd")
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	var records:Array=[]
	hashes["res://tools/biome_extensions/flat_conduit_builder.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/flat_conduit_builder.gd")
	var admission_path:String="res://tools/biome_extensions/artifacts/check_carapace_admission.json";hashes[admission_path]=FileAccess.get_sha256(admission_path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));check(admission.passed,"Real default-admitted geographic fixtures")
	for item:Dictionary in admission.cases:
		if int(item.habit)!=2:continue
		var seed_id:int=item.seed;var b=make_builder(7,seed_id);var p:=Vector2(item.position[0],item.position[1]);var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
		b.chunk_size=256;var root_cell:=Vector2i(floori(p.x/256),floori(p.y/256));var empty_cell:Vector2i=root_cell+Vector2i.RIGHT
		check(Candidate.new().build(b,empty_cell,PackedFloat64Array(),guard.portal_sites)==Golden.new().build(b,empty_cell,PackedFloat64Array(),guard.portal_sites) and not b.has_meta(Structures.CONDUIT_MEMO_KEY),"Empty Alien leaf neither allocates nor validates a geometry memo")
		Candidate.new().build(b,root_cell,PackedFloat64Array(),guard.portal_sites);var validated:int=b.get_meta(Structures.CONDUIT_MEMO_KEY).validations
		Candidate.new().build(b,empty_cell,PackedFloat64Array(),guard.portal_sites)
		check(int(b.get_meta(Structures.CONDUIT_MEMO_KEY).validations)==validated,"Existing memo is not re-fingerprinted by empty leaves")
		b.settings.alien_infected.conduit_cache_mib=0;Candidate.new().build(b,empty_cell,PackedFloat64Array(),guard.portal_sites)
		check(not b.has_meta(Structures.CONDUIT_MEMO_KEY),"Zero budget also releases a memo on an empty leaf")
		b.settings.alien_infected.conduit_cache_mib=8
		for variant in range(2):
			var grids:PackedFloat64Array=Structures.support_grids() if variant==0 else Structures.support_grids(128,96,20,7)
			for span:float in [4096,2048,256,8192,256]:
				b.chunk_size=span;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var reference:Array=Golden.new().build(b,cell,grids,guard.portal_sites)
				var candidate=Candidate.new();var actual:Array=candidate.build(b,cell,grids,guard.portal_sites)
				check(actual==reference,"Exact complete structure arrays across signed LOD origins and support grids")
				check(candidate.build(b,cell,grids,guard.portal_sites)==reference,"Cache reuse cannot mutate stored arrays")
				var memo:Dictionary=b.get_meta(Structures.CONDUIT_MEMO_KEY);check(memo.bytes<=8*1024*1024 and memo.entries.size()<=32,"Explicit worker cache bounds")
			var memo:Dictionary=b.get_meta(Structures.CONDUIT_MEMO_KEY);check(memo.hits>0,"Actual LOD/repeated-primitive reuse exercised")
			var sites:Array=[{"position":p+Vector2(300,10),"half":96.0},{"position":p+Vector2(100000,100000),"half":96.0}]
			var provider:Callable=artificial_sites.bind(sites);var cell:=Vector2i(floori(p.x/b.chunk_size),floori(p.y/b.chunk_size))
			check(Candidate.new().build(b,cell,grids,provider)==Golden.new().build(b,cell,grids,provider),"Changed protected approaches and irrelevant distant sites preserve every array")
			# Same worker object after actual used-sampler reconfiguration.
			b.settings.alien_infected.nerve_height+=7;b._configure_noise()
			check(Candidate.new().build(b,cell,grids,provider)==Golden.new().build(b,cell,grids,provider),"Changed settings invalidate the memo")
			var limited=Candidate.new();b.settings.alien_infected.conduit_cache_mib=1
			check(limited.build(b,cell,grids,provider)==Golden.new().build(b,cell,grids,provider),"Eviction/bypass preserves geometry")
			memo=b.get_meta(Structures.CONDUIT_MEMO_KEY);check(memo.bytes<=1024*1024 and memo.entries.size()<=32,"Eviction/bypass retains strict limits")
			records.append({"seed":seed_id,"variant":variant,"memo_hits":memo.hits,"memo_misses":memo.misses,"memo_bytes":memo.bytes,"memo_entries":memo.entries.size()})
		b.chunk_size=256;var mixed_cell:=Vector2i(floori(p.x/256),floori(p.y/256));b.settings.alien_infected.conduit_cache_mib=8
		b.settings.alien_infected_coverage=0;b.settings.forest_coverage=100;b.settings.alien_infected.overlay_strength=.8;b._configure_noise();b._get_height(p.x,p.y)
		check(b._last_extras[7].x>.5 and b._last_extras[7].x<.92,"Actual partial infection over a Forest owner")
		check(Candidate.new().build(b,mixed_cell,PackedFloat64Array(),guard.portal_sites)==Golden.new().build(b,mixed_cell,PackedFloat64Array(),guard.portal_sites),"Mixed-owner/partial-overlay structure arrays unchanged")
		b.settings.alien_infected.conduit_cache_mib=0
		check(Candidate.new().build(b,mixed_cell,PackedFloat64Array(),guard.portal_sites)==Golden.new().build(b,mixed_cell,PackedFloat64Array(),guard.portal_sites),"Zero cache budget retains exact original geometry")
		check(not b.has_meta(Structures.CONDUIT_MEMO_KEY),"Zero cache budget releases all cached data")
		b.settings.alien_infected.conduit_cache_mib=8
		var bypass=Candidate.new();bypass.conduit_cache_enabled=false
		check(bypass.build(b,mixed_cell,PackedFloat64Array(),guard.portal_sites)==Golden.new().build(b,mixed_cell,PackedFloat64Array(),guard.portal_sites) and not b.has_meta(Structures.CONDUIT_MEMO_KEY),"Reference switch also bypasses and releases cache")
	# Independently exercise the conservative protected-site filter near its
	# bound, including original reference switches and signed world origins.
	var flat=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();flat.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);flat.settings.alien_infected_coverage=100;flat._configure_noise()
	var a:=Vector2(-65536,131072);var end:Vector2=a+Vector2(2048,1024);var side:Vector2=Vector2(-(end-a).y,(end-a).x).normalized()
	for width:float in [8,20,40]:
		for reference_mode:int in range(3):
			for offset:float in [-width*2,0,32]:
				var site:Dictionary={"position":(a+end)*.5+side*(320+208+5.8*width+offset),"half":96.0}
				var original=Golden.new();var cached=Candidate.new();cached._prepare_conduit_memo(flat)
				for g in [original,cached]:
					g.origin=Vector3(-65536,0,131072);g._support_steps=Structures.support_grids();g._protected_sites=[site,{"position":a+Vector2(100000,100000),"half":96.0}];g.conduit_aprons=reference_mode!=1;g.conduit_shoulders=reference_mode!=2
					g.conduit(flat,a,end,width,.47,Color(.34,.28,.26))
				check([cached.vertices,cached.normals,cached.colors,cached.uvs]==[original.vertices,original.normals,original.colors,original.uvs],"Conservative protected boundary and reference switches retain exact primitive arrays")
	flat.settings.alien_infected.conduit_cache_mib=1
	var bounded=Candidate.new();bounded.origin=Vector3(a.x,0,a.y);bounded._support_steps=Structures.support_grids();bounded._prepare_conduit_memo(flat)
	for i in range(40):
		var original=Golden.new();original.origin=bounded.origin;original._support_steps=bounded._support_steps
		var first:int=bounded.vertices.size();bounded.conduit(flat,a,end,20,i*.37,Color(.34,.28,.26));original.conduit(flat,a,end,20,i*.37,Color(.34,.28,.26))
		check([bounded.vertices.slice(first),bounded.normals.slice(first),bounded.colors.slice(first),bounded.uvs.slice(first)]==[original.vertices,original.normals,original.colors,original.uvs],"FIFO eviction preserves every primitive array")
		var memo:Dictionary=flat.get_meta(Structures.CONDUIT_MEMO_KEY);check(memo.bytes<=1024*1024 and memo.entries.size()<=32,"Every insertion respects numeric-data/entry bounds")
	var evicted:Dictionary=flat.get_meta(Structures.CONDUIT_MEMO_KEY);check(evicted.entries.size()<40 and evicted.misses>=40,"Actual bounded eviction exercised")
	for family_id:int in [0,5,6]:
		var other=make_builder(family_id);other.chunk_size=4096
		check(Candidate.new().build(other,Vector2i.ZERO)==Golden.new().build(other,Vector2i.ZERO) and not other.has_meta(Structures.CONDUIT_MEMO_KEY),"Other families keep exact arrays without allocating the Alien memo")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable experiment source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_production_conduit_memo.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"experimental_only":false,"production_change_kept":true,"records":records,"source_sha256":hashes,"scope":"Production worker-owned conduit geometry memo, exact full-array comparisons across real signed LOD origins/default/custom support grids, repeated reuse, changed settings/protected sites and strict eviction/bypass bounds. Compares CURRENT uncached morphology with production caching,not a frozen historical morphology golden. Performance/streaming/collision are separate."},"  "))
	print("PRODUCTION_CONDUIT_MEMO ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
