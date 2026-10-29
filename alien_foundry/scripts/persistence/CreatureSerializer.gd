class_name CreatureSerializer
extends RefCounted
const HighPreview2=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const HighPreview=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
const SacSurface=preload("res://alien_foundry/scripts/geometry/BlobSacSurface212.gd")
const PositiveGrowth = preload("res://alien_foundry/scripts/geometry/BlobPositiveGrowth206.gd")
const SlabPolicy=preload("res://alien_foundry/scripts/geometry/BlobSlabPolicy210.gd")
const AdaptiveNormal = preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal208.gd")
const EdgeRefinement = preload("res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement204.gd")
const MassReprofileField = preload("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd")
const BodyGroupField = preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const EnvelopeField = preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const GroupField = preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
## Full anatomical DNA, not merely a seed. Generation software may evolve without
## discarding the actual node graph, module deformation, palette, or ancestry.

const FORMAT := "predator-isle-alien-dna"
const FORMAT_VERSION := 1
const DIRECT_FORMAT_VERSION := 2
const RENDER_GENERATION := 2
const MAX_FILE_BYTES := 32 * 1024 * 1024
const TYPES := ["Blob", "Crawler", "Humanoid", "Abomination", "Beast", "Slitherer", "Combination"]
const MATERIALS := ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]
const SHAPE_RANGES := {"width": [0.25, 4.0], "depth": [0.10, 2.0], "ribbing": [0.0, 1.0], "webbing": [0.0, 1.0], "web_bulge": [0.0, 0.6], "web_opening": [0.0, 0.38], "web_start": [0.0, 0.9], "web_end": [0.0, 1.0], "surface_burial": [0.0, 1.5], "squareness": [0.0, 1.0], "carrier_scale": [0.2, 1.0], "sculpt_strength": [0.0, 1.0]}
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const IterationArtifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Lineage = preload("res://alien_foundry/scripts/anatomy/CreatureLineage.gd")
const GroupFinalization = preload("res://alien_foundry/scripts/rigging/BlobSacGroupFinalization.gd")
const GroundPlacement = preload("res://alien_foundry/scripts/pipeline/BlobGroundPlacement.gd")
const DirectPipeline = preload("res://alien_foundry/scripts/pipeline/BlobDirectSurfacePipeline.gd")
const DirectRecipe = preload("res://alien_foundry/scripts/persistence/DirectSurfaceRecipeCodec.gd")

static func save_dna(path: String, dna: Dictionary) -> Dictionary:
	var checked := validate_dna(dna)
	if not checked["ok"]:
		return checked
	if str(dna.get("settings", {}).get("blob_pipeline_mode", "")) == "iterative_v2":
		var canonical: Dictionary = _restore_iterative_recipe(dna)
		if canonical.has("error"): return {"ok": false, "error": canonical.error}
		dna = canonical
	var envelope := {"format": FORMAT, "format_version": DIRECT_FORMAT_VERSION if _direct_enabled(dna) else FORMAT_VERSION, "application": "Predator Isle Alien Foundry", "saved_at_utc": Time.get_datetime_string_from_system(true), "dna": dna}
	var text := JSON.stringify(envelope, "\t", true, true)
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return {"ok": false, "error": "DNA exceeds the 32 MB safety limit."}
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot write this location: " + error_string(FileAccess.get_open_error())}
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "error": "Writing DNA failed: " + error_string(write_error)}
	var renamed := DirAccess.rename_absolute(temp_path, path)
	if renamed != OK:
		return {"ok": false, "error": "Cannot finish saving DNA: " + error_string(renamed)}
	return {"ok": true, "path": path}

