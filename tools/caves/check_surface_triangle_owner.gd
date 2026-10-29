extends "res://tools/caves/check_frozen_world_cohort.gd"
const Current=preload("res://scripts/caves/surface_context.gd")
const Before=preload("res://tools/caves/references/magma_original_surface_context.gd")
func triangle(points:PackedVector3Array)->Array:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);var normals:=PackedVector3Array();var colors:=PackedColorArray()
	for point:Vector3 in points:normals.append(Vector3.UP);colors.append(Color(.38,.35,.30,1))
	arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;return arrays
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/surface_context.gd","res://scripts/caves/surface_payload.gd","res://tools/caves/references/magma_original_surface_context.gd","res://tools/biome_extensions/artifacts/magma_first_portal_work.bin"]:guards[path]=FileAccess.get_sha256(path)
	check(guards["res://tools/caves/references/magma_original_surface_context.gd"]=="8b4fab0637d679a8f1008fa0a717a914bc92f4e73b7f337d470e9b6be847d29d","Full independent pre-fix context source pinned")
	var data:Dictionary=FileAccess.open("res://tools/biome_extensions/artifacts/magma_first_portal_work.bin",FileAccess.READ).get_var(false);var b=owner("volcanic",17);var old=Before.new();var current=Current.new();check(old.configure(data.parents,b._get_height) and current.configure(data.parents,b._get_height),"Same original failed native parent arrays configure old/new contexts")
	var comparisons:int=0
	for parent:Dictionary in data.parents:
		var points:PackedVector3Array=parent.arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=parent.arrays[Mesh.ARRAY_INDEX]
		for index in range(300,900,3):
			var arrays:Array=triangle(PackedVector3Array([points[indices[index]],points[indices[index+1]],points[indices[index+2]]]));var first:Dictionary=old.surfaces_indexed(arrays,parent.origin,true);var second:Dictionary=current.surfaces_indexed(arrays,parent.origin,true)
			check(first.valid and var_to_bytes(first)==var_to_bytes(second),"Entire original valid indexed vertices/normals/colors/payload/atlas/indices/collision byte-exact");check(var_to_bytes(old.surfaces(arrays,parent.origin))==var_to_bytes(current.surfaces(arrays,parent.origin)),"Entire original valid nonindexed payload byte-exact");comparisons+=1
	var origin:=Vector3(-111296,0,212928);var ground:float=current.height_at(-111270,212992);var points:=PackedVector3Array([Vector3(26,ground-.25,63.984375),Vector3(28,ground-.2,64),Vector3(26,ground-.15,64)]);var arrays:Array=triangle(points);var rejected:Dictionary=old.surfaces_indexed(arrays,origin,true);var accepted:Dictionary=current.surfaces_indexed(arrays,origin,true)
	check(not rejected.valid and rejected.reason=="Surface replacement triangle crosses unsupported parent boundary","Exact far-origin single-ULP centroid/parent negative reproduces original rejection")
	check(accepted.valid and accepted.groups.size()==1 and accepted.collision_faces==points,"Corrected parent lookup keeps original complete geometry and collision,without clipping/clamping/removal")
	var id:String=str(current.owner_at(Vector2(-111270,212992-.015625)));check(accepted.groups.has(id) and accepted.groups[id].arrays[Mesh.ARRAY_VERTEX]==points,"All corners use actual wholly containing original fine parent")
	var payload:PackedFloat32Array=accepted.groups[id].payload;var mismatches:int=0
	for corner in range(3):
		var p:Vector3=points[corner]+origin;var expected:PackedFloat32Array=current.controls(id,Vector2(p.x,p.z))
		for component in range(67):mismatches+=int(payload[corner*68+component]!=expected[component])
	check(mismatches==0,"Every decoded original terrain control remains exact;only original entry-depth channel appended")
	var outside:Array=triangle(PackedVector3Array([Vector3(-66,ground,63),Vector3(26,ground,64),Vector3(28,ground+.1,64)]));check(not current.surfaces_indexed(outside,origin,true).valid,"Real missing original parent coverage still rejected,never extrapolated")
	var cross_parent:Array=triangle(PackedVector3Array([Vector3(26,ground-.2,62),Vector3(28,ground-.2,66),Vector3(26,ground-.1,66)]));check(not current.surfaces_indexed(cross_parent,origin,true).valid,"Genuinely crossing material-parent triangle still fails closed,not silently assigned/clipped")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable corrected ownership source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_triangle_owner.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"whole_triangle_comparisons":comparisons,"decoded_control_mismatches":mismatches,"original_rejection":rejected.get("reason",""),"actual_parent":id,"scope":"Exact first failed production parent snapshot plus pinned whole original context:400already-valid indexed/nonindexed triangles remain byte-exact,far-origin centroid-ULP negative now selects whole-triangle containing original parent,all67original controls/collision/positions unchanged. True cross-parent/outside-coverage cases still reject. Separate whole portal replay/live return required."},"  "));print("SURFACE_TRIANGLE_OWNER ",checks," comparisons=",comparisons," failures=",failures);quit(0 if failures.is_empty() else 1)
