extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var failures:Array=[];var evidence:Dictionary={}
	var guide_names:Array[String]=["check_surface_guide_candidate","check_surface_guide_attachments","check_surface_guide_topology","check_surface_guide_collision","check_junction_custom_admission","check_junction_navigation_admission","check_junction_navigation_walk","check_native_walk_admission","check_rejected_steep_approach","check_far_conduit_lod","check_lod_controller","check_runtime_structure_lod"]
	guide_names.append_array(["check_margin_retaining_lod","check_margin_lod_protected","check_margin_lod_controller","check_margin_lod_shore_sites","check_runtime_margin_lod"])
	for name:String in guide_names:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var result=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not result is Dictionary or not result.get("passed",false) or not result.get("failures",[1]).is_empty():failures.append("Missing/failed surface-guide proof "+name);continue
		for source:String in result.source_sha256:
			if FileAccess.get_sha256(source)!=result.source_sha256[source]:failures.append("Stale surface-guide source "+name+": "+source)
		evidence[name]={"path":path,"sha256":FileAccess.get_sha256(path),"checks":result.checks,"scope":result.scope}
		if name=="check_junction_navigation_walk" and result.cases.size()!=6:failures.append("All six current navigation-admitted custom-scale returns required")
		if name=="check_margin_lod_shore_sites" and result.cases.size()!=3:failures.append("All three actual deformed shore sites required")
		if name=="check_runtime_margin_lod" and result.cases.size()!=6:failures.append("All six actual mixed/shore whole-node controls required")
	for name:String in ["profile_margin_retaining_lod","render_margin_lod_shores","check_conduit_footings","check_conduit_shoulders","profile_feature_ground_attachment","check_integration","check_alien_edge_cache","check_debug_light_invariance","check_biological_projection","check_alien_junctions","check_junction_admission","check_junction_collision","check_junction_walk","render_junctions","profile_conduit_foundations","profile_junctions","check_normal_controls","check_structure_normal_controls","check_scene_sun","check_authored_color_space_gl_compatibility","check_carapace_placement_policy","check_carapace_geometry","check_carapace_admission","check_carapace_collision","render_carapace","profile_carapace","check_production_conduit_memo","profile_production_conduit_memo","profile_conduit_memo_streaming_membrane_root","check_membrane_clearance","check_membrane_candidate","check_membrane_junction_candidate","check_membrane_attachments","check_membrane_collision","check_production_membranes","profile_membranes","check_production_network_tiles","check_network_tile_eviction","profile_production_network_tiles","profile_network_tile_streaming_query_root","check_production_nerve_fibres","check_nerve_fibre_walk","render_production_nerve_fibres","profile_nerve_fibres"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json"
		if not FileAccess.file_exists(path):failures.append("Missing "+path);continue
		var report=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not report is Dictionary:failures.append("Invalid "+path);continue
		if report.has("passed") and not report.passed:failures.append("Failed "+name)
		if report.has("failures") and not report.failures.is_empty():failures.append("Failures in "+name)
		if not report.has("source_sha256"):failures.append("Missing source guards "+name)
		else:
			for source:String in report.source_sha256:
				if FileAccess.get_sha256(source)!=report.source_sha256[source]:failures.append("Stale source "+name+": "+source)
		evidence[name]={"path":path,"sha256":FileAccess.get_sha256(path),"checks":report.get("checks",null),"scope":report.get("scope",null)}
		if report.has("capture_sha256"):
			for png:String in report.capture_sha256:
				if FileAccess.get_sha256(png)!=report.capture_sha256[png]:failures.append("Changed native pixels "+png)
				var pixels:=Image.load_from_file(png)
				if pixels==null or pixels.get_size()!=Vector2i(1280,720):failures.append("Native image dimensions "+png)
		if name=="profile_feature_ground_attachment":
			if report.margins_above_actual_mesh!=0 or report.guarded_unextended_exposed!=0:failures.append("Exposed native conduit margins")
			evidence[name]["sampled_outer_feet"]=report.conduit_margin_samples;evidence[name]["maximum_clearance_m"]=report.maximum_margin_clearance_m
		if name.begins_with("profile_") and report.has("summary"):evidence[name]["measured_native_streaming_summary" if name.contains("_streaming_") else "measured_cpu_summary"]=report.summary
		if name=="profile_nerve_fibres":evidence[name]["paired_median_numeric_terrain_ratio"]=report.paired_median_numeric_terrain_ratio
		if name=="check_debug_light_invariance":
			if not report.get("production_registration",false) or report.captures.size()!=28:failures.append("Actual production debug guard and complete physical/debug fixture required")
			evidence[name]["records"]=report.records;evidence[name]["whole_scene_physical_equivalence"]=report.whole_scene_physical_equivalence;evidence[name]["preserved_mixed_layer_mismatch_pixels"]=report.preserved_mixed_layer_mismatch_pixels
		if name in ["render_junctions","render_carapace","render_production_nerve_fibres","check_debug_light_invariance","render_margin_lod_shores"]:
			var expected_views:int=9 if name=="render_margin_lod_shores" else (28 if name=="check_debug_light_invariance" else (24 if name=="render_carapace" else (6 if name=="render_production_nerve_fibres" else 12)))
			if report.captures.size()!=expected_views:failures.append("Complete native views required "+name)
			for view:Dictionary in report.captures:
				var png:String="res://tools/biome_extensions/artifacts/"+view.biome+"_"+view.view+".png"
				if not view.committed or FileAccess.get_sha256(png)!=view.sha256:failures.append("Native junction cut/pixels "+png)
				var pixels:=Image.load_from_file(png)
				if pixels==null or pixels.get_size()!=Vector2i(1280,720):failures.append("Native image dimensions "+png)
			evidence[name]["captures"]=report.captures
			if name=="render_margin_lod_shores":
				if report.worker_proofs.size()!=3 or not report.production_registration:failures.append("All three actual committed shore-worker proofs required")
				var shore_seeds:Array[int]=[]
				for proof:Dictionary in report.worker_proofs:
					shore_seeds.append(int(proof.seed))
					if not proof.reduced or proof.actual_worker_vertex_positions_matched<=0 or proof.original_full_vertices<=proof.actual_worker_vertex_positions_matched or proof.actual_coastal_overlay_amount<.12:failures.append("Missing actual shore reduction/native worker binding")
				shore_seeds.sort()
				if shore_seeds!=[17,73921,92881]:failures.append("Distinct actual shore seeds required")
				evidence[name]["worker_proofs"]=report.worker_proofs
			if name=="render_junctions":
				var membrane_cases:int=0
				for view:Dictionary in report.captures:
					if view.view=="medium" and view.get("production_membrane_vertices",0)==5136:membrane_cases+=1
				if membrane_cases<1:failures.append("Actual default-rarity worker membrane required")
			if name=="render_carapace":
				var footing_cases:int=0
				for view:Dictionary in report.captures:
					if view.view!="medium":continue
					footing_cases+=1
					if view.get("production_tagged_vertices",0)!=18000 or view.get("unique_footings",0)!=120 or view.get("maximum_footing_clearance_m",0)>=-.05:failures.append("Missing/exposed real plate geometry/feet")
				if footing_cases!=6:failures.append("Six actual plate-footing cases required")
	var regression_path:String="res://data/surface_regression_20261018.json"
	var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path))
	if not regression is Dictionary or not regression.get("passed",false) or regression.get("test_count",0)!=31:failures.append("Shared 31-script regression missing/failed")
	else:
		for source:String in regression.source_sha256:
			if FileAccess.get_sha256("res://"+source.replace("\\","/"))!=regression.source_sha256[source]:failures.append("Shared regression stale "+source)
		evidence["shared_surface_regression"]={"path":regression_path,"sha256":FileAccess.get_sha256(regression_path),"test_count":regression.test_count,"date":regression.date,"scope":regression.scope}
	if not failures.is_empty():
		push_error("Alien follow-up not written: "+str(failures));quit(1);return
	var result:Dictionary={"completed_utc":Time.get_datetime_string_from_system(true),"evidence_validated":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"infinite_cave_foundation_implemented":false,"cave_biomes_implemented":false,"evidence":evidence,"limitations":["Scoped sampled attachment, native collision, three default-scale and six navigation-admitted minimum/maximum-scale junction returns plus one 480m fibre return. The original steep seed92881 minimum-scale approach remains a preserved failed/rejected route, not repaired or replaced in its geometric manifest; this does not certify arbitrary roots, slopes or whole-world traversal.","Junctions are closed biological blades/root struts with an open exterior ground passage, not cave entrances or underground hive chambers.","Smooth distant landscape, thin structure/material joins and broader surface scenic targets remain unfinished. Distant mixed/coastal/noise conduit LOD now retains every original contact/apron cell while adaptively simplifying far roofs; broad arbitrary-settings/shore and visual-performance acceptance remains open.","Foundation CPU work and cold-start/frame spikes remain measured limitations. Fibre, membrane and cache CPU costs are measured in the attached declared workloads, not inferred from earlier revisions. Native cache results are scoped to their separately declared route; sparse/random query tradeoffs and first-cut/frame spikes remain open.","Debug emitted-value invariance and terrain-only physical response pass in declared controls; the separately preserved four-pixel mixed-layer intersection difference is unresolved, not whole-scene physical equivalence.","Later Infinite Default, Default/Frozen registry, Crystal Caverns and Magma Caverns remain queued in user order."]}
	FileAccess.open("res://data/alien_surface_followup_20261019.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("ALIEN_FOLLOWUP_VALIDATED ",evidence.size()," guarded reports; all-user-tasks-complete=false");quit()