static func load_dna(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Cannot read file: " + error_string(FileAccess.get_open_error())}
	if file.get_length() > MAX_FILE_BYTES:
		return {"ok": false, "error": "File exceeds the 32 MB safety limit."}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "error": "Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary:
		return {"ok": false, "error": "Alien DNA must be a JSON object."}
	var envelope: Dictionary = json.data
	var dna: Dictionary
	var file_version := 0
	if envelope.get("format", "") == FORMAT:
		var version: Variant = envelope.get("format_version", 0)
		if not _valid_number(version) or float(version) != float(int(version)) or int(version) not in [FORMAT_VERSION, DIRECT_FORMAT_VERSION]:
			return {"ok": false, "error": "This DNA file uses an unsupported format version."}
		file_version = int(version)
		if not envelope.get("dna") is Dictionary:
			return {"ok": false, "error": "This file does not contain an anatomy description."}
		dna = envelope["dna"]
	else:
		# A direct versioned anatomy graph is useful for tools and exported test cases.
		dna = envelope
	# Enabled plans need an envelope that the old strict v1 loader rejects.
	# A direct graph export is still accepted for legacy/off DNA, not for an
	# extension that an older loader could otherwise silently ignore.
	if _direct_enabled(dna) and file_version != DIRECT_FORMAT_VERSION:
		return {"ok": false, "error": "Direct-surface DNA requires save format version 2; unsupported loaders must reject it."}
	if file_version == DIRECT_FORMAT_VERSION and not _direct_enabled(dna):
		return {"ok": false, "error": "Save format version 2 requires an enabled direct-surface carrier plan."}
	if dna.get("settings") is Dictionary and str(dna.settings.get("blob_pipeline_mode", "")) == "iterative_v2":
		if not _valid_json_value(dna, 0, [400000]): return {"ok": false, "error": "Unsupported or excessive JSON values."}
		var raw_preview226: Dictionary=HighPreview2.validate(dna)
		if not raw_preview226.ok:return raw_preview226
		var raw_preview224: Dictionary=HighPreview.validate(dna)
		if not raw_preview224.ok:return raw_preview224
		var raw_cavity217: Dictionary=Cavity217.validate_declaration(dna)
		if not raw_cavity217.ok:return raw_cavity217
		var raw_surface: Dictionary=SacSurface.validate_declaration(dna)
		if not raw_surface.ok:return raw_surface
		var raw_slab: Dictionary=SlabPolicy.validate(dna)
		if not raw_slab.ok:return raw_slab
		var raw_positive:=PositiveGrowth.validate_declaration(dna)
		if not raw_positive.ok:return raw_positive
		var raw_normal: Dictionary=AdaptiveNormal.validate(dna)
		if not raw_normal.ok:return raw_normal
		var raw_edge: Dictionary=EdgeRefinement.validate(dna)
		if not raw_edge.ok: return raw_edge
		var raw_envelope: Dictionary = EnvelopeField.validate_declaration(dna)
		if not raw_envelope.ok: return raw_envelope
		var raw_body_group: Dictionary = BodyGroupField.validate_declaration(dna)
		if not raw_body_group.ok: return raw_body_group
		var raw_mass_reprofile: Dictionary = MassReprofileField.validate_declaration(dna)
		if not raw_mass_reprofile.ok: return raw_mass_reprofile
		var restored: Dictionary = _restore_iterative_recipe(dna)
		if restored.has("error"): return {"ok": false, "error": restored.error}
		dna = restored
	var checked := validate_dna(dna)
	if not checked["ok"]:
		return checked
	return {"ok": true, "dna": dna}

static func _restore_iterative_recipe(dna: Dictionary) -> Dictionary:
	var restored: Dictionary = IterationArtifacts.geometry_input(dna)
	if restored.has("error"): return restored
	var direct: Dictionary = _restore_direct_recipes(restored)
	if direct.has("error"): return direct
	restored = direct
	if restored.has("pipeline") and not restored.pipeline is Dictionary: return {"error": "Iterative pipeline must be an object."}
	if restored.get("pipeline", {}).get("geometry_dnas") is Array:
		for i in range(restored.pipeline.geometry_dnas.size()):
			if not restored.pipeline.geometry_dnas[i] is Dictionary: return {"error": "Invalid iterative geometry snapshot."}
			var snapshot: Dictionary = IterationArtifacts.geometry_input(restored.pipeline.geometry_dnas[i])
			if snapshot.has("error"): return snapshot
			snapshot = _restore_direct_recipes(snapshot)
			if snapshot.has("error"): return snapshot
			restored.pipeline.geometry_dnas[i] = snapshot
	return restored

static func validate_dna(dna: Dictionary) -> Dictionary:
	# Preserve every valid JSON field, including provenance and future optional
	# metadata. Reject unsupported values rather than silently stringify objects.
	if not _valid_json_value(dna, 0, [400000]):
		return {"ok": false, "error": "DNA contains unsupported, non-finite, or excessively nested JSON values."}
	if int(dna.get("version", 0)) != 1:
		return {"ok": false, "error": "Unsupported anatomy version; expected version 1."}
	var render_generation: Variant = dna.get("render_generation", 1)
	if not _valid_number(render_generation) or float(render_generation) != float(RENDER_GENERATION):
		return {"ok": false, "error_code": "incompatible_render_generation", "error": "This DNA belongs to a different anatomy-asset generation. Pre-redesign draft faces are incompatible with the current cranial-shell library, so this file was not altered or reconstructed. Generate a new organism with its original type, seed and settings, then save it again; the appearance will differ."}
	var lineage_validation := Lineage.validate_source(dna)
	if not lineage_validation["ok"]:
		return lineage_validation
	var seed_value: Variant = dna.get("seed")
	if not (seed_value is int or seed_value is float) or not is_finite(float(seed_value)):
		return {"ok": false, "error": "Missing or invalid procedural seed."}
	if not str(dna.get("type", "")) in TYPES:
		return {"ok": false, "error": "Unknown creature category."}
	for key in ["nodes", "connections", "modules", "ancestry"]:
		if not dna.get(key) is Array:
			return {"ok": false, "error": "Missing or invalid anatomical array: " + key}
	if not dna.get("settings") is Dictionary or not dna.get("materials") is Dictionary:
		return {"ok": false, "error": "Missing settings or material configuration."}
	if dna.has("direct_surface_carriers") and not dna.direct_surface_carriers is Array:
		return {"ok": false, "error": "Direct-surface carrier plans must be an array."}
	if _direct_enabled(dna) and (str(dna.get("type", "")) != "Blob" or str(dna.settings.get("blob_pipeline_mode", "")) != "iterative_v2"):
		return {"ok": false, "error": "Direct-surface carriers require the versioned iterative Blob pipeline."}
	var preview226_restored: Dictionary=HighPreview2.validate(dna)
	if not preview226_restored.ok:return preview226_restored
	var preview224_restored: Dictionary=HighPreview.validate(dna)
	if not preview224_restored.ok:return preview224_restored
	var cavity217_restored: Dictionary=Cavity217.validate_restored(dna)
	if not cavity217_restored.ok:return cavity217_restored
	var surface_declaration: Dictionary=SacSurface.validate_declaration(dna)
	if not surface_declaration.ok:return surface_declaration
	var positive_declaration:=PositiveGrowth.validate(dna)
	if not positive_declaration.ok:return positive_declaration
	var slab_declaration: Dictionary=SlabPolicy.validate(dna)
	if not slab_declaration.ok:return slab_declaration
	var normal_declaration: Dictionary=AdaptiveNormal.validate(dna)
	if not normal_declaration.ok:return normal_declaration
	var edge_declaration: Dictionary=EdgeRefinement.validate(dna)
	if not edge_declaration.ok: return edge_declaration
	var envelope_declaration: Dictionary = EnvelopeField.validate(dna)
	if not envelope_declaration.ok: return envelope_declaration
	var body_group_declaration: Dictionary = BodyGroupField.validate(dna)
	if not body_group_declaration.ok: return body_group_declaration
	var mass_reprofile_declaration: Dictionary = MassReprofileField.validate(dna)
	if not mass_reprofile_declaration.ok: return mass_reprofile_declaration
	var volume_declaration: Dictionary = preload("res://alien_foundry/scripts/anatomy/BlobBaseVolumeDevelopment.gd").validate_declaration(dna)
	if not bool(volume_declaration.get("ok", false)): return volume_declaration
	if str(dna.settings.get("blob_pipeline_mode", "")) == "iterative_v2":
		var body_mode: Dictionary = preload("res://alien_foundry/scripts/anatomy/BlobCompactBody.gd").selection(dna.settings)
		if body_mode.has("error"): return {"ok": false, "error": body_mode.error}
		var identity_choice: Variant = dna.settings.get("blob_identity_profile", "foundation_171")
		if not identity_choice is String or identity_choice not in ["foundation_171", "seeded_v1", "positive_sacs_v1"]:
			return {"ok": false, "error": "Unsupported Blob identity profile."}
		var detail_mode: Dictionary = preload("res://alien_foundry/scripts/anatomy/BlobSecondaryTendonDetail.gd").validate(dna.settings)
		if detail_mode.has("error"): return {"ok": false, "error": detail_mode.error}
	if not dna.get("budget") is Dictionary:
		return {"ok": false, "error": "Missing anatomy complexity budget."}
	for budget_key in ["nodes", "modules", "bones"]:
		if not _valid_number(dna["budget"].get(budget_key)) or float(dna["budget"][budget_key]) <= 0.0:
			return {"ok": false, "error": "Invalid anatomy complexity budget."}
	if int(dna["budget"]["nodes"]) > 512 or int(dna["budget"]["modules"]) > 256 or int(dna["budget"]["bones"]) > 512:
		return {"ok": false, "error": "Anatomy complexity budget exceeds safe reconstruction limits."}
	for setting_key in ["size", "irregularity", "growth_density", "appendage_density", "surface_detail", "uncanny_features", "quality"]:
		if not _valid_number(dna["settings"].get(setting_key)):
			return {"ok": false, "error": "Invalid generation setting: " + setting_key}
	if dna["nodes"].is_empty() or dna["nodes"].size() > 512 or dna["modules"].size() > 256 or dna["connections"].size() > 1024:
		return {"ok": false, "error": "Anatomy is empty or exceeds safe reconstruction budgets."}
	var ids := {}
	for item in dna["nodes"]:
		if not item is Dictionary:
			return {"ok": false, "error": "Anatomy contains a non-object node."}
		var id := str(item.get("id", ""))
		if id.is_empty() or ids.has(id):
			return {"ok": false, "error": "Anatomy node identifiers are missing or duplicated."}
		ids[id] = item
		if not str(item.get("kind", "")) in ["mass", "curve", "cavity"]:
			return {"ok": false, "error": "Anatomy contains an unsupported geometry kind."}
		for field in ["position", "size"]:
			if not _valid_vector(item.get(field)):
				return {"ok": false, "error": "Invalid or non-finite node " + field + "."}
		if item.has("rotation") and not _valid_vector(item["rotation"]):
			return {"ok": false, "error": "Invalid anatomical rotation."}
		if item.has("growth_origin") and not _valid_vector(item["growth_origin"]):
			return {"ok": false, "error": "Invalid anatomical growth origin."}
		if item.has("growth_behavior") and item["growth_behavior"] not in ["swelling", "elongated", "correlated_branch"]:
			return {"ok": false, "error": "Invalid anatomical growth behavior."}
		if item.has("surface_opening") and not item["surface_opening"] is bool:
			return {"ok": false, "error": "Surface opening must be a boolean."}
		if item.has("normal") and (not _valid_vector(item["normal"]) or _vector_length_squared(item["normal"]) < 0.000001):
			return {"ok": false, "error": "Invalid anatomical surface normal."}
		for reference_key in ["cavity_id", "membrane_to"]:
			if item.has(reference_key) and (not item[reference_key] is String or item[reference_key].length() > 512):
				return {"ok": false, "error": "Invalid anatomical reference: " + reference_key}
		if not item.get("shape", {}) is Dictionary:
			return {"ok": false, "error": "Invalid anatomical shape parameters."}
		for shape_key in item.get("shape", {}):
			var shape_value: Variant = item["shape"][shape_key]
			if shape_key == "hanging_tissue":
				if not Graph.HangingTissue.valid_host(dna, item):
					return {"ok": false, "error": "Invalid versioned Blob hanging tissue."}
			elif shape_key == "hanging_root_version":
				if not Graph.HangingRoot.valid_host(dna, item):
					return {"ok": false, "error": "Invalid versioned Blob hanging root."}
			elif shape_key == "grown_envelope":
				if not Graph.GrownField.valid_host(dna,item):
					return {"ok":false,"error":"Invalid versioned Blob grown envelope."}
			elif shape_key == "grown_contact_version":
				if not Graph.GrownContact.valid_host(dna,item):
					return {"ok":false,"error":"Invalid versioned Blob grown contact."}
			elif shape_key == "mantle_envelope":
				if not _valid_mantle_host(dna,item,false) or not Graph.MantleField.valid_descriptor(shape_value):
					return {"ok":false,"error":"Invalid versioned Blob mantle envelope."}
			elif shape_key == "mantle_buttress_version":
				if not _valid_mantle_host(dna,item,true) or not _valid_number(shape_value) or float(shape_value)!=1.0:
					return {"ok":false,"error":"Invalid versioned Blob mantle buttress."}
			elif shape_key == "loaded_contact_profile":
				if not _valid_loaded_primary(dna, item) or not _valid_loaded_contact_profile(shape_value):
					return {"ok": false, "error": "Invalid versioned Blob loaded-contact profile."}
			elif shape_key == "loaded_upper_floor_off":
				if not _valid_loaded_primary(dna, item) or str(item.get("role", "")) != "core" or not _valid_number(shape_value) or float(shape_value) != 1.0:
					return {"ok": false, "error": "Invalid Blob elevated-core floor marker."}
			elif shape_key == PositiveGrowth.KEY:
				if not PositiveGrowth._context_ok(shape_value): return {"ok":false,"error":"Invalid206 stage-local positive context descriptor."}
			elif shape_key == MassReprofileField.KEY:
				if not MassReprofileField.descriptor_ok(shape_value): return {"ok": false,"error": "Invalid203 mass reprofile descriptor."}
			elif shape_key == BodyGroupField.KEY:
				if not BodyGroupField.descriptor_ok(shape_value): return {"ok": false,"error": "Invalid202 body group descriptor."}
			elif shape_key == EnvelopeField.KEY:
				if not EnvelopeField.descriptor_ok(shape_value): return {"ok": false,"error": "Invalid201 shared envelope descriptor."}
			elif shape_key == GroupField.KEY:
				if not GroupField.descriptor_ok(shape_value): return {"ok": false,"error": "Invalid shared sac group descriptor."}
			elif shape_key == "surface_follow":
				if not shape_value is bool:
					return {"ok": false, "error": "Surface-follow shape control must be a boolean."}
			elif shape_key in ["geometry","profile","attachment"]:
				var allowed: Array=["detail"] if shape_key=="geometry" else (["fascicle","muscle_belly","fascia","digit","branch","tendril"] if shape_key=="profile" else ["root","both"])
				if not shape_value is String or shape_value not in allowed:
					return {"ok":false,"error":"Invalid detail-layer shape mode: "+str(shape_key)}
			elif shape_key=="web_height_grid":
				if not _valid_web_grid(shape_value):
					return {"ok":false,"error":"Web height grid must be a bounded 5×5 lattice with zero border."}
			elif shape_key in ["width_profile","depth_profile"]:
				if not shape_value is Array or shape_value.size()<1 or shape_value.size()>64:
					return {"ok":false,"error":"Invalid detail cross-section profile."}
				for factor in shape_value:
					if not _valid_number(factor) or float(factor)<0.1 or float(factor)>4.0:
						return {"ok":false,"error":"Detail cross-section factor outside safe range."}
			elif not _valid_number(shape_value):
				return {"ok": false, "error": "Invalid anatomical shape value: " + str(shape_key)}
			elif SHAPE_RANGES.has(shape_key):
				var limits: Array = SHAPE_RANGES[shape_key]
				if float(shape_value) < float(limits[0]) or float(shape_value) > float(limits[1]):
					return {"ok": false, "error": "Anatomical shape control outside safe range: " + str(shape_key)}
		var shape: Dictionary = item.get("shape", {})
		if shape.get("attachment", "both") == "root" and shape.get("profile", "") not in ["digit", "tendril"]:
			return {"ok": false, "error": "Only digit or tendril profiles may have a free tip and root-only attachment."}
		if shape.has("web_start") or shape.has("web_end"):
			if float(shape.get("web_end", 0.79)) < float(shape.get("web_start", 0.16)) + 0.05 - 0.000001:
				return {"ok": false, "error": "Membrane interval must cover at least five percent of its supporting curve."}
		if not item.get("deformation", {}) is Dictionary or not item.get("joints", {}) is Dictionary:
			return {"ok": false, "error": "Invalid anatomical deformation or joint configuration."}
		for scalar in item.get("deformation", {}):
			if not _valid_number(item["deformation"][scalar]):
				return {"ok": false, "error": "Invalid anatomical deformation parameter."}
		if not item.get("points", []) is Array or not item.get("radii", []) is Array:
			return {"ok": false, "error": "Curve points and radii must be arrays."}
		if not str(item.get("material", "flesh")) in MATERIALS:
			return {"ok": false, "error": "Unsupported tissue material."}
		if str(item.get("kind", "")) == "curve":
			if item.get("points", []).size() < 2 or item.get("radii", []).size() != item.get("points", []).size():
				return {"ok": false, "error": "Curve points and radii do not match."}
			for radius_value in item.get("radii", []):
				if not _valid_number(radius_value) or float(radius_value) <= 0.0:
					return {"ok": false, "error": "Invalid curve radius."}
		for scalar in ["radius", "blend", "noise"]:
			if item.has(scalar) and not _valid_number(item[scalar]):
				return {"ok": false, "error": "Invalid anatomical scalar: " + scalar}
		if item.get("points", []) is Array:
			if item.get("points", []).size() > 128:
				return {"ok": false, "error": "Curve exceeds the safe point budget."}
			for point in item.get("points", []):
				if not _valid_vector(point):
					return {"ok": false, "error": "Invalid curve point."}
	for item in dna["nodes"]:
		var parent := str(item.get("parent", ""))
		if not parent.is_empty() and not ids.has(parent):
			return {"ok": false, "error": "Anatomy contains a missing parent reference."}
		for reference_key in ["cavity_id", "membrane_to"]:
			var target: String = item.get(reference_key, "")
			if target.is_empty():
				continue
			if not ids.has(target) or target == str(item["id"]):
				return {"ok": false, "error": "Missing or self-referencing anatomical " + reference_key + "."}
			if reference_key == "cavity_id" and ids[target].get("kind", "") != "cavity":
				return {"ok": false, "error": "Aperture rim must reference a cavity."}
			if reference_key == "membrane_to" and (ids[target].get("kind", "") != "curve" or (ids[target].get("role", "") != "tendon" and ids[target].get("shape",{}).get("geometry","")!="detail")):
				return {"ok": false, "error": "Membrane must reference a supporting tendon."}
	for connection in dna["connections"]:
		if not connection is Dictionary or not ids.has(str(connection.get("from", ""))) or not ids.has(str(connection.get("to", ""))):
			return {"ok": false, "error": "Invalid anatomical connection."}
	for module in dna["modules"]:
		if not module is Dictionary or not ids.has(str(module.get("parent", ""))) or not module.get("deformation", {}) is Dictionary:
			return {"ok": false, "error": "Invalid anatomical module."}
		for flag in ["full_shell", "surface_mount"]:
			if module.has(flag) and not module[flag] is bool:
				return {"ok": false, "error": "Invalid cranial-shell flag: " + flag}
		if module.has("shell_surface_offset") and (not _valid_number(module["shell_surface_offset"]) or float(module["shell_surface_offset"]) < 0.0 or float(module["shell_surface_offset"]) > 0.6):
			return {"ok": false, "error": "Invalid cranial-shell surface offset."}
		if module.has("mounting") and (not module["mounting"] is String or module["mounting"].length() > 128):
			return {"ok": false, "error": "Invalid anatomical mounting mode."}
		for vector_key in ["position", "normal", "up", "scale"]:
			if not _valid_vector(module.get(vector_key)):
				return {"ok": false, "error": "Invalid module attachment " + vector_key + "."}
		for scalar in module.get("deformation", {}):
			if not _valid_number(module["deformation"][scalar]):
				return {"ok": false, "error": "Invalid module deformation."}
	var placement_check := GroundPlacement.validate_declaration(dna)
	if not bool(placement_check.get("ok", false)): return placement_check
	var graph_check: Dictionary = Graph.validate(dna)
	if not graph_check.get("valid", false):
		return {"ok": false, "error": "Invalid anatomy graph: " + str(graph_check.get("errors", []))}
	if dna.has("biological_blueprint") or str(dna.settings.get("blob_pipeline_mode", "")) == "iterative_v2":
		var recipe_check: Dictionary = IterationArtifacts.decode_geometry_recipe(dna)
		if recipe_check.has("error"): return {"ok": false, "error": recipe_check.error}
		var biology: Dictionary = Blueprint.validate(dna)
		if not bool(biology.get("ok", false)): return biology
	var direct_selection: Dictionary = DirectPipeline.selection(dna)
	if not direct_selection.ok: return direct_selection
	var group_check: Dictionary = GroupField.validate(dna)
	if not bool(group_check.get("ok",false)): return group_check
	if dna.has("pipeline"):
		return _validate_pipeline(dna)
	return {"ok": true}

static func _validate_pipeline(dna: Dictionary) -> Dictionary:
	# Stage snapshots are reconstruction inputs, not optional descriptive
	# metadata. Reject malformed/newer snapshots without replacing their DNA.
	var pipeline: Variant = dna.pipeline
	if not pipeline is Dictionary or str(dna.type) != "Blob":
		return {"ok": false, "error": "Invalid staged creature data; only Blob supports this pipeline."}
	if _valid_number(pipeline.get("version")) and float(pipeline.version) == 2.0:
		return _validate_iterative_pipeline(dna)
	if not _valid_number(pipeline.get("version")) or float(pipeline.version) != 1.0:
		return {"ok": false, "error": "Unsupported staged creature version. The saved anatomy was not altered."}
	if pipeline.get("stage_order") != ["base_anatomy", "surface_geometry", "secondary_structures", "materials"]:
		return {"ok": false, "error": "The saved creature does not preserve the required stage order."}
	for key: String in ["base_dna", "surface_dna"]:
		var snapshot: Variant = pipeline.get(key)
		if not snapshot is Dictionary or snapshot.has("pipeline"):
			return {"ok": false, "error": "The saved creature is missing a valid " + key + " intermediate."}
		if snapshot.get("type") != "Blob" or snapshot.get("seed") != dna.seed:
			return {"ok": false, "error": "The saved " + key + " intermediate belongs to a different organism."}
		var checked: Dictionary = validate_dna(snapshot)
		if not bool(checked.get("ok", false)):
			return {"ok": false, "error": "Invalid " + key + " intermediate: " + str(checked.get("error", "Unknown validation error."))}
	return {"ok": true}

static func _validate_iterative_pipeline(dna: Dictionary) -> Dictionary:
	var pipeline: Dictionary = dna.pipeline
	var expected_recipe_contract: int = 2 if _direct_enabled(dna) else 1
	var recipe_contract: Variant = pipeline.get("recipe_contract_version", 0)
	if str(pipeline.get("mode", "")) != "iterative_v2" or not _valid_number(recipe_contract) or float(recipe_contract) != float(expected_recipe_contract) or pipeline.get("stage_order") != IterationArtifacts.IDS:
		return {"ok": false, "error": "Unsupported iterative pipeline contract; saved anatomy was not altered."}
	if not pipeline.get("geometry_dnas") is Array or pipeline.geometry_dnas.size() != 6:
		return {"ok": false, "error": "An iterative save must preserve all six geometry inputs."}
	var prior_features := {}
	var prior_refs := {}
	var prior_direct_refs := {}
	var prior_carriers := {}
	var final_carriers: Dictionary = _direct_carrier_signatures(dna)
	for i in range(6):
		var snapshot: Variant = pipeline.geometry_dnas[i]
		if not snapshot is Dictionary or snapshot.has("pipeline") or snapshot.get("type") != "Blob" or snapshot.get("seed") != dna.seed:
			return {"ok": false, "error": "Invalid or mismatched iterative geometry snapshot."}
		var checked: Dictionary = validate_dna(snapshot)
		if not bool(checked.get("ok", false)): return {"ok": false, "error": "Invalid iteration %s: %s" % [i + 1, checked.get("error", "")]}
		if not snapshot.get("metadata") is Dictionary or int(snapshot.metadata.get("iteration_index", 0)) != i + 1:
			return {"ok": false, "error": "Iterative geometry snapshot order is invalid."}
		if snapshot.biological_blueprint.organism_id != dna.biological_blueprint.organism_id:
			return {"ok": false, "error": "Iterative snapshot biological namespace changed."}
		var current: Dictionary = _iterative_registry_signature(snapshot.biological_blueprint)
		var current_carriers: Dictionary = _direct_carrier_signatures(snapshot)
		for carrier_id: String in prior_carriers:
			if not current_carriers.has(carrier_id) or current_carriers[carrier_id] != prior_carriers[carrier_id]: return {"ok": false, "error": "A persistent direct-surface carrier recipe or identity changed or vanished between iterations."}
		for carrier_id: String in current_carriers:
			if not final_carriers.has(carrier_id) or final_carriers[carrier_id] != current_carriers[carrier_id]: return {"ok": false, "error": "Final anatomy lost or changed a persistent direct-surface carrier."}
		prior_carriers = current_carriers
		var final_registry: Dictionary = _iterative_registry_signature(dna.biological_blueprint)
		for id: String in prior_features:
			if not current.has(id): return {"ok": false, "error": "A declared biological identity vanished in a later iteration."}
		for id: String in current:
			if not final_registry.has(id) or current[id] != final_registry[id]:
				return {"ok": false, "error": "Persistent biological identity changed between saved iterations."}
			var feature: Dictionary = Blueprint.feature(snapshot.biological_blueprint, id)
			var final_feature: Dictionary = Blueprint.feature(dna.biological_blueprint, id)
			var refs: Array = feature.geometry_refs.node_ids
			for old_ref in prior_refs.get(id, []):
				if old_ref not in refs: return {"ok": false, "error": "An authored biological carrier reference vanished in a later iteration."}
			for ref in refs:
				if ref not in final_feature.geometry_refs.node_ids: return {"ok": false, "error": "Final blueprint lost a biological carrier reference."}
			prior_refs[id] = refs.duplicate()
			var direct_refs: Array = _direct_ref_keys(feature)
			var final_direct_refs: Array = _direct_ref_keys(final_feature)
			for old_ref: String in prior_direct_refs.get(id, []):
				if old_ref not in direct_refs: return {"ok": false, "error": "A persistent direct-surface part reference vanished between iterations."}
			for ref: String in direct_refs:
				if ref not in final_direct_refs: return {"ok": false, "error": "Final blueprint lost a direct-surface part reference."}
			prior_direct_refs[id] = direct_refs
		prior_features = current
	if prior_carriers.size() != final_carriers.size(): return {"ok": false, "error": "Final direct-surface plan differs from the preserved completed geometry input."}
	var direct_manifest: Dictionary = {}
	if DirectPipeline.enabled(dna) or DirectPipeline.Generalized.requested(dna):
		var direct_plan: Dictionary = DirectPipeline.validate_plans({"final_dna": dna, "geometry_dnas": pipeline.geometry_dnas})
		if not direct_plan.ok: return direct_plan
	if DirectPipeline.Generalized.requested(dna) and not DirectPipeline.enabled(dna) and pipeline.has("direct_surface_artifacts"):
		return {"ok": false, "error": "No-target vascular policy cannot claim direct surface artifacts."}
	if DirectPipeline.enabled(dna):
		direct_manifest = DirectPipeline.validate_manifest(dna, pipeline.get("direct_surface_artifacts"))
		if not direct_manifest.ok: return direct_manifest
	if GroundPlacement.enabled(dna):
		var reference_key := ""
		for i in range(6):
			if not pipeline.geometry_dnas[i] is Dictionary: return {"ok": false, "error": "Invalid placement reference snapshot."}
			reference_key = IterationArtifacts.geometry_key(pipeline.geometry_dnas[i], i + 1, reference_key)
		if DirectPipeline.enabled(dna): reference_key = str(direct_manifest.geometry_key)
		var placement_check := GroundPlacement.validate_record(dna.get("asset_placement"), int(dna.settings.quality), reference_key)
		if not bool(placement_check.get("ok", false)): return placement_check
	if IterationArtifacts.geometry_key(dna, 6) != IterationArtifacts.geometry_key(pipeline.geometry_dnas[5], 6):
		return {"ok": false, "error": "Final anatomy differs from the preserved completed geometry input."}
	if GroupFinalization.enabled(dna) or dna.has("group_finalization"):
		var group_reference_key := ""
		for i in range(6): group_reference_key = IterationArtifacts.geometry_key(pipeline.geometry_dnas[i],i+1,group_reference_key)
		var group_record: Dictionary = GroupFinalization.validate_record(dna,group_reference_key)
		if not bool(group_record.get("ok",false)): return group_record
	return {"ok": true}

static func _iterative_registry_signature(blueprint: Dictionary) -> Dictionary:
	var identities := {}
	for item: Dictionary in blueprint.features:
		# Immutable identity is separate from stage-grown carrier references,
		# children, realization state and later detail/material instructions.
		identities[str(item.id)] = DirectRecipe.typed_key({"id": str(item.id), "type": str(item.type),
			"parent_id": str(item.parent_id), "created_stage": int(item.created_stage), "stream_id": str(item.stream_id)})
	return identities

static func _direct_enabled(dna: Dictionary) -> bool:
	return dna.get("direct_surface_carriers") is Array and not dna.direct_surface_carriers.is_empty()

static func _restore_direct_recipes(dna: Dictionary) -> Dictionary:
	if not dna.has("direct_surface_carriers"): return dna
	if not dna.direct_surface_carriers is Array: return {"error": "Direct-surface carrier plans must be an array."}
	for carrier in dna.direct_surface_carriers:
		if not carrier is Dictionary: return {"error": "Invalid direct-surface carrier record."}
		var decoded: Dictionary = DirectRecipe.decode(carrier.get("recipe"), carrier.get("numeric_recipe"))
		if not decoded.get("ok", false): return {"error": decoded.get("error", "Invalid exact direct-surface recipe.")}
		carrier["recipe"] = decoded.recipe
		carrier["numeric_recipe"] = DirectRecipe.seal(decoded.recipe).numeric_recipe
		for key: String in ["schema_version", "adapter_version", "created_stage"]:
			var value: Variant = carrier.get(key)
			if _valid_number(value) and float(value) == float(int(value)): carrier[key] = int(value)
	return dna

static func _direct_ref_keys(feature: Dictionary) -> Array:
	var keys: Array = []
	for ref: Dictionary in feature.geometry_refs.get("direct_surface_parts", []): keys.append(JSON.stringify([str(ref.carrier_id), str(ref.part_id)]))
	keys.sort()
	return keys

static func _direct_carrier_signatures(dna: Dictionary) -> Dictionary:
	var signatures := {}
	for carrier: Dictionary in dna.get("direct_surface_carriers", []):
		var identity: Dictionary = carrier.duplicate(true)
		identity.erase("recipe"); identity.erase("numeric_recipe")
		identity["recipe_key"] = DirectRecipe.canonical_key(carrier.recipe, carrier.numeric_recipe)
		# JSON transports metadata enum/limit numbers as floats. Their small,
		# validated values compare canonically; consumed recipe numbers above
		# remain strictly typed and retain exact i64/IEEE754 bits.
		signatures[str(carrier.carrier_id)] = DirectRecipe.typed_key(_transport_metadata(identity))
	return signatures

static func _transport_metadata(value: Variant) -> Variant:
	if value is Dictionary:
		var output := {}
		for key: String in value: output[key] = _transport_metadata(value[key])
		return output
	if value is Array:
		var output: Array = []
		for child in value: output.append(_transport_metadata(child))
		return output
	if value is int or value is float: return float(value)
	return value

static func _valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component)) > 10000.0:
			return false
	return true

