extends SceneTree
const FAN_CASES="res://tools/biome_extensions/artifacts/revisions/experiment_badlands_fan_apron_adoption_505e5ee259a6/sources/tools/badlands/artifacts/check_fan_geometry.json.txt"
var failures:Array=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func digest(b,arrays:Array)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(arrays));hash.update(var_to_bytes(b.build_swamp_water(arrays,8)));hash.update(var_to_bytes(b.built_extension_data));hash.update(var_to_bytes(b.built_badlands_palette));return hash.finish().hex_encode()
func _initialize()->void:call_deferred("run")
func run()->void:
	var sources:Dictionary={}
	for path:String in ["res://tools/badlands/check_fan_gradient_candidate.gd","res://tools/badlands/fan_gradient_candidate.gd","res://tools/badlands/check_fan_geometry.gd",FAN_CASES,"res://scripts/badlands_fan_geometry.gd","res://scripts/badlands_sampler.gd","res://scripts/badlands_settings.gd","res://scripts/terrain_mesh_builder.gd"]:sources[path]=FileAccess.get_sha256(path)
	# Freeze original seed/index/lane identities independently of future
	# regenerations of the numerical report. Recompute current fields below.
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(FAN_CASES));assert(fixture.passed)
	var records:Array=[];var changes:int=0
	var control_differences:Array=[]
	for item:Dictionary in fixture.cases:
		var seed_id:int=item.seed;var original=preload("res://tools/badlands/check_fan_geometry.gd").builder(seed_id)
		var zero=preload("res://tools/badlands/fan_gradient_candidate.gd").builder(seed_id,0)
		for cell:Vector2i in [Vector2i(19,14),Vector2i(-42,-11)]:verify(digest(original,original.build(cell,8))==digest(zero,zero.build(cell,8)),"Private zero mode exact complete original geometry/water/palette")
		for slope:float in [.01,.025,.04]:
			var candidate=preload("res://tools/badlands/fan_gradient_candidate.gd").builder(seed_id,slope);var maximum:float=0;var core_checks:int=0;var changed:int=0
			for site:Dictionary in item.floor_cases:
				var tree:Dictionary=candidate._badlands._tree(int(site.index),int(site.lane),1);var basis:PackedFloat64Array=preload("res://scripts/badlands_fan_geometry.gd").frame(tree)
				var root:=Vector2(basis[0],basis[1]);var axis:=Vector2(basis[2],basis[3]);var normal:=Vector2(-axis.y,axis.x);var reach:float=minf(425,maxf(32,basis[4]*.85))
				verify(candidate._island_mask(root.x,root.y)>.1 and candidate._badlands.region_weights(root)[14]>.6,"Original logical fan identity remains an actual on-land fan province")
				for longitudinal:float in [-.3,-.1,0,.15,.3,.5,.7,.85,1,1.3]:
					for across:float in [-450,-300,-180,-100,-40,0,40,100,180,300,450]:
						var point:Vector2=root+axis*reach*longitudinal+normal*across
						var a:PackedFloat64Array=original._badlands._raw(point);var z:PackedFloat64Array=zero._badlands._raw(point);var b:PackedFloat64Array=candidate._badlands._raw(point)
						verify(a==z,"Exact zero raw channels");verify(a.slice(1)==b.slice(1),"Positive gradient preserves all published nonheight controls")
						if a.slice(1)!=b.slice(1):
							for channel in range(1,16):
								if a[channel]!=b[channel]:control_differences.append({"seed":seed_id,"gradient":slope,"point":[point.x,point.y],"channel":channel,"original":a[channel],"candidate":b[channel],"original_repeat":original._badlands._raw(point)[channel],"candidate_repeat":candidate._badlands._raw(point)[channel],"original_height":a[0],"candidate_height":b[0]})
						var delta:float=b[0]-a[0];maximum=maxf(maximum,delta)
						verify(delta>=-.000001 and delta<=.6*(350+391*original.settings.badlands.relief)*slope+.000001,"Finite bounded positive raw deposition")
						if delta>.001:changed+=1
				var a:PackedFloat64Array=original._badlands._raw(root);var b:PackedFloat64Array=candidate._badlands._raw(root)
				verify(a[0]==b[0],"Original primary wash outlet floor remains exact");core_checks+=1
			verify(changed>0,"Actual seeded apron changes under positive gradient");changes+=changed
			records.append({"seed":seed_id,"gradient":slope,"maximum_raw_height_change":maximum,"changed_samples":changed,"primary_outlet_checks":core_checks})
	for path:String in sources:verify(FileAccess.get_sha256(path)==sources[path],"Stable private source "+path)
	var code:String=preload("res://tools/badlands/fan_gradient_candidate.gd").source_for(FileAccess.get_file_as_string("res://scripts/badlands_sampler.gd"))
	FileAccess.open("res://tools/badlands/artifacts/fan_gradient_candidate_generated.txt",FileAccess.WRITE).store_string(code)
	FileAccess.open("res://tools/badlands/artifacts/check_fan_gradient_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"control_differences":control_differences,"assertions":checks,"source_sha256":sources,"generated_sampler_sha256":code.sha256_text(),"production_registration":false,"cases":records,"changed_samples":changes,"scope":"Private rooted longitudinal deposit gradient with weighted overlap heights,not random hills. Exact zero complete meshes/water/palettes and all raw channels;positive bounded raw heights while published nonheight controls and actual primary outlet floors remain exact. Three gradients/three seeds/nine fixed fan-province roots. No actual native scenic,interpolated-grade,collision,streaming,cost or production-adoption acceptance yet."},"  "))
	print("FAN_GRADIENT_PRIVATE ",checks," checks / ",changes," changed samples / failures=",failures);quit(0 if failures.is_empty() else 1)
