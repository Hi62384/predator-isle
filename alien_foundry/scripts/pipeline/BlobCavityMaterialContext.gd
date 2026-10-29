extends RefCounted
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
## Narrow Stage 4 appearance overlay for explicitly authored, contained Blob
## cavities. A cutter identifies exposed tissue, NEVER a skeletal owner.
## The only changed render channel is UV2: host category stays in COLOR.r,
## authored inner category goes in UV2.x, and the geometric blend in UV2.y.
const Volume = preload("res://alien_foundry/scripts/geometry/OrganicVolume.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const PROFILE := "authored_cavity_v1"
const VERSION := 2
const SETTING := "blob_cavity_material_assignment"
const MATERIALS := ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]

static func is_enabled(dna: Dictionary) -> bool:
	return str(dna.get("type", "")) == "Blob" and str(dna.get("settings", {}).get(SETTING, "")) == PROFILE

static func cache_key(final_geometry_key: String) -> String:
	return final_geometry_key + ":" + PROFILE + ":mask_v" + str(VERSION)

static func _closed(reason: String) -> Dictionary:
	return {"version": VERSION, "profile": PROFILE, "trusted": false, "reason": reason, "changes_geometry": false, "changes_binding": false}

static func _prepare_field(dna: Dictionary, geometry: Dictionary) -> Dictionary:
	# These are the same preparation steps as OrganicVolume._build_once, with
	# the ACTUAL budget spacing and the recorded post-lattice repair collars.
	# No field lattice is sampled, repaired, or extracted here.
	var stats: Dictionary = geometry.get("stats", {})
	if not stats.has("cell_size") or not stats.has("spacing_scale"):
		return {"reason": "The final mesh lacks its actual extraction spacing."}
	var quality := clampi(int(geometry.get("quality", dna.get("settings", {}).get("quality", 1))), 0, 2)
	var field := Volume.new()
	field.source_dna = dna
	field.geometry_adjustments = {"thin_features": [], "attachment_collars": [], "lattice_collars": []}
	field.budget_spacing_scale = float(stats.spacing_scale)
	field.regional_noise_gain = stats.get("regional_noise_gains", Volume.REGIONAL_NOISE_GAINS).duplicate()
	field._prepare(dna.get("nodes", []), quality)
	if not field.preparation_errors.is_empty(): return {"reason": "; ".join(field.preparation_errors)}
	field._conform_surface_folds()
	field._configure_grid(quality)
	var actual_step := float(stats.cell_size)
	if absf(field.step - actual_step) > maxf(actual_step * 0.000001, 0.00000001):
		return {"reason": "Reconstructed field spacing disagrees with the final extracted mesh."}
	field._preserve_thin_features()
	field._ensure_growth_attachments(dna.nodes)
	if not field.preparation_errors.is_empty(): return {"reason": "; ".join(field.preparation_errors)}
	field._build_tiles()
	var settings: Dictionary = dna.get("settings", {})
	field.noise.configure(int(dna.get("seed", 1)), maxf(float(settings.get("size", 1.0)), 0.05), float(settings.get("surface_detail", settings.get("detail", 0.5))))
	field._prepare_masks(dna.get("modules", []))
	field._expose_surface_cavities(dna.nodes)
	field._prepare_module_seats(dna.get("modules", []))
	var collars: Array = []
	for mark: Dictionary in geometry.get("geometry_adjustments", {}).get("lattice_collars", []):
		var radii: Array = mark.get("radii", [])
		if radii.size() != 2 or float(radii[0]) != float(radii[1]):
			return {"reason": "A recorded lattice repair cannot be reconstructed exactly."}
		collars.append({"start": Curves.vector(mark.get("start", [])), "end": Curves.vector(mark.get("end", [])), "radius": float(radii[0]), "blend": float(mark.get("blend", 0.0))})
	field._register_lattice_collars(collars)
	return {"field": field}

static func _has_host(mesh: Dictionary, vertex: int, host: int) -> bool:
	var indices: PackedInt32Array = mesh.get("component_indices", PackedInt32Array())
	var weights: PackedFloat32Array = mesh.get("component_weights", PackedFloat32Array())
	if indices.size() >= (vertex + 1) * 4 and weights.size() >= (vertex + 1) * 4:
		for slot in range(vertex * 4, vertex * 4 + 4):
			if indices[slot] == host and weights[slot] > 0.00001: return true
	var owners: PackedInt32Array = mesh.get("component_ids", PackedInt32Array())
	return vertex < owners.size() and owners[vertex] == host

