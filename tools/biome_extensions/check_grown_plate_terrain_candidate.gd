extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/grown_plate_terrain_candidate.gd")
func field_builder(seed_id:int,scale_value:float,relief_value:float):
	var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value;b._configure_noise();var field=Candidate.new();field.plate_relief=relief_value;field.configure(b.settings.alien_infected,seed_id,b,7);b._extras[7]=field;return b
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/grown_plate_terrain_candidate.gd","res://tools/biome_extensions/check_grown_plate_terrain_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var sites:Array=[];var bound_failures:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			var original=make_builder(7,seed_id);original.settings.alien_infected.feature_scale=scale_value;original._configure_noise()
			var zero=field_builder(seed_id,scale_value,0);var enabled=field_builder(seed_id,scale_value,72);var changed:int=0;var maximum:float=0;var max_gradient:float=0
			for i in range(600):
				var p:=Vector2(i*7919%120000-60000,i*11939%120000-60000)
				for habit in range(6):
					var old:PackedFloat64Array=original._extras[7].evaluate(p,habit);var disabled:PackedFloat64Array=zero._extras[7].evaluate(p,habit);var value:PackedFloat64Array=enabled._extras[7].evaluate(p,habit)
					check(old==disabled,"Exact zero-relief original regional fields")
					check(value.slice(1)==old.slice(1),"Unchanged water/control fields")
					if habit not in [2,5]:check(value==old,"Only hard/ancient carapace regional height changes")
					else:
						var added:float=value[0]-old[0];var upper:float=72*minf(scale_value,1);var lower:float=-upper*.5
						# Test raw deformation exactly, then allow 1nm only for the
						# floating-point (base+delta)-base cancellation in published height.
						var raw:float=enabled._extras[7].grown_crust(p,habit)
						check(raw>=lower and raw<=upper,"Exact raw deformation bounds")
						var excess:float=maxf(0,maxf(lower-added,added-upper));var bound_ok:bool=excess<=.000000001
						check(bound_ok,"Bounded raised or planed crust")
						if excess>0:bound_failures.append({"seed":seed_id,"scale":scale_value,"point":p,"habit":habit,"old":old[0],"new":value[0],"delta":added,"lower":lower,"upper":upper,"floating_point_excess_m":excess,"within_1nm_height_cancellation_tolerance":bound_ok})
						if absf(added)>.1:changed+=1
						maximum=maxf(maximum,added)
						var gradient:=Vector2.ZERO
						for axis:int in range(2):
							var d:=Vector2(1,0) if axis==0 else Vector2(0,1)
							gradient[axis]=(enabled._extras[7].grown_crust(p+d,habit)-enabled._extras[7].grown_crust(p-d,habit))*.5
						max_gradient=maxf(max_gradient,gradient.length());check(gradient.is_finite(),"Finite crust gradient")
				if scale_value==1 and sites.size()<6:
					var height:float=enabled._get_height(p.x,p.y);var base_height:float=original._get_height(p.x,p.y)
					var r:float=enabled._extras[7].region(p);var habit:int=roundi(r);var already:bool=false
					for previous:Dictionary in sites:
						if int(previous.seed)==seed_id and int(previous.habit)==habit:already=true
					if not already and habit in [2,5] and height-base_height>12 and base_height>maxf(original.water_level,original.get_water_surface_height(p.x,p.y))+6 and enabled._last_extras[7].x>.92:
						sites.append({"seed":seed_id,"habit":habit,"x":p.x,"z":p.y,"base_height":base_height,"candidate_height":height,"added_height":height-base_height,"region":r})
			for cell:Vector2i in [Vector2i(-12,-11),Vector2i.ZERO,Vector2i(20,20)]:
				var a:Array=original.build(cell,16);var b:Array=zero.build(cell,16);check(a==b and original.built_extension_data==zero.built_extension_data,"Full zero-mode terrain/atlas equality")
			check(changed>10,"Actual nonzero grown crust")
			check(enabled._extras[7]._plate_shapes.size()<=512,"Bounded worker-only shape cache")
			records.append({"seed":seed_id,"scale":scale_value,"changed_raw_points":changed,"maximum_raw_added_height_m":maximum,"maximum_observed_raw_added_gradient":max_gradient})
	check(not sites.is_empty(),"Actual dry preview geography")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_grown_plate_terrain_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"bound_failures":bound_failures,"source_sha256":hashes,"records":records,"sites":sites,"experimental_only":true,"production_change_kept":false,"scope":"Private grown-carapace terrain study, three seeds/scales, compact irregular overlapping trunk-oriented crust, unchanged other regional/control fields and complete zero-mode meshes/atlas. Not production, native art, collision/traversal or performance acceptance."},"  "))
	print("GROWN_PLATE_TERRAIN_CANDIDATE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
