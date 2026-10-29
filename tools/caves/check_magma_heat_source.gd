extends "res://tools/biome_extensions/check_all.gd"
const Before=preload("res://tools/caves/references/magma_original_surface_features.gd")
const Current=preload("res://scripts/terrain_feature_meshes.gd")
const Liquid=preload("res://scripts/retained_liquid_geometry.gd")
const Heat=preload("res://scripts/caves/magma_heat.gd")
class SourceSampler extends RefCounted:
	var settings:Resource=preload("res://scripts/biome_extension_settings.gd").new()
	func descriptor(_cell:Vector2i,_span:float)->Dictionary:return {"id":"2:0:0","position":Vector2.ZERO,"radius":100.0,"chance":0.0,"age":.5}
	func region(_point:Vector2)->float:return .5
class Bowl extends RefCounted:
	var water_level:float=0
	var coverage:float=1
	var island:float=1
	var flat:bool=false
	var _extra_weights:=PackedFloat64Array([0,0,1])
	var _extras:Array=[null,null,SourceSampler.new()]
	func _get_height(x:float,z:float,_publish:bool=true)->float:return 20.0 if flat else 20.0+(x*x+z*z)*.05
	func _biome_weights(_x:float,_z:float)->Vector4:_extra_weights[2]=coverage;return Vector4.ZERO
	func _island_mask(_x:float,_z:float)->float:return island
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/references/magma_original_surface_features.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/retained_liquid_geometry.gd","res://scripts/caves/magma_heat.gd","res://scripts/volcanic_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd"]:guards[path]=FileAccess.get_sha256(path)
	check(guards["res://tools/caves/references/magma_original_surface_features.gd"]=="38426a4957853344ed00bfa826c50b285a4728137071859bb227108e57e9a9c2","Full independent original pre-extraction surface mesher bytes pinned")
	var bowl=Bowl.new();var before=Before.new();before.builder=bowl;var current=Current.new();current.builder=bowl;var rows:Array=[]
	for flat:bool in [false,true]:
		bowl.flat=flat;before.reset();current.reset();var old_ok:bool=before.pool(Vector2.ZERO,38,Color(1,.24,.025));var new_ok:bool=current.pool(Vector2.ZERO,38,Color(1,.24,.025));check(old_ok==new_ok and var_to_bytes(before.arrays())==var_to_bytes(current.arrays()),"Complete old/new controlled retained/dry pool mesh arrays exact")
	bowl.flat=false;var heat=Heat.new();heat.configure(bowl);var point:=Vector3(0,-180,0);var positive:Dictionary=heat.sample(point);check(float(positive.heat)>.5 and positive.get("id","")=="2:0:0","Actual retained clipped source admits explicit underground intrusion heat")
	heat.enabled=false;check(heat.sample(point)=={"heat":0.0},"Independent heat off exact cold despite cached positive");heat.enabled=true;check(var_to_bytes(heat.sample(point))==var_to_bytes(positive),"Heat ON/OFF/ON exact source witness return")
	for mode:String in ["flat_bed","owner","island","ocean","inactive","liquids_off"]:
		var candidate=Bowl.new()
		match mode:
			"flat_bed":candidate.flat=true
			"owner":candidate.coverage=.94
			"island":candidate.island=.09
			"ocean":candidate.water_level=100
			"inactive":candidate._extras[2].settings.active_frequency=0.0
			"liquids_off":candidate._extras[2].settings.special_liquids_enabled=false
		var negative=Heat.new();negative.configure(candidate);check(negative.sample(point)=={"heat":0.0},"Eligible source hash alone cannot bypass actual "+mode+" renderer condition,even at depth")
	check(heat.sample(Vector3(200,-399,200))=={"heat":0.0} and heat.sample(Vector3(0,2000,0))=={"heat":0.0},"Outside actual clipped surface footprint and above source stay cold")
	var prior_path:String="res://tools/biome_extensions/artifacts/check_liquids.json";var prior=JSON.parse_string(FileAccess.get_file_as_string(prior_path));check(prior is Dictionary and prior.failures.is_empty() and prior.cases.size()==4,"Original four actual retained surface-liquid fixtures available");guards[prior_path]=FileAccess.get_sha256(prior_path)
	if prior is Dictionary:
		for selection:Dictionary in prior.cases:
			var family:int=int(selection.family);var b=make_builder(family,73921);b.chunk_size=8192;b.settings.get(TerrainSettings.EXTENSION_KEYS[family]).caves_enabled=false;b._configure_noise();var sampler=b._extras[family];var parts:PackedStringArray=str(selection.id).split(":");var cell:=Vector2i(int(parts[1]),int(parts[2]));var descriptor:Dictionary=sampler.descriptor(cell,(7200 if family==2 else 4096)*sampler.settings.feature_scale);var center:Vector2=descriptor.position if family==2 else sampler.hive_node(cell);var radius:float=descriptor.radius*(.85 if sampler.region(center)>1.6 else .38) if family==2 else 300.0
			var old=Before.new();old.builder=b;var production=Current.new();production.builder=b;old.origin=Vector3(floorf(center.x/8192)*8192,0,floorf(center.y/8192)*8192);production.origin=old.origin;old.reset();production.reset();var tint:=Color(1,.24,.025) if family==2 else Color(.18,.42,.27);var old_valid:bool=old.pool(center,radius,tint);var current_valid:bool=production.pool(center,radius,tint);check(old_valid and current_valid and var_to_bytes(old.arrays())==var_to_bytes(production.arrays()),"Complete original actual retained Volcanic/Alien native positions/normals/colors/UV arrays bit-exact")
			var row:Dictionary={"family":family,"id":selection.id,"center":center,"radius":radius,"vertices":production.arrays()[Mesh.ARRAY_VERTEX].size() if current_valid else 0}
			if family==2:
				var context=Heat.new();context.configure(b);var bed:float=b._get_height(center.x,center.y);var source:Dictionary=context.sample(Vector3(center.x,bed-180,center.y));check(source.get("heat",0)>.4 and source.get("id","")==str(selection.id),"Original normally active retained Volcanic source has actual clipped underground witness");b._get_height(-16384,24576);var cold_context=Heat.new();cold_context.configure(b);check(var_to_bytes(cold_context.sample(Vector3(center.x,bed-180,center.y)))==var_to_bytes(source),"Fresh context after unrelated canonical cache/payload query gives exact same source;no stale last payload");row["heat_source"]=source
			rows.append(row)
	var no_volcanic=make_builder(0,73921);var cold=Heat.new();cold.configure(no_volcanic);check(cold.sample(Vector3(0,-399,0))=={"heat":0.0},"No configured canonical Volcanic owner never becomes molten merely because deep")
	check(heat.cache_counts().x<=32 and heat.cache_counts().y<=512,"Source and point caches stay in declared numeric bounds")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable common surface/heat implementation "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_heat_source.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"actual_original_sources":rows,"controlled_positive":positive,"scope":"Initial Magma canonical heat mechanism. Shared original rim/level/clipped-triangle math versus full pinned independent original surface mesher,complete actual two Volcanic/two Alien pools bit-exact. Actual normal4percent active source witnesses,controlled positive and six rejection conditions,cold deep nonvolcanic,ON/OFF/ON/stale-payload and cache bounds. Heat is an explicitly idealized intrusion below actual rendered molten rock,not measured Kelvin or normal depth gradient. Not yet wired to cave generation,no Magma biome/underground molten mesh/native cave art/full traversal completion."},"  "));print("MAGMA_HEAT_SOURCE ",checks," actual=",rows," failures=",failures);quit(0 if failures.is_empty() else 1)