static func _has_positive_provenance(mesh: Dictionary, vertex: int, positive: PackedByteArray) -> bool:
	var indices: PackedInt32Array = mesh.get("component_indices", PackedInt32Array())
	var weights: PackedFloat32Array = mesh.get("component_weights", PackedFloat32Array())
	if indices.size() >= (vertex + 1) * 4 and weights.size() >= (vertex + 1) * 4:
		var found := false
		for slot in range(vertex * 4, vertex * 4 + 4):
			if weights[slot] <= 0.00001: continue
			if indices[slot] < 0 or indices[slot] >= positive.size() or positive[indices[slot]] == 0: return false
			found = true
		return found
	var owners: PackedInt32Array = mesh.get("component_ids", PackedInt32Array())
	return vertex < owners.size() and owners[vertex] >= 0 and owners[vertex] < positive.size() and positive[owners[vertex]] != 0

##217 consumes an independently completed finite qualification, never pending
## porous metadata. This checks identity/completeness, not a new field proof.
static func qualification217_ok(dna: Dictionary, qualification: Variant)->bool:
	if Cavity217.single_enabled(dna):return qualification223_ok(dna,qualification)
	if not Cavity217.enabled(dna) or not qualification is Dictionary:return false
	if not qualification.get("ok") is bool or not qualification.ok or qualification.has("first_failure"):return false
	var cavity_policy: GDScript=Cavity217.policy_for(dna)
	if not Cavity217.text_is(qualification.get("spec_sha256"),cavity_policy.PIN) or not Cavity217.text_is(qualification.get("method"),Cavity217.qualification_method(dna)):return false
	var artifacts: GDScript=load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	if not Cavity217.text_is(qualification.get("geometry_key217"),artifacts.geometry_key(dna,5,Cavity217.DEPENDENCY4)):return false
	var accounting: Variant=qualification.get("accounting")
	if not accounting is Dictionary or not Cavity217.integral(accounting.get("complete_field_calls")) or float(accounting.complete_field_calls)<=0.0 or float(accounting.complete_field_calls)>6971.0 or not Cavity217.integral(accounting.get("owner_locations")) or float(accounting.owner_locations)!=31.0:return false
	if not qualification.get("checks") is Array or qualification.checks.is_empty():return false
	for checked: Variant in qualification.checks:
		if not checked is Dictionary or not checked.get("ok") is bool or not checked.ok:return false
	var cavities: Variant=qualification.get("cavities")
	if not cavities is Array or cavities.size()!=2:return false
	for i: int in range(2):
		var cavity: Variant=cavities[i]
		if not cavity is Dictionary or not Cavity217.text_is(cavity.get("node_id"),Cavity217.IDS[i]) or not cavity.get("mouths") is Array or cavity.mouths.size()!=13:return false
		for key: String in ["shell_f0","shell_f2"]:
			var shell: Variant=cavity.get(key)
			if not shell is Dictionary or not shell.get("ok") is bool or not shell.ok or not Cavity217.integral(shell.get("sample_count")) or float(shell.sample_count)!=177.0:return false
	return true

##223 is explicitly one primary chamber, never a two-void qualification claim.
static func qualification223_ok(dna: Dictionary, qualification: Variant) -> bool:
	if not Cavity217.single_enabled(dna) or not qualification is Dictionary:return false
	if not qualification.get("ok") is bool or not qualification.ok or qualification.has("first_failure"):return false
	var policy: GDScript=Cavity217.policy_for(dna)
	if not Cavity217.text_is(qualification.get("spec_sha256"),policy.PIN) or not Cavity217.text_is(qualification.get("method"),Cavity217.qualification_method(dna)):return false
	var artifacts: GDScript=load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	if not Cavity217.text_is(qualification.get("geometry_key217"),artifacts.geometry_key(dna,5,Cavity217.DEPENDENCY4)):return false
	var accounting: Variant=qualification.get("accounting")
	if not accounting is Dictionary or not Cavity217.integral(accounting.get("complete_field_calls")) or float(accounting.complete_field_calls)<=0.0 or float(accounting.complete_field_calls)>4406.0 or not Cavity217.integral(accounting.get("owner_locations")) or float(accounting.owner_locations)!=13.0:return false
	if not qualification.get("checks") is Array or qualification.checks.is_empty():return false
	for checked: Variant in qualification.checks:
		if not checked is Dictionary or not checked.get("ok") is bool or not checked.ok:return false
	var cavities: Variant=qualification.get("cavities")
	if not cavities is Array or cavities.size()!=1:return false
	var cavity: Variant=cavities[0]
	if not cavity is Dictionary or not Cavity217.text_is(cavity.get("node_id"),"n013") or not cavity.get("mouths") is Array or cavity.mouths.size()!=13:return false
	for key: String in ["shell_f0","shell_f2"]:
		var shell: Variant=cavity.get(key)
		if not shell is Dictionary or not shell.get("ok") is bool or not shell.ok or not Cavity217.integral(shell.get("sample_count")) or float(shell.sample_count)!=177.0:return false
	if not qualification.get("bridge",{}) is Dictionary or not qualification.get("bridge",{}).is_empty():return false
	return true

