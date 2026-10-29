extends RefCounted
## Stage 4 has no geometry creation and no armature dependency. It bakes anatomy-
## aware semantic masks from final positions, normals and region provenance.
## RGBA meanings match the renderer: insertion/growth/exposure/thickness.
const Context = preload("res://alien_foundry/scripts/rigging/AnatomicalSurfaceContext.gd")
const Materials = preload("res://alien_foundry/scripts/rendering/MaterialGenerator.gd")

static func build_context(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null) -> Dictionary:
	var body := _surface_context(dna, geometry, controls)
	if body.has("cancelled"):
		return body
	var details: Array = []
	for detail: Dictionary in geometry.get("detail_meshes", []):
		var context := _surface_context(dna, detail, controls)
		if context.has("cancelled"):
			return context
		details.append(context.values)
	return {"body": body.values, "details": details, "channels": ["attachment", "growth", "fibre_exposure", "relative_thickness"],
		"inputs": ["final_positions", "final_normals", "component_provenance", "anatomical_regions"],
		"additional_shader_inputs": ["macro_occlusion", "bind_coordinates", "tissue_atlas"],
		"changes_geometry": false, "requires_armature": false}

static func _surface_context(dna: Dictionary, mesh: Dictionary, controls: RefCounted) -> Dictionary:
	var vertices: PackedVector3Array = mesh.get("vertices", PackedVector3Array())
	var existing: PackedFloat32Array = mesh.get("authored_surface_context", PackedFloat32Array())
	if existing.size() == vertices.size() * 4 and not existing.is_empty():
		return {"values": existing.duplicate()}
	var ids: PackedStringArray = mesh.get("node_ids", PackedStringArray())
	if ids.is_empty():
		for node: Dictionary in dna.get("nodes", []):
			ids.append(str(node.get("id", "")))
	var source: Array = Context.cache(dna, ids)
	var normals: PackedVector3Array = mesh.get("normals", PackedVector3Array())
	var provenance: PackedInt32Array = mesh.get("component_indices", PackedInt32Array())
	var weights: PackedFloat32Array = mesh.get("component_weights", PackedFloat32Array())
	var owners: PackedInt32Array = mesh.get("component_ids", PackedInt32Array())
	var values := PackedFloat32Array()
	values.resize(vertices.size() * 4)
	for i: int in range(vertices.size()):
		if controls != null and i % 1024 == 0 and controls.is_cancelled():
			return {"cancelled": true}
		var normal: Vector3 = normals[i] if i < normals.size() else Vector3.UP
		var context := Vector4.ZERO
		var total := 0.0
		if provenance.size() >= (i + 1) * 4 and weights.size() >= (i + 1) * 4:
			for j: int in range(4):
				var slot: int = i * 4 + j
				var owner: int = provenance[slot]
				if owner >= 0 and owner < source.size() and weights[slot] > 0.00001:
					context += Context.sample(vertices[i], normal, source[owner]) * weights[slot]
					total += weights[slot]
		if total < 0.00001 and i < owners.size() and owners[i] >= 0 and owners[i] < source.size():
			context = Context.sample(vertices[i], normal, source[owners[i]])
			total = 1.0
		context = context / total if total > 0.00001 else Vector4(0, 0, 0, 1)
		for channel: int in range(4):
			values[i * 4 + channel] = clampf(context[channel], 0.0, 1.0)
	return {"values": values}

static func attach_context(geometry: Dictionary, context: Dictionary) -> void:
	geometry["authored_surface_context"] = context.get("body", PackedFloat32Array())
	var details: Array = context.get("details", [])
	for i: int in range(mini(details.size(), geometry.get("detail_meshes", []).size())):
		geometry.detail_meshes[i]["authored_surface_context"] = details[i]

static func bake(dna: Dictionary, controls: RefCounted = null) -> Dictionary:
	# Material randomness never consumes base/surface/secondary streams.
	if controls != null:
		if controls.is_cancelled():
			return {"cancelled": true}
		controls.set_progress(0.0, "Baking biological tissue fields")
	var material_dna: Dictionary = dna.duplicate(true)
	material_dna["seed"] = int(dna.get("materials", {}).get("palette_seed", dna.get("seed", 1)))
	var result: Dictionary = Materials.prepare_tissue(material_dna, controls)
	if controls != null and not bool(result.get("cancelled", false)):
		controls.set_progress(1.0, "Material fields are ready")
	return result