static func _valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 10000.0

static func _vector_length_squared(value: Array) -> float:
	return float(value[0]) * float(value[0]) + float(value[1]) * float(value[1]) + float(value[2]) * float(value[2])

static func _valid_json_value(value: Variant, depth: int, remaining: Array) -> bool:
	remaining[0] -= 1
	if depth > 64 or remaining[0] < 0:
		return false
	if value == null or value is bool:
		return true
	if value is int or value is float:
		return is_finite(float(value))
	if value is String:
		return value.length() <= 1024 * 1024
	if value is Array:
		for child in value:
			if not _valid_json_value(child, depth + 1, remaining):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or key.length() > 4096 or not _valid_json_value(value[key], depth + 1, remaining):
				return false
		return true
	return false

static func _valid_mantle_host(dna: Dictionary, item: Dictionary, buttress: bool) -> bool:
	return Graph.MantleField.valid_host(dna,item,buttress)

static func _valid_loaded_primary(dna: Dictionary, item: Dictionary) -> bool:
	# New markers are explicit Stage-1 Blob primary-shape data, never a
	# general escape hatch for arbitrary nested shape dictionaries.
	if str(dna.get("type", "")) != "Blob" or str(item.get("kind", "")) != "mass": return false
	if str(item.get("role", "")) not in ["core", "lobe"] or str(item.get("operation", "union")) != "union": return false
	var stage: Variant = item.get("pipeline_stage")
	if not _valid_number(stage) or float(stage) != 1.0: return false
	var points: Variant = item.get("points", [])
	if not points is Array or not points.is_empty(): return false
	var shape: Dictionary = item.get("shape", {})
	if shape.get("geometry", "") != "": return false
	var squareness: Variant = shape.get("squareness", 0.0)
	return _valid_number(squareness) and float(squareness) == 0.0

static func _valid_loaded_contact_profile(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4: return false
	for key in value:
		if key not in ["version", "axis", "compression", "spread"]: return false
	if not _valid_number(value.get("version")) or float(value.version) != 1.0: return false
	if not _valid_vector(value.get("axis")) or absf(_vector_length_squared(value.axis) - 1.0) > 0.0001: return false
	if not _valid_number(value.get("compression")) or not _valid_number(value.get("spread")): return false
	return float(value.compression) >= 0.0 and float(value.compression) <= 0.18 and float(value.spread) >= 0.0 and float(value.spread) <= 0.20

static func _valid_web_grid(value: Variant) -> bool:
	if not value is Array or value.size()!=5: return false
	for row in range(5):
		if not value[row] is Array or value[row].size()!=5: return false
		for column in range(5):
			var height: Variant=value[row][column]
			if not _valid_number(height) or float(height)<-0.25 or float(height)>0.35: return false
			if (row==0 or row==4 or column==0 or column==4) and float(height)!=0.0: return false
	return true