static func build(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null, qualification217: Dictionary = {}) -> Dictionary:
	if not is_enabled(dna): return _closed("The versioned Blob cavity material assignment is not enabled.")
	var active217: bool=Cavity217.enabled(dna)
	if active217 and not qualification217_ok(dna,qualification217):return _closed("217 requires its matching successful finite qualification, not authored safety flags.")
	# Only OrganicVolume's fused body stream is considered. Explicit Stage 3
	# membranes/fibres are separate detail_meshes; modules are prepared apart.
	# Never recurse into those surfaces merely because they inherit body owners.
	var vertices: PackedVector3Array = geometry.get("vertices", PackedVector3Array())
	var normals: PackedVector3Array = geometry.get("normals", PackedVector3Array())
	var node_ids: PackedStringArray = geometry.get("node_ids", PackedStringArray())
	if vertices.is_empty() or normals.size() != vertices.size() or node_ids.is_empty():
		return _closed("The final body lacks matching positions, normals, or positive component provenance.")
	if active217 and vertices.size()>60000:return _closed("217 provenance exceeds the fixed cumulative solved-edge/vertex cap.")
	var complete_calls217: int=0
	var analytic_filters217: int=0
	var eligible_pairs217: int=0
	var prepared := _prepare_field(dna, geometry)
	if not prepared.has("field"): return _closed(str(prepared.reason))
	var field: RefCounted = prepared.field
	var nodes: Array = dna.get("nodes", [])
	var positive := PackedByteArray(); positive.resize(node_ids.size())
	for node: Dictionary in nodes:
		var index := node_ids.find(str(node.get("id", "")))
		if index >= 0 and str(node.get("kind", "")) != "cavity" and str(node.get("operation", "union")) != "subtract": positive[index] = 1
	var candidates: Array = []
	var ids := PackedStringArray()
	for influence_index in range(field.influences.size()):
		var item: RefCounted = field.influences[influence_index]
		var node: Dictionary = nodes[item.node_index]
		var safety: Dictionary = node.get("porous_growth", {})
		if not item.subtract or item.is_curve or str(node.get("kind", "")) != "cavity": continue
		if active217:
			if str(node.id) not in Cavity217.ids_for(dna) or bool(node.get("surface_opening",false)):continue
		else:
			if bool(node.get("surface_opening", false)) or not bool(safety.get("complete_rim", false)) or not bool(safety.get("back_wall", false)): continue
			if str(safety.get("containment_method", "")) != "contiguous_host_thickness_and_full_inward_shell": continue
		var host_id := str(node.get("surface_grown_host", node.get("parent", "")))
		var host := node_ids.find(host_id)
		var field_host: int = field.node_ids.find(host_id)
		if host < 0 or field_host < 0 or str(node.get("parent", "")) != host_id: continue
		var host_node: Dictionary = nodes[field_host]
		if str(host_node.get("kind", "")) == "cavity" or str(host_node.get("operation", "union")) == "subtract": continue
		ids.append(str(node.id))
		candidates.append({"item": item, "influence": influence_index, "host": host})
	if candidates.is_empty(): return _closed("No explicit finite complete-rim cavity with a verified positive host is eligible.")
	if active217 and (ids!=PackedStringArray(Cavity217.ids_for(dna)) or candidates.size()!=Cavity217.ids_for(dna).size()):return _closed("223 provenance requires exactly its one qualified primary void ID." if Cavity217.single_enabled(dna) else "217 provenance requires exactly its two qualified void IDs.")
	var owners := PackedInt32Array(); owners.resize(vertices.size()); owners.fill(-1)
	var weights := PackedFloat32Array(); weights.resize(vertices.size())
	# 0 unrelated, 1 exposed inner wall, 2 host rim, 3 positive post-cut lip,
	# 4 field/normal mismatch. This is geometric evidence, not bone identity.
	var regions := PackedByteArray(); regions.resize(vertices.size())
	var counts := {"interior": 0, "rim": 0, "lip": 0, "unrelated": 0, "mismatch": 0}
	var step: float = field.step
	for vi in range(vertices.size()):
		if vi % 1024 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		# Component blending can give the containing sac zero weight deep in a
		# body overlap. Verify original positive provenance, not that one host's
		# weight: actual counterfactual subtraction below establishes identity.
		if not _has_positive_provenance(geometry, vi, positive): continue
		var point: Vector3 = vertices[vi]
		var normal: Vector3 = normals[vi].normalized()
		var bucket: PackedInt32Array = field._tile_at(point)
		for ci in range(candidates.size()):
			var candidate: Dictionary = candidates[ci]
			var item: RefCounted = candidate.item
			if not item.bounds.grow(step).has_point(point): continue
			if active217:analytic_filters217+=1
			var distance: float = item.distance(point)
			if absf(distance) > step * 1.25: continue
			if active217:
				if complete_calls217+5>600000 or analytic_filters217>120000:return _closed("217 fixed provenance query cap exceeded.")
				eligible_pairs217+=1;complete_calls217+=2
			var full: float = field._field_value(point, bucket)
			var without_lips: float = field._field_value(point, bucket, true, true, false)
			if without_lips - full > maxf(step * 0.0001, 0.000001):
				weights[vi] = 0.0; owners[vi] = -1; regions[vi] = 3; break
			var without: PackedInt32Array = bucket.duplicate()
			var at := without.find(int(candidate.influence))
			if at < 0: continue
			without.remove_at(at)
			if active217:complete_calls217+=1
			var retained: float = field._field_value(point, without)
			var cut_delta: float = full - retained
			var local: Vector3 = item.inverse_basis * (point - item.position)
			var outward: Vector3 = (item.inverse_basis.transposed() * (local * item.inverse_squared)).normalized()
			var inward_alignment := normal.dot(-outward)
			# A near cutter is not enough: the final surface must actually be
			# made by subtraction, backed by positive tissue, and face the void.
			if absf(full) > step * 0.75 or inward_alignment < 0.15:
				if weights[vi] <= 0.0: regions[vi] = maxi(regions[vi], 4)
				continue
			if retained >= -step * 0.20 or cut_delta <= step * 0.20:
				if weights[vi] <= 0.0: regions[vi] = maxi(regions[vi], 2)
				continue
			var probe := step * 0.40
			if active217:complete_calls217+=2
			var ahead: float = field.sample_signed_distance(point + normal * probe)
			var behind: float = field.sample_signed_distance(point - normal * probe)
			if ahead <= full + probe * 0.10 or behind >= full - probe * 0.10:
				if weights[vi] <= 0.0: regions[vi] = maxi(regions[vi], 4)
				continue
			var depth_width := maxf(step * 1.80, minf(item.radii.x, item.radii.y) * 0.35)
			var amount := smoothstep(step * 0.25, depth_width, -retained)
			amount *= smoothstep(step * 0.20, step * 0.85, cut_delta) * smoothstep(0.15, 0.65, inward_alignment)
			if amount > weights[vi]:
				weights[vi] = amount; owners[vi] = ci; regions[vi] = 1
		match regions[vi]:
			1: counts.interior += 1
			2: counts.rim += 1
			3: counts.lip += 1
			4: counts.mismatch += 1
			_: counts.unrelated += 1
	var result: Dictionary={"version": VERSION, "profile": PROFILE, "trusted": true, "vertex_count": vertices.size(), "cavity_node_ids": ids,
		"vertex_cavities": owners, "weights": weights, "regions": regions, "counts": counts,
		"cell_size": step, "field_lattices_sampled": 0, "changes_geometry": false, "changes_binding": false}
	if active217:
		result["qualification217_identity_verified"]=true
		result["complete_field_calls217"]=complete_calls217
		result["complete_field_cap217"]=600000
		result["analytic_cutter_filters217"]=analytic_filters217
		result["eligible_vertex_cavity_pairs217"]=eligible_pairs217
		result["counts_are_not_authoritative_vertex_totals"]=true
		result["applied"]=false
	return result

