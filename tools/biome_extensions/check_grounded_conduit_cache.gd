extends SceneTree
const References=preload("res://tools/biome_extensions/grounded_conduit_references.gd")
const Base=preload("res://scripts/biome_extension_structures.gd")
const LOD=preload("res://scripts/lod_biome_extension_structures.gd")
var checks:int=0
func verify(ok:bool,label:String)->void:checks+=1;assert(ok,label)
func packed(generator)->Array:return [generator.vertices,generator.normals,generator.colors,generator.uvs]
func builder(seed_id:int,enabled:bool):
	var result=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(seed_id,true);result.settings.alien_infected.hive_grounded_shoulders=enabled;return result
func _initialize()->void:
	var before:GDScript=References.before();var accepted:GDScript=References.accepted();var records:Array=[]
	# Same worker signature and primitive inputs,only the independent emitter
	# switch changes. Both actual cache classes must isolate false/true entries
	# AND copy the switch into the real cold-cache child emitter.
	for use_lod:bool in [false,true]:
		var flat=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();flat.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);flat.settings.alien_infected_coverage=100;flat._configure_noise();var previous_hits:int=0
		for enabled:bool in [false,true,false,true]:
			var actual=LOD.new() if use_lod else Base.new();actual.conduit_grounded_shoulders=enabled;actual.origin=Vector3(-65536,0,131072);actual._support_steps=Base.support_grids();actual._protected_sites=[{"position":Vector2(-64512,132500),"half":96.0}];actual._prepare_conduit_memo(flat)
			var reference=accepted.new() if enabled else before.new();reference.origin=actual.origin;reference._support_steps=actual._support_steps;reference._protected_sites=actual._protected_sites.duplicate(true)
			for generator in [actual,reference]:generator.conduit(flat,Vector2(-65536,131072),Vector2(-63488,132096),28,1.7,Color(.34,.28,.26))
			verify(packed(actual)==packed(reference),"Actual cached cold/hit emitter equals complete frozen off/on reference")
			var memo:Dictionary=flat.get_meta(Base.CONDUIT_MEMO_KEY);verify(memo.bytes<=8*1024*1024 and memo.entries.size()<=32,"Original bounded worker cache unchanged")
			if records.size()%4>=2:verify(memo.hits>previous_hits,"Repeated same-mode primitive uses its own correct cached entry")
			previous_hits=memo.hits;records.append({"lod_class":use_lod,"emitter_flag":enabled,"hits":memo.hits,"misses":memo.misses,"entries":memo.entries.size(),"bytes":memo.bytes})
	# Actual settings-driven whole-root construction on one builder. No oracle
	# is allowed to clear the tested worker's memo while preparing expectations.
	var b=builder(73921,true);b.chunk_size=256;var coordinate:=Vector2i(314,-487);var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();mesher.build(b,coordinate);var grids:PackedFloat64Array=Base.support_grids(256,128,16,4)
	var original_true:Array=[];var true_signature:PackedByteArray
	for phase in range(3):
		var enabled:bool=phase!=1;b.settings.alien_infected.hive_grounded_shoulders=enabled;var actual:Array=LOD.new().build(b,coordinate,grids,mesher.portal_sites);verify(actual[2]!=null,"Original actual native-owned root still present")
		var oracle=builder(73921,enabled);oracle.chunk_size=256;var feature=preload("res://scripts/terrain_feature_meshes.gd").new();feature.build(oracle,coordinate);var reference=accepted.new() if enabled else before.new();var expected:Array=reference.build(oracle,coordinate,grids,feature.portal_sites)
		verify(actual==expected,"Settings true/false/true builds match complete immutable references")
		var memo:Dictionary=b.get_meta(Base.CONDUIT_MEMO_KEY);verify(memo.bytes<=8*1024*1024 and memo.entries.size()<=32,"Whole-root memo keeps original limits")
		if phase==0:original_true=actual;true_signature=memo.signature.duplicate()
		elif phase==1:verify(memo.signature!=true_signature,"Resource switch invalidates whole-worker configuration signature");verify(actual!=original_true,"Actual setting changes genuine geometry,not only a cache label")
		else:verify(memo.signature==true_signature and actual==original_true,"Restored setting restores original signature and every geometry byte")
		var repeated:Array=LOD.new().build(b,coordinate,grids,mesher.portal_sites);verify(repeated==actual,"Cache hit after each setting switch cannot change arrays")
		b.settings.alien_infected.conduit_cache_mib=0;LOD.new().build(b,coordinate+Vector2i.RIGHT,grids,mesher.portal_sites);verify(not b.has_meta(Base.CONDUIT_MEMO_KEY),"Zero budget releases cache even on an empty leaf");b.settings.alien_infected.conduit_cache_mib=8
	var guards:Dictionary={}
	for path:String in [References.BEFORE_BASE,References.BEFORE_LOD,References.ACCEPTED,"res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/grounded_conduit_references.gd","res://tools/biome_extensions/check_grounded_conduit_cache.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd","res://tools/biome_extensions/flat_conduit_builder.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_grounded_conduit_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"checks":checks,"source_sha256":guards,"primitive_records":records,"settings_root":[314,-487,0],"scope":"REGISTERED independent emitter/settings cache lifecycle. Both base and actual LOD cache cold/hit paths must copy and distinguish false/true controls under SAME worker signature,with complete immutable off/on-reference arrays. Actual original native-owned root tests settings true/false/true on one worker,signature invalidation/restoration,complete oracle arrays,repeated hits and immediate zero-budget release. Original8MiB/32-entry cap unchanged. Not streaming/GPU/collision/art acceptance."},"  "));print("GROUNDED_CONDUIT_CACHE ",checks);quit()
