extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/nerve_fibres_candidate.gd")
func candidate_builder(seed_id:int,extent:float,height:float):
	var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=extent;b.settings.alien_infected.conduit_cache_mib=0;b._configure_noise()
	var field=Candidate.new();field.fibre_height=height;field.configure(b.settings.alien_infected,seed_id,b,7);b._extras[7]=field;return b
func preview_site()->Dictionary:
	var catalogue=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"));var item:Dictionary=catalogue.families.alien_infected.regions["1"]
	var p:=Vector2(item.x,item.z);var base=candidate_builder(73921,1,0);var raised=candidate_builder(73921,1,24);var field=raised._extras[7];var cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var edges:PackedVector2Array=field.network_edges(cell);var best:Dictionary={};var best_delta:float=0
	for edge in range(0,8,4):
		for t:float in [.15,.25,.35,.45,.55,.65,.75,.85]:
			var center:Vector2=edges[edge].lerp(edges[edge+1],t*2) if t<.5 else edges[edge+1].lerp(edges[edge+2],(t-.5)*2)
			var axis:Vector2=(edges[edge+1]-edges[edge]).normalized() if t<.5 else (edges[edge+2]-edges[edge+1]).normalized();var side:=Vector2(-axis.y,axis.x)
			for offset:float in [-220,-140,-70,0,70,140,220,300]:
				var q:Vector2=center+side*offset;var old_height:float=base._get_height(q.x,q.y);var new_height:float=raised._get_height(q.x,q.y);var delta:float=new_height-old_height
				if delta<=best_delta or old_height<maxf(base.water_level,base.get_water_surface_height(q.x,q.y))+6:continue
				if raised._last_extras[7].x<.92:continue
				best_delta=delta;best={"seed":73921,"x":q.x,"z":q.y,"base_height":old_height,"candidate_height":new_height,"actual_added_height":delta,"axis":[axis.x,axis.y],"region":field.region(q)}
	return best
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/nerve_fibres_candidate.gd","res://tools/biome_extensions/check_nerve_fibres_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[]
	hashes["res://tools/biome_extensions/artifacts/previews.json"]=FileAccess.get_sha256("res://tools/biome_extensions/artifacts/previews.json")
	for seed_id:int in [73921,17,92881]:
		for extent:float in [.2,1,2]:
			var base=candidate_builder(seed_id,extent,0)
			var disabled=candidate_builder(seed_id,extent,0);var enabled=candidate_builder(seed_id,extent,24)
			var max_added:float=0;var max_added_gradient:float=0;var changed:int=0
			for i in range(256):
				var p:=Vector2(i*7919%180000-90000,i*11939%180000-90000)
				for habit in range(6):
					var original:PackedFloat64Array=base._extras[7].evaluate(p,habit);var zero:PackedFloat64Array=disabled._extras[7].evaluate(p,habit);var value:PackedFloat64Array=enabled._extras[7].evaluate(p,habit)
					check(original==zero,"Zero prototype relief retains exact original regional fields")
					check(value.slice(1)==original.slice(1),"Water/wetness/region/feature controls unchanged")
					if habit!=1:check(value==original,"Only Nerve lowlands regional height is changed")
					else:
						var added:float=value[0]-original[0];max_added=maxf(max_added,added);check(added>=0 and added<=24,"Bounded positive trunk-associated physical fibre relief")
						if added>.05:changed+=1
						var gradient:=Vector2.ZERO
						for axis:int in range(2):
							var d:=Vector2(1,0) if axis==0 else Vector2(0,1)
							var plus:float=enabled._extras[7].evaluate(p+d,1)[0]-base._extras[7].evaluate(p+d,1)[0];var minus:float=enabled._extras[7].evaluate(p-d,1)[0]-base._extras[7].evaluate(p-d,1)[0]
							gradient[axis]=(plus-minus)*.5
						max_added_gradient=maxf(max_added_gradient,gradient.length());check(gradient.is_finite(),"Finite local added-relief gradient")
			for cell:Vector2i in [Vector2i(-12,-11),Vector2i.ZERO,Vector2i(20,20)]:
				var a:Array=base.build(cell,16);var z:Array=disabled.build(cell,16)
				check(a==z and base.built_extension_data==disabled.built_extension_data,"Complete zero-relief terrain/atlas equality")
			check(changed>16,"Actual network-associated relief, not an unused setting")
			# Probe both sides of the closest-segment bisector at real path bends.
			# Public network results remain exactly the original dictionary.
			for cell:Vector2i in [Vector2i(-12,-11),Vector2i.ZERO,Vector2i(20,20)]:
				var field=enabled._extras[7];var edges:PackedVector2Array=field.network_edges(cell)
				for edge in range(0,8,4):
					var incoming:Vector2=(edges[edge+1]-edges[edge]).normalized();var outgoing:Vector2=(edges[edge+2]-edges[edge+1]).normalized()
					var tangent:Vector2=(incoming+outgoing).normalized();var side:=Vector2(-tangent.y,tangent.x)
					for offset:float in [-320,-160,-60,60,160,320]:
						var p:Vector2=edges[edge+1]+side*offset*extent;var epsilon:float=.125*extent
						var values:PackedFloat64Array=[]
						for sign_value:float in [-1,0,1]:
							var q:Vector2=p+tangent*epsilon*sign_value
							values.append(field.evaluate(q,1)[0]-base._extras[7].evaluate(q,1)[0])
							check(field.network(q)==base._extras[7].network(q),"Public network result unchanged at path bends")
						check(absf(values[0]-values[2])<epsilon*3,"No added-height step when the closest segment changes")
			records.append({"seed":seed_id,"extent":extent,"changed_raw_points":changed,"maximum_added_height_m":max_added,"maximum_observed_added_raw_gradient":max_added_gradient})
	var site:Dictionary=preview_site();check(not site.is_empty() and site.get("actual_added_height",0)>.5,"Actual dry Nerve-lowland site with visible prototype relief")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable prototype source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_nerve_fibres_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"experimental_only":true,"production_change_kept":false,"records":records,"preview_site":site,"source_sha256":hashes,"scope":"Raw full-biome Nerve-lowland trunk-associated fibre relief prototype, three seeds/feature scales, bounded positive height, unchanged other regional fields and water/control channels, exact complete zero-relief terrain/atlas comparisons. No production registration, partial-overlay update, native streaming, traversal, visual or performance acceptance."},"  "))
	print("NERVE_FIBRES_CANDIDATE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