static func apply(dna: Dictionary, geometry: Dictionary, context: Dictionary) -> Dictionary:
	if not is_enabled(dna): return {"enabled": false, "changed_vertices": 0}
	if not bool(context.get("trusted", false)) or int(context.get("version", 0)) != VERSION:
		return {"enabled": true, "applied": false, "reason": str(context.get("reason", "Unsupported cavity material context.")), "changed_vertices": 0}
	var vertices: PackedVector3Array = geometry.get("vertices", PackedVector3Array())
	var colors: PackedColorArray = geometry.get("colors", PackedColorArray())
	var source_uv: PackedVector2Array = geometry.get("uvs2", PackedVector2Array())
	var indices: PackedInt32Array = geometry.get("indices", PackedInt32Array())
	var weights: PackedFloat32Array = context.get("weights", PackedFloat32Array()).duplicate()
	var owners: PackedInt32Array = context.get("vertex_cavities", PackedInt32Array())
	if colors.size() != vertices.size() or source_uv.size() != vertices.size() or weights.size() != vertices.size() or owners.size() != vertices.size():
		return {"enabled": true, "applied": false, "reason": "Cavity context does not match the final body's vertex attributes.", "changed_vertices": 0}
	var nodes: Dictionary = {}
	for node: Dictionary in dna.get("nodes", []): nodes[str(node.get("id", ""))] = node
	var target_ids := PackedInt32Array()
	for id: String in context.cavity_node_ids:
		target_ids.append(MATERIALS.find(str(nodes.get(id, {}).get("material", ""))))
	var targets := PackedInt32Array(); targets.resize(vertices.size()); targets.fill(-1)
	for vi in range(vertices.size()):
		if owners[vi] < 0 or owners[vi] >= target_ids.size() or weights[vi] <= 0.00001: weights[vi] = 0.0; continue
		var target := target_ids[owners[vi]]
		var primary := roundi(colors[vi].r * 7.0)
		var secondary := roundi(source_uv[vi].x * 7.0)
		if target < 0 or target == primary or (source_uv[vi].y > 0.00001 and secondary != target): weights[vi] = 0.0; continue
		targets[vi] = target
	# All vertices of a triangle with nonzero cavity amount must carry its
	# SAME secondary category, even at amount zero. Otherwise rounded varying
	# categorical IDs would invent root/chitin/etc between host and cavity.
	# Reject competing third identities rather than silently erasing a blend.
	var guards := PackedInt32Array(); guards.resize(vertices.size()); guards.fill(-1)
	var conflicts := PackedByteArray(); conflicts.resize(vertices.size())
	for base in range(0, indices.size(), 3):
		var target := -1
		for j in range(3):
			var vi := indices[base + j]
			if weights[vi] <= 0.0: continue
			if target >= 0 and target != targets[vi]:
				for k in range(3): conflicts[indices[base + k]] = 1
			target = targets[vi]
		if target < 0: continue
		for j in range(3):
			var vi := indices[base + j]
			if guards[vi] >= 0 and guards[vi] != target: conflicts[vi] = 1
			if source_uv[vi].y > 0.00001 and roundi(source_uv[vi].x * 7.0) != target: conflicts[vi] = 1
			guards[vi] = target
	var rejected := 0
	for base in range(0, indices.size(), 3):
		if conflicts[indices[base]] == 0 and conflicts[indices[base + 1]] == 0 and conflicts[indices[base + 2]] == 0: continue
		for j in range(3):
			var vi := indices[base + j]
			if weights[vi] > 0.0: rejected += 1
			weights[vi] = 0.0
	guards.fill(-1)
	for base in range(0, indices.size(), 3):
		var target := -1
		for j in range(3):
			var vi := indices[base + j]
			if weights[vi] > 0.0: target = targets[vi]
		if target >= 0:
			for j in range(3): guards[indices[base + j]] = target
	var output := source_uv.duplicate()
	var changed := 0; var active := 0; var deep := 0; var blended := 0; var guarded := 0
	for vi in range(vertices.size()):
		if guards[vi] < 0: continue
		output[vi] = Vector2(float(guards[vi]) / 7.0, maxf(source_uv[vi].y, weights[vi]))
		if output[vi] != source_uv[vi]: changed += 1
		if weights[vi] > 0.0:
			active += 1
			if weights[vi] >= 0.999: deep += 1
			else: blended += 1
		else: guarded += 1
	geometry["uvs2"] = output
	return {"enabled": true, "applied": active > 0, "profile": PROFILE, "version": VERSION, "changed_vertices": changed,
		"interior_vertices": active, "full_tissue_vertices": deep, "blended_vertices": blended, "zero_weight_guard_vertices": guarded,
		"conflicting_vertices_rejected": rejected, "changes_geometry": false, "changes_binding": false, "changed_channels": ["uvs2"]}
