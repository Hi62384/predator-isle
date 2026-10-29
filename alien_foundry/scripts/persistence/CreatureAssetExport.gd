extends RefCounted
## Narrow rest-geometry/rig export adapter. No custom-shader, physics collision
## or procedural-preview-animation portability is claimed by this GLB contract.
const Placement = preload("res://alien_foundry/scripts/pipeline/BlobGroundPlacement.gd")

static func create_export_root(visual: Node3D) -> Dictionary:
	if not is_instance_valid(visual) or not visual.has_method("organism_to_asset_transform"):
		return {"error": "Export requires a complete CreatureVisual."}
	var dna: Dictionary = visual.get_meta("dna", {})
	var check := Placement.validate_declaration(dna)
	if not bool(check.get("ok", false)): return {"error": check.error}
	if Placement.enabled(dna) and (not dna.has("asset_placement") or visual.organism_to_asset_transform() != Placement.transform_for(dna.asset_placement)):
		return {"error": "Export placement differs from the preserved intrinsic asset frame."}
	# Duplicate node/resource hierarchy only. Do not disable animation, mutate
	# stage visibility, move the actor, or edit any displayed mesh/bind array.
	var copied: Node3D = visual.duplicate(0)
	copied.name = "BlobAsset"
	copied.transform = Transform3D.IDENTITY
	var remove_paths: Array[NodePath] = []
	for node: Node in visual._stage_preview_roots.values():
		if is_instance_valid(node): remove_paths.append(visual.get_path_to(node))
	for node: Node in [visual.preview, visual.anatomy_lines]:
		if is_instance_valid(node): remove_paths.append(visual.get_path_to(node))
	if is_instance_valid(visual.preview) and is_instance_valid(visual.preview.skeleton_lines):
		remove_paths.append(visual.get_path_to(visual.preview.skeleton_lines))
	for path: NodePath in remove_paths:
		var node: Node = copied.get_node_or_null(path)
		if node != null: node.free()
	if is_instance_valid(visual.preview):
		for mouth: Dictionary in visual.preview.mouth_meshes:
			if not is_instance_valid(mouth.mesh): continue
			var target: MeshInstance3D = copied.get_node_or_null(visual.get_path_to(mouth.mesh))
			if target != null: target.set_blend_shape_value(int(mouth.index), float(mouth.rest))
	_clean(copied)
	for source: MeshInstance3D in visual.render_meshes:
		if not is_instance_valid(source): continue
		var target: MeshInstance3D = copied.get_node_or_null(visual.get_path_to(source))
		if target == null: copied.free(); return {"error": "Export lost a finalized anatomical mesh."}
		target.visible = true
		target.material_override = null
	if is_instance_valid(visual.skeleton):
		var skeleton: Skeleton3D = copied.get_node_or_null(visual.get_path_to(visual.skeleton))
		if skeleton == null: copied.free(); return {"error": "Export lost the finalized skeleton."}
		skeleton.reset_bone_poses()
	var contract := {"version": 1, "coordinate_frame": "asset_root_identity_with_intrinsic_organism_placement",
		"actor_world_transform_included": false, "asset_placement": dna.get("asset_placement", {}).duplicate(true),
		"scope": "Completed rest geometry and skeleton/bind hierarchy",
		"not_claimed": ["Custom tissue shader portability", "Physics collision portability", "Procedural preview animation export", "Full exported rig fidelity without independent parent/rest/bind/topology/weight comparison", "Multi-support stability or gait"]}
	copied.set_meta("asset_export_contract", contract)
	return {"root": copied, "contract": contract}

static func _clean(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			child.free()
		else: _clean(child)
	# Runtime dictionaries may contain packed data/resources not GLTF extras.
	for key: StringName in node.get_meta_list(): node.remove_meta(key)
	node.set_script(null)

static func export_glb(visual: Node3D, path: String) -> Dictionary:
	if path.get_extension().to_lower() != "glb": return {"error": "Creature export requires a .glb destination."}
	var prepared := create_export_root(visual)
	if prepared.has("error"): return prepared
	var document := GLTFDocument.new(); var state := GLTFState.new()
	var error: Error = document.append_from_scene(prepared.root, state)
	if error == OK: error = document.write_to_filesystem(state, path)
	prepared.root.free()
	if error != OK: return {"error": "Creature GLB export failed: " + error_string(error)}
	var sidecar := FileAccess.open(path + ".placement.json", FileAccess.WRITE)
	if sidecar == null: return {"error": "GLB was written, but its placement/scope sidecar could not be created.", "glb_path": path}
	sidecar.store_string(JSON.stringify(prepared.contract, "\t", true, true)); sidecar.close()
	return {"ok": true, "path": path, "contract_path": path + ".placement.json", "contract": prepared.contract}
