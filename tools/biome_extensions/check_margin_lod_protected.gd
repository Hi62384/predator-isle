extends "res://tools/biome_extensions/check_margin_retaining_lod.gd"
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	for path:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/forest_sampler.gd","res://tools/biome_extensions/check_margin_retaining_lod.gd","res://tools/biome_extensions/check_margin_lod_protected.gd","res://tools/biome_extensions/margin_retaining_lod_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value;b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50;b._configure_noise()
			var field=b._extras[7];var a:Vector2=field.hive_node(Vector2i(-113,-103));var end:Vector2=field.hive_node(Vector2i(-112,-103));var width:float=24*scale_value;var axis:Vector2=(end-a).normalized();var side:=Vector2(-axis.y,axis.x)
			for protected_position:Vector2 in [(a+end)*.5,(a+end)*.5+side*(400+width*2),a]:
				var protected_sites:Array=[{"position":protected_position,"half":96.0}]
				var old=Structures.new();old.origin=Vector3(floorf(a.x/256)*256,0,floorf(a.y/256)*256);old._support_steps=Structures.support_grids();old._protected_sites=protected_sites;old.conduit(b,a,end,width,.47,Color(.34,.28,.26))
				var trial=Candidate.new();trial.origin=old.origin;trial._support_steps=old._support_steps;trial._protected_sites=protected_sites
				var owner:=Vector2i(floori(a.x/16384),floori(a.y/16384));b.set_meta(trial.CONTEXT,{"bounds":Rect2(Vector2(owner)*16384,Vector2.ONE*16384),"ratio":.5,"floor":INF})
				trial.conduit(b,a,end,width,.47,Color(.34,.28,.26));b.remove_meta(trial.CONTEXT)
				check(margin_attributes(trial)==margin_attributes(old),"Exact all protected-approach contact/apron attributes, including collapsed and tapered skirts")
				check(boundary(trial)==boundary(old),"No new open or T-junction boundary beside a protected cavity approach")
				check(trial.vertices.size()<=old.vertices.size(),"Protection does not create hidden extra detail")
				cases.append({"seed":seed_id,"scale":scale_value,"protected_position":protected_position,"original_vertices":old.vertices.size(),"trial_vertices":trial.vertices.size()})
	check(cases.size()==27,"All three protection layouts at every seed/scale")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable protected-approach LOD source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_margin_lod_protected.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":false,"scope":"Private retained-margin topology/attribute controls over 27 seed/scale/protected-site layouts, including full approach collapse, partial skirt taper and endpoint reservation. Every original protected contact/apron attribute and boundary edge remains exact. Primitive controls, not an arbitrary cave route, native traversal or production-registration certificate."},"  "))
	print("MARGIN_LOD_PROTECTED ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
