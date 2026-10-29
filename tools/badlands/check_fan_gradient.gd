extends SceneTree
const CASES="res://tools/biome_extensions/artifacts/revisions/experiment_badlands_fan_apron_adoption_505e5ee259a6/sources/tools/badlands/artifacts/check_fan_geometry.json.txt"
const FROZEN="res://tools/biome_extensions/artifacts/revisions/experiment_fan_gradient_trial_2305e1381e5c/sources/scripts/badlands_sampler.gd.txt"
var checks:int=0
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
static func builder(seed_id:int,gradient:float):
	var b=preload("res://tools/badlands/check_fan_geometry.gd").builder(seed_id);b.settings.badlands.fan_gradient=gradient;b._configure_noise();return b
func payload(b,cell:Vector2i)->Array:
	var a:Array=b.build(cell,16)
	return [a,b.build_swamp_water(a,16),b.built_extension_data.duplicate(),b.built_badlands_palette.duplicate(),b.built_extension_mask,b.built_badlands_palette_slot]
func _initialize()->void:call_deferred("run")
func run()->void:
	var guards:Dictionary={}
	for path:String in [CASES,FROZEN,"res://tools/badlands/check_fan_gradient.gd","res://tools/badlands/check_fan_geometry.gd","res://tools/badlands/fan_gradient_candidate.gd","res://scripts/badlands_sampler.gd","res://scripts/badlands_settings.gd","res://scripts/badlands_fan_geometry.gd","res://scripts/terrain_mesh_builder.gd"]:guards[path]=FileAccess.get_sha256(path)
	var original:=GDScript.new();original.source_code=FileAccess.get_file_as_string(FROZEN);assert(original.reload()==OK)
	var prototype:=GDScript.new();prototype.source_code=preload("res://tools/badlands/fan_gradient_candidate.gd").source_for(original.source_code);assert(prototype.reload()==OK)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(CASES));var records:Array=[]
	for item:Dictionary in fixture.cases:
		var seed_id:int=item.seed;var zero=builder(seed_id,0);var before=builder(seed_id,0);var old=original.new();old.configure(before.settings.badlands,seed_id,before);before._badlands=old
		for cell:Vector2i in [Vector2i(19,14),Vector2i(-42,-11)]:verify(payload(zero,cell)==payload(before,cell),"Zero mode exact complete pre-gradient payload")
		for slope:float in [0,.01,.025,.04,.08]:
			var current=builder(seed_id,slope);var reference=builder(seed_id,0);var private_field=prototype.new();private_field.fan_gradient=slope;private_field.configure(reference.settings.badlands,seed_id,reference);reference._badlands=private_field
			var changed:int=0;var maximum:float=0;var maximum_grade:float=0
			for site:Dictionary in item.floor_cases:
				var tree:Dictionary=current._badlands._tree(int(site.index),int(site.lane),1);var basis:PackedFloat64Array=preload("res://scripts/badlands_fan_geometry.gd").frame(tree)
				var root:=Vector2(basis[0],basis[1]);var axis:=Vector2(basis[2],basis[3]);var normal:=Vector2(-axis.y,axis.x);var reach:float=minf(425,maxf(32,basis[4]*.85))
				verify(current._island_mask(root.x,root.y)>.1 and current._badlands.region_weights(root)[14]>.6,"Frozen logical fan remains on land in the fan province")
				for along:float in [-.3,-.1,0,.15,.3,.5,.7,.85,1,1.3]:
					for across:float in [-450,-300,-180,-100,-40,0,40,100,180,300,450]:
						var p:Vector2=root+axis*reach*along+normal*across
						var a:PackedFloat64Array=zero._badlands._raw(p);var b:PackedFloat64Array=current._badlands._raw(p)
						verify(b==reference._badlands._raw(p),"Registered gradient exactly matches the accepted private formula")
						verify(a.slice(1)==b.slice(1),"All nonheight controls unchanged")
						var delta:float=b[0]-a[0];maximum=maxf(maximum,delta)
						verify(delta>=-.000001 and delta<=.6*(350+391*current.settings.badlands.relief)*slope+.000001,"Bounded nonnegative deposit")
						if delta>.001:changed+=1
						# Actual canonical field including interpolation,not only raw samples.
						var h:float=current._get_height(p.x,p.y);verify(h==reference._get_height(p.x,p.y),"Canonical interpolated height matches independent frozen prototype")
						for offset:Vector2 in [Vector2(2,0),Vector2(0,2)]:maximum_grade=maxf(maximum_grade,absf(current._get_height(p.x+offset.x,p.y+offset.y)-h)/2)
				verify(zero._badlands._raw(root)[0]==current._badlands._raw(root)[0],"Primary outlet height stays exact")
				var cell:=Vector2i(floori(root.x/256),floori(root.y/256));verify(payload(current,cell)==payload(reference,cell),"Actual seeded complete mesh/water/packed payload equals prototype")
			verify((changed==0)==(slope==0),"Positive gradient changes actual fans;zero changes none")
			records.append({"seed":seed_id,"gradient":slope,"changed_samples":changed,"maximum_raw_deposit_metres":maximum,"maximum_canonical_sampled_grade_including_existing_terrain":maximum_grade})
	for path:String in guards:verify(FileAccess.get_sha256(path)==guards[path],"Stable source "+path)
	FileAccess.open("res://tools/badlands/artifacts/check_fan_gradient.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"assertions":checks,"source_sha256":guards,"cases":records,"production_registration":true,"scope":"Independent zero comparison to frozen pre-gradient production and positive comparison to preserved private formula. Five gradients,three seeds,nine fixed logical fans,all raw controls,canonical interpolation,and actual full payloads. Grade reported including existing terrain,not a universal walkability assertion;physical routes and native review separate."},"  "));print("REGISTERED_FAN_GRADIENT ",checks," checks /failures=",failures);quit(0 if failures.is_empty() else 1)
