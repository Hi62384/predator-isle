extends "res://tools/caves/render_crystal_fixed_profiled.gd"
var canonical_field
var same_theme_prisms:int=0
var anchor_veins:int=0
var dominant_nodes:int=0
var actual_extent:float=0
func selection_label()->String:return "Same original1422m admitted candidate and exact original near1500 descriptor location;regional mineral ownership validated instead of requiring every logical lobe to own a large prism"
func inspection_control_scope()->String:return "Original CrystalWastes17/(9,-3)/9:-3:2:1:lobe:0 retained. Its three actual attached vein segments and same canonical1422m theme's parent/sibling prisms are required. Original stricter per-lobe prism failure remains archived;zero forced probability/density/growth and no substituted seed/site/room. This is REGION extent coverage,not a claim that every geological lobe contains a prism."
func inspection_prepare_workload(work)->void:canonical_field=work.field
func additional_guards()->Dictionary:
	var result:Dictionary=super.additional_guards();result["res://tools/caves/render_crystal_fixed_profiled.gd"]=FileAccess.get_sha256("res://tools/caves/render_crystal_fixed_profiled.gd");return result
func inspection_views(data:Dictionary,_largest:Dictionary)->Array:
	var owners:Dictionary={};var largest:Dictionary={}
	for candidate:Dictionary in canonical_field._biome_assignment.get("candidates",[]):
		if str(candidate.id)==str(selection.theme):actual_extent=candidate.extent_m
	for region:Dictionary in data.bundle.regions:
		for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
			var assignment:Dictionary=Regions.along_edge(canonical_field._biome_assignment,str(room.id),str(room.id),0,0)
			if str(assignment.candidate_ids.get("crystal",""))==str(selection.theme) and float(assignment.weights.get("crystal",0))>=.8:owners[str(room.id)]=true
	dominant_nodes=owners.size()
	for form:Dictionary in data.placements:
		if form.kind=="mineral_vein" and str(form.id).begins_with(str(data.room.id)+"/"):anchor_veins+=1
		if form.kind!="crystal":continue
		for id:String in owners:
			if str(form.id).begins_with(id+"/"):
				same_theme_prisms+=1
				if largest.is_empty() or form.height>largest.height:largest=form
				break
	check(absf(actual_extent-1422.16184446588)<.00001 and dominant_nodes>0,"Original1422m candidate retained and canonically dominant on actual connected nodes")
	check(same_theme_prisms>0 and anchor_veins>0 and not largest.is_empty(),"Actual original anchor has attached mineral veins and SAME canonical region has positive parent/sibling crystal geometry")
	var center:Vector3=data.room.point;var target:Vector3=largest.bounds.get_center() if not largest.is_empty() else center+Vector3(10,4,0)
	return [{"name":"same_original_region_mineral","position":center+Vector3.UP*1.8,"target":target},{"name":"original_logical_lobe_veins_and_region","position":center+Vector3.UP*1.8,"target":target+Vector3.UP*3},{"name":"original_connected_neck","position":data.parent.point+Vector3.UP*1.8,"target":center+Vector3.UP*4}]
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var result:Dictionary=await super.inspection_material_checks(data,nodes,camera,light);result["actual_candidate_extent_m"]=actual_extent;result["canonical_dominant_nodes"]=dominant_nodes;result["actual_same_theme_prisms"]=same_theme_prisms;result["actual_anchor_vein_segments"]=anchor_veins;result["original_location_retained"]=true;return result
