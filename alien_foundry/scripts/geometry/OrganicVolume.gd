class_name OrganicVolume
extends RefCounted
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
## Universal continuous organism builder. All mutable state belongs to one job.
## build() is worker-thread safe: packed arrays in, packed arrays out, no Nodes.
const SacSurface=preload("res://alien_foundry/scripts/geometry/BlobSacSurface212.gd")
const PositiveGrowth = preload("res://alien_foundry/scripts/geometry/BlobPositiveGrowth206.gd")
const AdaptiveNormal = preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal207.gd")
const BoundedNormal = preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal208.gd")
const BoundedEdge = preload("res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement208.gd")
const EdgeRefinement = preload("res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement204.gd")
const MassReprofileField = preload("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd")
const BodyGroupField = preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const EnvelopeField = preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const GroupQualification = preload("res://alien_foundry/scripts/geometry/BlobSacGroupQualification.gd")
const GroupField = preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
const SDF = preload("res://alien_foundry/scripts/geometry/SDFOperations.gd")
const NoiseField = preload("res://alien_foundry/scripts/geometry/NoiseGenerator.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const SlabPolicy=preload("res://alien_foundry/scripts/geometry/BlobSlabPolicy210.gd")
const HighPreview2=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const HighPilot2=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPilot226.gd")
const SlabPass2=preload("res://alien_foundry/scripts/geometry/BlobRectilinearPass226.gd")
const HighPreview=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const HighPilot=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPilot224.gd")
const SlabPilot=preload("res://alien_foundry/scripts/geometry/BlobSlabPilot210.gd")
const SlabGrid=preload("res://alien_foundry/scripts/geometry/BlobRectilinearGrid210.gd")
const SlabExtractor=preload("res://alien_foundry/scripts/geometry/BlobRectilinearExtractor210.gd")
const SlabEdge=preload("res://alien_foundry/scripts/geometry/BlobSlabEdge210.gd")
const Connectivity = preload("res://alien_foundry/scripts/geometry/FieldConnectivity.gd")
const Extractor = preload("res://alien_foundry/scripts/geometry/MeshExtractor.gd")
const Tendons = preload("res://alien_foundry/scripts/geometry/TendonGeometry.gd")
const BlobPatchField = preload("res://alien_foundry/scripts/geometry/BlobPorousPatchField.gd")
const BlobLoadedPressure = preload("res://alien_foundry/scripts/geometry/BlobLoadedPressureField.gd")
const BlobHangingTissue = preload("res://alien_foundry/scripts/geometry/BlobHangingTissueField.gd")
const BlobHangingRoot = preload("res://alien_foundry/scripts/geometry/BlobHangingRootField.gd")
const BlobGrownContact = preload("res://alien_foundry/scripts/geometry/BlobGrownContactField.gd")
const BlobGrown = preload("res://alien_foundry/scripts/geometry/BlobGrownEnvelopeField.gd")
const BlobMantle = preload("res://alien_foundry/scripts/geometry/BlobMantleField.gd")
const BlobButtress = preload("res://alien_foundry/scripts/geometry/BlobMantleButtressField.gd")
const MATERIALS: Array[String] = ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]
const QUALITY_SAMPLES: Array[int] = [125000, 480000, 1000000]
const QUALITY_AXIS: Array[int] = [48, 94, 132]
const TILE_CELLS: int = 5
const BODY_TRIANGLE_CAPS: Array[int] = [45000, 100000, 180000]
const DETAIL_TRIANGLE_CAPS: Array[int] = [35000, 65000, 120000]
const MAX_BUDGET_ATTEMPTS := 6
# Calibrated in a fixed-lattice clay comparison. These amplify only authored
# anatomical displacement, not fine shader detail or the extraction resolution.
# Faces, joints, terminals and independent thin appendages retain their masks.
const REGIONAL_NOISE_GAINS := {
	"torso": 3.5, "core": 3.5, "abdomen": 4.0, "lobe": 4.0,
	"shoulder": 3.0, "pelvis": 3.0, "muscle_fan": 3.0,
	"growth": 4.5, "limb": 2.75, "body_chain": 2.75, "segment": 3.0,
}

class Influence:
	extends RefCounted
	var node_index: int = 0
	var is_curve: bool = false
	var subtract: bool = false
	var position := Vector3.ZERO
	var radii := Vector3.ONE
	var inverse_radii := Vector3.ONE
	var inverse_squared := Vector3.ONE
	var inverse_basis := Basis.IDENTITY
	var rotated: bool = false
	var end := Vector3.ZERO
	var segment := Vector3.ZERO
	var inverse_length_squared: float = 0.0
	var radius_a: float = 0.1
	var radius_b: float = 0.1
	var elliptical: bool = false
	var width_a: float = 1.0
	var width_b: float = 1.0
	var depth_a: float = 1.0
	var depth_b: float = 1.0
	var across := Vector3.RIGHT
	var depth_axis := Vector3.BACK
	var axial := Vector3.UP
	var blend: float = 0.1
	var amplitude: float = 0.05
	var material: int = 0
	var bounds := AABB()
	var shape_power: float = 2.0
	var body_envelope: RefCounted = null
	var member_indices := PackedInt32Array()
	func represents_node(index: int) -> bool:
		return index == node_index or index in member_indices
	var sac_group: RefCounted = null
	var sculpt_strength: float = 0.0
	var sculpt_phase: float = 0.0
	var sculpt_mode: int = 0
	var preserve_thickness: bool = true
	var surface_parent: int = -1
	var lip_radius: float = 0.0
	var contained_lip_radius: float = 0.0
	var contained_lip_minimum_radius: float = 0.0
	var contained_lip_owner: int = -1
	var contained_lip_bounds := AABB()
	var porous_patch: RefCounted = null
	var loaded_pressure: RefCounted = null
	var grown_field: RefCounted = null
	var mantle_field: RefCounted = null
	var seat_grid: Dictionary = {}
	var seat_scale := Vector3.ONE
	var seat_height: float = 1.35
	var seat_depth: float = 0.16
	var noise_origin := Vector3.ZERO
	var noise_basis := Basis.IDENTITY
	var noise_offset := Vector3.ZERO
	var noise_context := Vector4(0.0, 0.0, 0.0, 0.35)
	var fold_frequency: float = 2.8
	func noise_point(point: Vector3) -> Vector3:
		return noise_basis * (point - noise_origin) + noise_offset
	func distance(point: Vector3) -> float:
		if body_envelope != null: return body_envelope.distance(point)
		if sac_group != null: point = sac_group.inverse(point)
		if grown_field != null:
			return grown_field.distance(inverse_basis*(point-position))
		if mantle_field != null:
			return mantle_field.distance(inverse_basis*(point-position))
		if loaded_pressure != null:
			return loaded_pressure.distance(inverse_basis * (point - position))
		if porous_patch != null:
			return porous_patch.distance(inverse_basis * (point - position))
		if not seat_grid.is_empty():
			var p := (inverse_basis * (point - position)) / seat_scale
			var v := p.y / (seat_height * 0.5)
			var shape := 1.0 - 0.19 * smoothstep(0.0, 1.0, (-v - 0.10) / 0.75) + 0.035 * exp(-pow((v + 0.12) / 0.24, 2.0))
			var r := Vector2(p.x / (0.5 * shape), v).length()
			var radial := (r - 0.94) * minf(seat_scale.x * 0.5, seat_scale.y * seat_height * 0.5)
			if radial > blend * 2.0:
				return radial
			var resolution := int(seat_grid.resolution)
			var gx := clampf((p.x / float(seat_grid.width) + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
			var gy := clampf((p.y / float(seat_grid.height) + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
			var ix := mini(floori(gx), resolution - 2)
			var iy := mini(floori(gy), resolution - 2)
			var heights: PackedFloat32Array = seat_grid.heights
			var height := lerpf(lerpf(heights[ix + iy * resolution], heights[ix + 1 + iy * resolution], gx - ix), lerpf(heights[ix + (iy + 1) * resolution], heights[ix + 1 + (iy + 1) * resolution], gx - ix), gy - iy)
			p.z -= height
			var depth := seat_depth * (1.0 - smoothstep(0.60, 0.94, r))
			return maxf(radial, maxf((-p.z - depth) * seat_scale.z, (p.z - 0.10) * seat_scale.z))
		if is_curve:
			var t := clampf((point - position).dot(segment) * inverse_length_squared, 0.0, 1.0)
			var radial := point.distance_to(position + segment * t)
			t = clampf(t + (radius_b - radius_a) * radial * inverse_length_squared, 0.0, 1.0)
			if not elliptical:
				return point.distance_to(position + segment * t) - lerpf(radius_a, radius_b, t)
			# Elliptical biological envelope in a transported anatomical frame.
			# The axial coordinate preserves rounded end caps; the radial factors
			# change continuously without adding overlapping secondary meshes.
			var offset := point - position - segment * t
			var scale := Vector3(lerpf(width_a, width_b, t), lerpf(depth_a, depth_b, t), 1.0)
			var local := Vector3(offset.dot(across), offset.dot(depth_axis), offset.dot(axial))
			var q := local / scale
			var k0 := q.length()
			var k1 := (q / scale).length()
			var radius := lerpf(radius_a, radius_b, t)
			if k1 < 0.000001:
				return -radius * minf(1.0, minf(scale.x, scale.y))
			return k0 * (k0 - radius) / k1
		var p := point - position
		if rotated:
			p = inverse_basis * p
		var original := p
		if sculpt_strength > 0.0001:
			# Low-frequency anatomical sculpting precedes detail displacement.
			# Coupled axial bends, waists and compression planes eliminate the
			# obvious quadric silhouette without roughening every surface equally.
			var q := p * inverse_radii
			var phase_sine := sin(sculpt_phase)
			q.x += sculpt_strength * 0.62 * (sin(q.y * 2.7 + sculpt_phase) - phase_sine)
			q.z += sculpt_strength * 0.52 * (sin(q.y * 3.3 - sculpt_phase) + phase_sine)
			q.y += sculpt_strength * 0.30 * sin(q.x * 2.4 + q.z * 1.8)
			q.x *= 1.0 + sculpt_strength * 0.65 * cos(q.y * 4.1 + sculpt_phase)
			q.z *= 1.0 + sculpt_strength * 0.60 * sin(q.y * 3.2 + q.x * 1.6 + sculpt_phase)
			if sculpt_mode == 1:
				var waist := exp(-pow((q.y + 0.26) / 0.32, 2.0))
				var ribs := exp(-pow((q.y - 0.42) / 0.42, 2.0))
				q.x *= 1.0 + sculpt_strength * (2.0 * waist - 0.75 * ribs)
				q.z *= 1.0 + sculpt_strength * 0.65 * waist
			elif sculpt_mode == 3:
				# Cranial vault, cheek prominence and a distinct tapered jaw are
				# anatomical shape rules, not random spheres with a face decal.
				var jaw_width := 0.64 + 0.36 * smoothstep(-0.88, 0.32, q.y)
				var cheek := 0.085 * exp(-pow((q.y + 0.04) / 0.29, 2.0))
				q.x /= jaw_width + cheek
				q.z *= 1.0 + 0.16 * (1.0 - smoothstep(-0.85, -0.10, q.y))
			elif sculpt_mode == 4:
				# Iliac flares, a narrower lower pelvic ring and a shallow crest.
				var crest := exp(-pow((q.y - 0.38) / 0.38, 2.0))
				var lower_ring := exp(-pow((q.y + 0.52) / 0.34, 2.0))
				q.x *= 1.0 + sculpt_strength * (-0.60 * crest + 0.51 * lower_ring)
				q.z *= 1.0 + sculpt_strength * 0.30 * lower_ring
				q.y += sculpt_strength * 0.18 * sin(q.x * PI) * sin(q.x * PI)
			elif sculpt_mode == 5:
				# Compact cartilage landmarks have two offset condyles rather
				# than a perfectly round elbow/knee bead.
				q.x *= 1.0 + 0.12 * cos(q.y * PI * 1.8)
				q.z += 0.11 * sin(q.x * PI)
			p = q * radii
		if shape_power > 2.001:
			# A rounded quadrangular internal palm follows metacarpal spread
			# without exposed spherical knuckles or subvoxel support spokes.
			var q := (p * inverse_radii).abs()
			var k := pow(pow(q.x, shape_power) + pow(q.y, shape_power) + pow(q.z, shape_power), 1.0 / shape_power)
			var gradient := Vector3(pow(q.x, shape_power - 1.0), pow(q.y, shape_power - 1.0), pow(q.z, shape_power - 1.0)) * inverse_radii
			if gradient.length_squared() < 0.000000001:
				return -minf(radii.x, minf(radii.y, radii.z))
			return pow(k, shape_power - 1.0) * (k - 1.0) / gradient.length()
		var k0 := (p * inverse_radii).length()
		var k1 := (p * inverse_squared).length()
		if k1 < 0.000001:
			return -minf(radii.x, minf(radii.y, radii.z))
		var field := k0 * (k0 - 1.0) / k1
		if sculpt_mode == 2:
			var floor_plane := -original.y - radii.y * 0.79
			var blend_radius := minf(radii.x, minf(radii.y, radii.z)) * 0.16
			var h := clampf(0.5 + 0.5 * (field - floor_plane) / blend_radius, 0.0, 1.0)
			field = lerpf(floor_plane, field, h) + blend_radius * h * (1.0 - h)
		elif sculpt_mode == 3:
			# A softened front facial plane gives the reusable brow/cheek mesh
			# a biological transition into the skull instead of an oval plaque.
			var normalized_y := original.y / radii.y
			var front_extent := radii.z * (0.73 + 0.12 * smoothstep(-0.8, 0.7, normalized_y))
			var facial_plane := -original.z - front_extent
			var blend_radius := minf(radii.x, minf(radii.y, radii.z)) * 0.18
			var h := clampf(0.5 + 0.5 * (field - facial_plane) / blend_radius, 0.0, 1.0)
			field = lerpf(facial_plane, field, h) + blend_radius * h * (1.0 - h)
		return field

var slab_high_preview2: bool=false
var slab_high_preview: bool=false
var slab_pilot_path: String=""
var slab_axes: Array=[]
var slab_dimensions: Vector3i=Vector3i.ZERO
var slab_report: Dictionary={}
var influences: Array[Influence] = []
var lattice_collars: Array[Influence] = []
var contained_lips: Array[Influence] = []
var preparation_errors: Array[String] = []
var tiles: Array = []
var tile_dimensions := Vector3i.ZERO
var grid_dimensions := Vector3i.ZERO
var bounds := AABB()
var step: float = 0.1
var noise = NoiseField.new()
var preservation_masks: Array[Vector4] = []
var module_surface_anchors: Dictionary = {}
var module_surface_grids: Dictionary = {}
var node_ids := PackedStringArray()
var node_materials := PackedInt32Array()
var node_blends := PackedFloat32Array()
var controls: RefCounted
var thin_features_preserved: int = 0
var attachment_repairs: int = 0
var geometry_adjustments: Dictionary = {}
var field_evaluations: int = 0
var primitive_evaluations: int = 0
var empty_samples: int = 0
var source_dna: Dictionary = {}
var budget_spacing_scale: float = 1.0
var body_triangle_limit: int = 180000
var detail_triangle_limit: int = 120000
var attachment_lattice := PackedFloat32Array()
var build_module_attachment_fields: bool = false
var regional_noise_gain: Dictionary = REGIONAL_NOISE_GAINS.duplicate()

#206c: old206 snapshots remain loadable/queryable, but experimental downstream
# extraction cannot silently use the independently rejected204c normal policy.
static func validate_positive_growth_extraction_policy(dna: Dictionary)->Dictionary:
	var settings: Dictionary=dna.get("settings",{})
	if settings.get(PositiveGrowth.SETTING,PositiveGrowth.OFF)!=PositiveGrowth.MODE:return {"ok":true}
	var normal_mode: Variant=settings.get(BoundedNormal.SETTING,BoundedNormal.OFF)
	if normal_mode is String and normal_mode==BoundedNormal.MODE:return BoundedNormal.validate(dna)
	var choice: Dictionary=AdaptiveNormal.selection(settings)
	if choice.has("error") or choice.get("mode")!=AdaptiveNormal.MODE:return {"ok":false,"error":"206c positive-growth extraction requires explicit qualified adaptive_field_gradient_v1 normals; no fallback."}
	return {"ok":true}

func build(dna: Dictionary, quality: int = 1, job: RefCounted = null, limits: Dictionary = {}) -> Dictionary:
	var slab_check: Dictionary=SlabPolicy.validate(dna)
	if not slab_check.ok:return {"error":slab_check.error}
	var retained_path: Variant=limits.get("conforming_slab_pilot_path","")
	if not retained_path is String:return {"error":"210 retained pilot path must be a string."}
	var preview_path: Variant=limits.get("high_preview_pilot_path","")
	if not preview_path is String:return {"error":"224 HighPreview retained pilot path must be a string."}
	var preview2_path: Variant=limits.get("high_preview2_pilot_path","")
	if not preview2_path is String:return {"error":"226 HighPreview2 retained pilot path must be a string."}
	slab_high_preview2=HighPreview2.enabled(dna)
	slab_high_preview=HighPreview.enabled(dna)
	if slab_high_preview2:
		if preview2_path.is_empty() or not preview_path.is_empty() or not retained_path.is_empty():return {"error":"226 requires its exact224 refined pilot and forbids other pilot paths; no fallback."}
	elif not preview2_path.is_empty():return {"error":"226 retained pilot requires its explicit HighPreview2 selector."}
	elif slab_high_preview:
		# This separate path authenticates the SAME selected Stage5 field, not a
		# Stage4 pilot for changed anatomy. No absent/bad-pilot rebuild fallback.
		if preview_path.is_empty() or not retained_path.is_empty():return {"error":"224 requires its explicit selected Stage5 pilot and forbids the old retained-pilot path."}
	elif not preview_path.is_empty():return {"error":"224 retained pilot requires the explicit HighPreview budget selector."}
	if SacSurface.enabled(dna) and not slab_high_preview:
		var pilot_eligibility: Dictionary=SacSurface.validate_pilot_path(dna,retained_path)
		if not pilot_eligibility.ok:return {"error":pilot_eligibility.error}
	if (SlabPolicy.enabled(dna) and quality!=1) or (not retained_path.is_empty() and not SlabPolicy.enabled(dna)):return {"error":"210 retained pilot/refinement requires explicit Standard Stage4 mode."}

	slab_pilot_path=preview2_path if slab_high_preview2 else (preview_path if slab_high_preview else retained_path)
	var positive_normal_policy: Dictionary=validate_positive_growth_extraction_policy(dna)
	if not positive_normal_policy.ok:return {"error":positive_normal_policy.error}
	quality = clampi(quality, 0, 2)
	build_module_attachment_fields = bool(limits.get("module_attachment_fields", false))
	# An explicit map replaces defaults, including an empty baseline map used
	# by controlled comparisons. This option never mutates the saved anatomy.
	regional_noise_gain = limits.get("regional_noise_gain", REGIONAL_NOISE_GAINS).duplicate()
	var budget: Dictionary = dna.get("budget", {})
	body_triangle_limit = mini(BODY_TRIANGLE_CAPS[quality], mini(int(limits.get("max_body_triangles", BODY_TRIANGLE_CAPS[quality])), int(budget.get("max_body_triangles", BODY_TRIANGLE_CAPS[quality]))))
	detail_triangle_limit = mini(DETAIL_TRIANGLE_CAPS[quality], mini(int(limits.get("max_detail_triangles", DETAIL_TRIANGLE_CAPS[quality])), int(budget.get("max_detail_triangles", DETAIL_TRIANGLE_CAPS[quality]))))
	if body_triangle_limit < 512 or detail_triangle_limit < 0:
		return {"error": "The requested geometry budget is below the minimum viable anatomical surface budget."}
	budget_spacing_scale = 1.0
	var started := Time.get_ticks_msec()
	var adaptations: Array[String] = []
	for attempt in range(MAX_BUDGET_ATTEMPTS):
		var result := _build_once(dna, quality, job)
		if result.has("retry_body_triangles"):
			var previous := budget_spacing_scale
			budget_spacing_scale *= maxf(1.08, sqrt(float(result.retry_body_triangles) / float(body_triangle_limit)) * 1.035)
			if budget_spacing_scale > 3.2 or attempt == MAX_BUDGET_ATTEMPTS - 1:
				return {"error": "The fused anatomy cannot fit its %s-triangle limit without excessive resolution loss." % body_triangle_limit, "budget_exceeded": true}
			adaptations.append("Fused surface spacing increased from %.3fx to %.3fx to meet the %s-triangle cap." % [previous, budget_spacing_scale, body_triangle_limit])
			if job != null:
				job.set_progress(0.12, "Adapting surface resolution to the triangle budget")
			continue
		if result.has("error") or result.get("cancelled", false):
			return result
		var detail_triangles := 0
		for layer in result.detail_meshes:
			detail_triangles += int(layer.indices.size() / 3)
			for message in layer.stats.get("budget_adaptations", []):
				adaptations.append(str(message))
		result.stats["budget_adaptations"] = adaptations
		result.stats["budget_attempts"] = attempt + 1
		result.stats["spacing_scale"] = budget_spacing_scale
		result.stats["max_body_triangles"] = body_triangle_limit
		result.stats["max_detail_triangles"] = detail_triangle_limit
		result.stats["detail_triangles"] = detail_triangles
		result.stats["generated_triangles"] = int(result.indices.size() / 3) + detail_triangles
		result.stats["regional_noise_gains"] = regional_noise_gain.duplicate()
		result.stats["geometry_ms"] = Time.get_ticks_msec() - started
		return result
	return {"error": "The geometry budget adaptation did not converge.", "budget_exceeded": true}

var envelope_attribution_reductions := 0
var envelope_attribution_max_dropped := 0.0
var envelope_attribution_sum_dropped := 0.0

func _build_once(dna: Dictionary, quality: int, job: RefCounted) -> Dictionary:
	slab_axes=[];slab_dimensions=Vector3i.ZERO;slab_report={}
	envelope_attribution_reductions = 0
	envelope_attribution_max_dropped = 0.0
	envelope_attribution_sum_dropped = 0.0
	var start_time := Time.get_ticks_msec()
	controls = job
	source_dna = dna
	quality = clampi(quality, 0, 2)
	influences.clear()
	lattice_collars.clear()
	preservation_masks.clear()
	module_surface_anchors.clear()
	module_surface_grids.clear()
	node_ids.clear()
	node_materials.clear()
	node_blends.clear()
	thin_features_preserved = 0
	attachment_repairs = 0
	geometry_adjustments = {"thin_features": [], "attachment_collars": [], "lattice_collars": []}
	field_evaluations = 0
	primitive_evaluations = 0
	empty_samples = 0
	if job != null:
		job.set_progress(0.06, "Growing anatomical volumes")
	var nodes: Array = dna.get("nodes", [])
	if nodes.is_empty():
		return {"error": "The anatomy graph contains no tissue nodes."}
	_prepare(nodes, quality)
	if not preparation_errors.is_empty(): return {"error": "; ".join(preparation_errors), "invalid_blob_patch": true}
	if influences.is_empty():
		return {"error": "The anatomy graph contains no supported volumes."}
	_conform_surface_folds()
	_configure_grid(quality)
	_preserve_thin_features()
	_ensure_growth_attachments(nodes)
	if source_dna.get("settings",{}).get(EnvelopeField.SETTING,EnvelopeField.OFF)!=EnvelopeField.OFF and (thin_features_preserved>0 or attachment_repairs>0): preparation_errors.append("201b fixed bounded union refuses geometry repairs.")
	if not preparation_errors.is_empty(): return {"error": "; ".join(preparation_errors), "invalid_blob_patch": true}
	_build_tiles()
	var settings: Dictionary = dna.get("settings", {})
	var scale_value := maxf(float(settings.get("size", 1.0)), 0.05)
	noise.configure(int(dna.get("seed", 1)), scale_value, float(settings.get("surface_detail", settings.get("detail", 0.5))))
	_prepare_masks(dna.get("modules", []))
	_expose_surface_cavities(nodes)
	_prepare_module_seats(dna.get("modules", []))
	var cavity_qualification217: Dictionary={}
	if Cavity217.enabled(dna):
		var cavity_author: GDScript=Cavity217.author_for(dna)
		cavity_qualification217=cavity_author.qualify(dna,{},self)
		if not cavity_qualification217.get("ok",false):return {"error":"217 fixed mantle cavity qualification failed; no placement/size fallback.","mantle_cavity_qualification217":cavity_qualification217}
	if source_dna.get("settings",{}).get(GroupField.SETTING,GroupField.OFF) in [GroupField.LEGACY_MODE,GroupField.MODE,GroupField.FINAL_MODE]:
		var qualification: Dictionary = sac_group_qualification()
		if not qualification.ok:
			var rejected_qualification: Dictionary={"error": "184 shared group failed declared root/channel/composed section qualification.","sac_group_qualification": qualification}
			if Cavity217.enabled(dna):rejected_qualification["mantle_cavity_qualification217"]=cavity_qualification217
			return rejected_qualification
	var sampled: PackedFloat32Array=PackedFloat32Array()
	var sample_time: int=0
	var result: Dictionary={}
	if SlabPolicy.enabled(dna):
		var slab_result: Dictionary=_extract_conforming_slabs210(job)
		if Cavity217.enabled(dna):slab_result["mantle_cavity_qualification217"]=cavity_qualification217
		if slab_result.has("error") or slab_result.get("cancelled",false):return slab_result
		sampled=slab_result.field;result=slab_result.mesh;sample_time=slab_result.sample_time
	else:
		sampled = _sample_field()
		if sampled.is_empty() or _cancelled():
			return {"cancelled": true}
		var connectivity: Dictionary = Connectivity.repair(sampled, grid_dimensions, bounds.position, step, job)
		if connectivity.has("error") or connectivity.get("cancelled", false):
			return connectivity
		if source_dna.get("settings",{}).get(EnvelopeField.SETTING,EnvelopeField.OFF)!=EnvelopeField.OFF and not connectivity.collars.is_empty(): return {"error":"201b bounded union context invalidated by lattice collars; no extraction."}
		sampled = connectivity.field
		_register_lattice_collars(connectivity.collars)
		sample_time = Time.get_ticks_msec()
		var refinement: RefCounted=null
		if source_dna.get("settings",{}).get(EdgeRefinement.SETTING,EdgeRefinement.OFF)==EdgeRefinement.MODE:
			var normal_mode: Variant=source_dna.get("settings",{}).get(BoundedNormal.SETTING,BoundedNormal.OFF)
			if normal_mode is String and normal_mode==BoundedNormal.MODE:
				refinement=BoundedEdge.create(_continuous_extraction_value,step,BoundedNormal.MODE)
			else:
				refinement=EdgeRefinement.create(_continuous_extraction_value,step,str(source_dna.get("settings",{}).get(AdaptiveNormal.SETTING,AdaptiveNormal.OFF)))
		result = Extractor.new().extract(sampled, grid_dimensions, bounds.position, step, job,refinement)
	if result.has("error"): return result
	if result.get("cancelled", false):
		return result
	if result.vertices.is_empty():
		return {"error": "No surface crossed the bounded extraction lattice."}
	if result.indices.size() / 3 > body_triangle_limit:
		if SlabPolicy.enabled(dna):
			result.merge({"error":"210 final triangle cap exceeded; no spacing adaptation.","rejected":true,"raw_snapshot_complete":true,"raw_snapshot_status":"completed_finite_index_safe_rejected_before_attribution"},true);return result
		return {"retry_body_triangles": int(result.indices.size() / 3)}
	var extraction_time := Time.get_ticks_msec()
	_attribute_vertices(result, sampled)
	if _cancelled():
		if SlabPolicy.enabled(dna):return _slab_completed_rejection210(result,"210 cancelled after complete extraction, attribution unavailable.",true)
		return {"cancelled": true}
	result["node_ids"] = node_ids
	result["bounds"] = _vertex_bounds(result.vertices)
	if Cavity217.enabled(dna):result["mantle_cavity_qualification217"]=cavity_qualification217
	attachment_lattice = sampled
	var tendon_layer: Dictionary = Tendons.build(dna, quality, _embed_tendon_endpoint, _tendon_surface, job, detail_triangle_limit)
	if tendon_layer.has("error") or tendon_layer.get("cancelled", false):
		attachment_lattice = PackedFloat32Array()
		if SlabPolicy.enabled(dna):return _slab_completed_rejection210(result,str(tendon_layer.get("error","210 cancelled during post-extraction detail processing.")),bool(tendon_layer.get("cancelled",false)))
		return tendon_layer
	for endpoint: Vector3 in tendon_layer.get("embedded_endpoints", PackedVector3Array()):
		if _attachment_value(endpoint) >= -step * 0.001:
			attachment_lattice = PackedFloat32Array()
			if SlabPolicy.enabled(dna):return _slab_completed_rejection210(result,"210 post-extraction tendon endpoint rejected.")
			return {"error": "A tendon endpoint could not be embedded in the final extracted tissue without an unsafe attachment."}
	for point in tendon_layer.get("surface_attachment_samples", PackedVector3Array()):
		if _attachment_value(point) >= -step * 0.001:
			attachment_lattice = PackedFloat32Array()
			if SlabPolicy.enabled(dna):return _slab_completed_rejection210(result,"210 post-extraction fascia boundary rejected.")
			return {"error": "An explicitly buried fascia boundary could not be attached to the final primary tissue."}
	result["detail_meshes"] = []
	if not tendon_layer.is_empty():
		var membrane_layer: Dictionary = tendon_layer.get("membrane_mesh", {})
		tendon_layer.erase("membrane_mesh")
		result.detail_meshes.append(tendon_layer)
		if not membrane_layer.is_empty():
			result.detail_meshes.append(membrane_layer)
			result.bounds = result.bounds.merge(membrane_layer.bounds)
		result.bounds = result.bounds.merge(tendon_layer.bounds)
	result["collision_proxies"] = _collision_proxies(nodes)
	result["module_anchors"] = _module_anchors(dna.get("modules", []), sampled)
	attachment_lattice = PackedFloat32Array()
	if _cancelled():
		if SlabPolicy.enabled(dna):return _slab_completed_rejection210(result,"210 cancelled after complete extraction, final metadata unavailable.",true)
		return {"cancelled": true}
	result["geometry_adjustments"] = geometry_adjustments
	result["quality"] = quality
	result["stats"] = {"vertices": result.vertices.size(), "triangles": result.indices.size() / 3, "grid": [grid_dimensions.x, grid_dimensions.y, grid_dimensions.z], "cell_size": step, "grid_samples": sampled.size(), "sampled_points": field_evaluations, "skipped_empty_points": empty_samples, "primitive_tests": primitive_evaluations, "field_primitives": influences.size(), "active_cells": result.get("active_cells", 0), "thin_features_preserved": thin_features_preserved, "attachment_repairs": attachment_repairs, "lattice_connection_repairs": lattice_collars.size(), "field_ms": sample_time - start_time, "extraction_ms": extraction_time - sample_time, "attribution_ms": Time.get_ticks_msec() - extraction_time, "geometry_ms": Time.get_ticks_msec() - start_time}
	if SlabPolicy.enabled(dna):
		result.stats["conforming_slabs210"]=slab_report.duplicate(true)
		result.stats["base_grid"]=[grid_dimensions.x,grid_dimensions.y,grid_dimensions.z]
		result.stats["uniform_extraction_grid"]=slab_axes.is_empty()
		if not slab_axes.is_empty():result.stats["grid"]=[slab_dimensions.x,slab_dimensions.y,slab_dimensions.z]
		result.stats["cell_size_semantics"]="unchanged field/normal reference cell, not all rectilinear interval widths"
	if dna.get("settings", {}).get(EnvelopeField.SETTING, EnvelopeField.OFF) == EnvelopeField.MODE:
		result.stats["body_envelope201_attribution"] = {"reductions":envelope_attribution_reductions,"maximum_dropped_weight":envelope_attribution_max_dropped,"sum_dropped_weight":envelope_attribution_sum_dropped,"maximum_components":4}
	if dna.get("settings",{}).get(BodyGroupField.SETTING,BodyGroupField.OFF)==BodyGroupField.MODE:
		result.stats["body_group202"]={"one_external_group":true,"internal_carriers":4,"core_evaluated_once_per_group_call":true,"actual_smooth_min_attribution":true,"finite_witnesses_only":true}
	if not contained_lips.is_empty():
		var lip_reports: Array = []
		for item in contained_lips:
			lip_reports.append({"cavity_id": str(node_ids[item.node_index]), "owner_id": str(node_ids[item.contained_lip_owner]), "minimum_grid_span": item.contained_lip_minimum_radius * 2.0 / step, "enabled_at_resolution": item.contained_lip_minimum_radius * 2.0 >= step * 2.2, "radius": item.contained_lip_radius, "throat_ratio": 0.50, "collar_min_fraction": 0.12})
		result.stats["contained_lips"] = lip_reports
	if result.has("edge_refinement204"): result.stats["edge_refinement204"]=result.edge_refinement204.duplicate(true)
	if source_dna.get("settings",{}).get(MassReprofileField.SETTING,MassReprofileField.OFF)==MassReprofileField.MODE:
		result.stats["mass_reprofile203"]={"one_external_group":true,"internal_carriers":4,"outer_host_changed":true,"protected_middle_roots_unchanged":true,"crown_heuristic_diagnostic":"reported_in_field_qualification","crown_is_aesthetic_diagnostic":true}
	if job != null:
		job.set_progress(0.90, "Continuous mesh ready")
	return result

func _slab_completed_rejection210(result: Dictionary,message: String,was_cancelled: bool=false)->Dictionary:
	# The extractor has already certified complete finite/index-safe physical arrays.
	# Partial semantic attributes are retained under a diagnostic-only key.
	var partial: Dictionary={}
	for key: String in ["component_ids","component_indices","component_weights","colors","uvs","uvs2","ambient_occlusion"]:
		if result.has(key):partial[key]=result[key];result.erase(key)
	if not partial.is_empty():result["partial_attribution210"]=partial
	result.merge({"error":message,"cancelled":was_cancelled,"rejected":true,"raw_snapshot_complete":true,"raw_snapshot_status":"completed_finite_index_safe_rejected_before_attribution","attribution_complete":false,"conforming_slabs210":slab_report.duplicate(true)},true)
	return result

#210: one detection/refinement pass, never a shape/normal repair loop.
func _extract_conforming_slabs210(job: RefCounted)->Dictionary:
	if slab_high_preview2:return _extract_second_conforming_pass226(job)
	var base_shape: Dictionary=SlabGrid._validate_dimensions(grid_dimensions,SlabGrid.MAX_COARSE_SAMPLES)
	if not base_shape.ok:return {"error":base_shape.error}
	var pilot: Dictionary={}
	var coarse_field: PackedFloat32Array=PackedFloat32Array()
	var coarse_sample_time: int=0
	var phase_started: int=Time.get_ticks_msec()
	var historical: bool=not slab_pilot_path.is_empty()
	slab_report={"mode":SlabPolicy.MODE,"pin":SlabPolicy.PIN,"retained_coarse":historical,"coarse_extractions_new":0,"refined_extractions_new":0,"lattice_visits_new":0,"lattice_queries_new":0,"lattice_skips_new":0,"coarse_lattice_visits_new":0,"coarse_lattice_queries_new":0,"coarse_lattice_skips_new":0,"refined_lattice_visits_new":0,"refined_lattice_queries_new":0,"refined_lattice_skips_new":0,"historical_lattice_visits":0,"historical_edge_queries":0,"historical_edges":0,"base_grid":[grid_dimensions.x,grid_dimensions.y,grid_dimensions.z],"base_origin_f32_le":PackedVector3Array([bounds.position]).to_byte_array().hex_encode(),"reference_cell_f64_le":SlabPolicy.scalar_bits(step),"field_normal_reference_unchanged":true,"connectivity_repairs":0,"refinement_pass_cap":1}
	if slab_high_preview:
		slab_report["preview_budget224"]={"mode":HighPreview.MODE,"pin":HighPreview.PIN,"maximum_planes":12,"maximum_planes_per_axis":4,"maximum_extra_samples":80000,"maximum_total_samples":560000,"same_base_field":true,"game_lod_claim":false}
	if historical:
		var retained: Dictionary=HighPilot.load_retained(slab_pilot_path,source_dna,grid_dimensions,bounds.position,step) if slab_high_preview else SlabPilot.load_retained(slab_pilot_path,source_dna,grid_dimensions,bounds.position,step)
		if retained.has("error"):return retained
		pilot=retained.mesh;slab_report.historical_lattice_visits=retained.historical_lattice_visits
		slab_report.historical_edge_queries=retained.historical_queries;slab_report.historical_edges=retained.historical_edges
		slab_report["retained_raw_sha256"]=retained.raw_sha256;slab_report["retained_geometry_key"]=retained.geometry_key
	else:
		coarse_field=_sample_coarse210()
		if _cancelled():return {"cancelled":true,"conforming_slabs210":slab_report}
		if coarse_field.is_empty():return {"error":"210 coarse field sampling is nonfinite or incomplete.","conforming_slabs210":slab_report}
		var connected: Dictionary=SlabGrid.audit_connectivity(coarse_field,grid_dimensions,job)
		if not connected.get("ok",false) or connected.get("cancelled",false):connected["conforming_slabs210"]=slab_report;return connected
		coarse_sample_time=Time.get_ticks_msec();slab_report["coarse_sampling_and_audit_ms"]=coarse_sample_time-phase_started
		var coarse_solver: RefCounted=SlabEdge.create_cumulative(_continuous_extraction_value,step,0,0)
		slab_report.coarse_extractions_new=1
		pilot=Extractor.new().extract(coarse_field,grid_dimensions,bounds.position,step,job,coarse_solver)
		slab_report["coarse_extraction_ms"]=Time.get_ticks_msec()-coarse_sample_time
		var coarse_counts: Dictionary=pilot.get("edge_refinement204",coarse_solver.snapshot())
		slab_report["coarse_edges"]=int(coarse_counts.get("unique_edges",0));slab_report["coarse_edge_queries"]=int(coarse_counts.get("continuous_queries",0))
		slab_report["actual_new_edge_queries"]=slab_report.coarse_edge_queries
		if pilot.get("cancelled",false):pilot["conforming_slabs210"]=slab_report;return pilot
		# Incomplete root/normal failures are never eligible for slab refinement.
		if pilot.has("error") and (not SlabPolicy.text_is(pilot.get("error"),SlabPolicy.FACE_ERROR) or not pilot.get("raw_snapshot_complete",false)):
			pilot["conforming_slabs210"]=slab_report;return pilot
	var plan: Dictionary=SlabGrid.plan(pilot,grid_dimensions,bounds.position,step,slab_high_preview)
	if not plan.get("ok",false):
		if slab_high_preview:slab_report["rejected_plan224"]=plan.duplicate(true)
		return {"error":plan.get("error","210 invalid coarse plan."),"conforming_slabs210":slab_report,"coarse_artifact210":pilot}
	slab_report["plan"]=plan.duplicate(true)
	slab_report["canonical_plan_sha256"]=HighPilot.plan_digest(plan,step) if slab_high_preview else SlabPilot.plan_digest(plan,step)
	var prior: Dictionary=pilot.get("edge_refinement204",{})
	if not prior.get("unique_edges") is int or not prior.get("continuous_queries") is int:return {"error":"210 coarse query records must be exact integers.","coarse_artifact210":pilot,"conforming_slabs210":slab_report}
	var prior_edges: int=prior.unique_edges;var prior_queries: int=prior.continuous_queries
	slab_report["coarse_edges"]=prior_edges;slab_report["coarse_edge_queries"]=prior_queries
	if prior_edges>SlabPolicy.EDGE_CAP or prior_queries>SlabPolicy.QUERY_CAP:return {"error":"210 coarse budget already exceeded.","coarse_artifact210":pilot,"conforming_slabs210":slab_report}
	if not plan.refine:
		# A verified retained conflict packet cannot take this branch. Ordinary clean
		# output is the final surface; do not create a recursive self-artifact.
		if historical:return {"error":"210 retained rejected pilot unexpectedly has no conflicts.","coarse_artifact210":pilot,"conforming_slabs210":slab_report}
		slab_report["cumulative_edges"]=prior_edges;slab_report["cumulative_edge_queries"]=prior_queries
		slab_report["coarse_artifact_is_final"]=true;pilot["conforming_slabs210"]=slab_report.duplicate(true)
		return {"mesh":pilot,"field":coarse_field,"sample_time":coarse_sample_time}
	slab_axes=plan.axes;slab_dimensions=plan.dimensions
	phase_started=Time.get_ticks_msec()
	var field: PackedFloat32Array=_sample_rectilinear210()
	if _cancelled():return {"cancelled":true,"coarse_artifact210":pilot,"conforming_slabs210":slab_report}
	if field.is_empty():return {"error":"210 nonfinite rectilinear sampling rejected.","coarse_artifact210":pilot,"conforming_slabs210":slab_report}
	var audit: Dictionary=SlabGrid.audit_connectivity(field,slab_dimensions,job,slab_high_preview)
	if not audit.get("ok",false) or audit.get("cancelled",false):audit["coarse_artifact210"]=pilot;audit["conforming_slabs210"]=slab_report;return audit
	var sample_time: int=Time.get_ticks_msec();slab_report["refined_sampling_and_audit_ms"]=sample_time-phase_started
	var solver: RefCounted=SlabEdge.create_cumulative(_continuous_extraction_value,step,prior_edges,prior_queries)
	if not solver.error.is_empty():return {"error":solver.error,"coarse_artifact210":pilot,"conforming_slabs210":slab_report}
	slab_report.refined_extractions_new=1
	var final_mesh: Dictionary=SlabExtractor.new().extract_rectilinear(field,slab_axes,bounds.position,step,job,solver,slab_high_preview)
	slab_report["refined_extraction_ms"]=Time.get_ticks_msec()-sample_time
	var final_edge: Dictionary=final_mesh.get("edge_refinement204",solver.snapshot())
	slab_report["final_edges"]=int(final_edge.get("unique_edges",0));slab_report["final_edge_queries"]=int(final_edge.get("continuous_queries",0))
	slab_report["cumulative_edges"]=prior_edges+int(slab_report.final_edges)
	slab_report["cumulative_edge_queries"]=prior_queries+int(slab_report.final_edge_queries)
	slab_report["actual_new_edge_queries"]=int(slab_report.final_edge_queries)+(0 if historical else prior_queries)
	final_mesh["conforming_slabs210"]=slab_report.duplicate(true);final_mesh["coarse_artifact210"]=pilot
	if final_mesh.has("error") or final_mesh.get("cancelled",false):return final_mesh
	return {"mesh":final_mesh,"field":field,"sample_time":sample_time}

func _extract_second_conforming_pass226(job: RefCounted)->Dictionary:
	# An authenticated level1 artifact supplies the first pass. Only one new
	# orientation-driven conforming pass is permitted; never recurse on failure.
	var retained: Dictionary=HighPilot2.load_retained(slab_pilot_path,source_dna,grid_dimensions,bounds.position,step)
	if retained.has("error"):return retained
	var pilot: Dictionary=retained.mesh
	var prior_edges: int=retained.historical_edges
	var prior_queries: int=retained.historical_queries
	slab_report={"mode":SlabPolicy.MODE,"pin":SlabPolicy.PIN,"retained_coarse":true,"retained_refined":true,"retained_artifact_level":1,"coarse_extractions_new":0,"refined_extractions_new":0,"lattice_visits_new":0,"lattice_queries_new":0,"lattice_skips_new":0,"coarse_lattice_visits_new":0,"coarse_lattice_queries_new":0,"coarse_lattice_skips_new":0,"refined_lattice_visits_new":0,"refined_lattice_queries_new":0,"refined_lattice_skips_new":0,"historical_lattice_visits":retained.historical_lattice_visits,"historical_edge_queries":prior_queries,"historical_edges":prior_edges,"base_grid":[grid_dimensions.x,grid_dimensions.y,grid_dimensions.z],"base_origin_f32_le":PackedVector3Array([bounds.position]).to_byte_array().hex_encode(),"reference_cell_f64_le":SlabPolicy.scalar_bits(step),"field_normal_reference_unchanged":true,"connectivity_repairs":0,"refinement_pass_cap":2,"historical_refinement_passes":1,"retained_raw_sha256":retained.raw_sha256,"retained_geometry_key":retained.geometry_key,"actual_new_edge_queries":0,"cumulative_edges":prior_edges,"cumulative_edge_queries":prior_queries,"cumulative_lattice_visits":retained.historical_lattice_visits,"refinement_passes":1}
	slab_report["preview_budget226"]={"mode":HighPreview2.MODE,"pin":HighPreview2.PIN,"maximum_cumulative_planes":16,"maximum_cumulative_planes_per_axis":6,"maximum_cumulative_extra_samples":100000,"maximum_total_samples":560000,"same_base_field":true,"orientation_only":true,"game_lod_claim":false,"broad_rim_quality_claim":false}
	var plan: Dictionary=SlabPass2.plan(pilot,retained.axes,retained.first_plan,grid_dimensions,step)
	if not plan.get("ok",false):
		slab_report["rejected_plan226"]=plan.duplicate(true)
		return {"error":plan.get("error","226 invalid complete second-pass plan."),"conforming_slabs210":slab_report,"refined_artifact226":pilot}
	slab_report["plan"]=plan.duplicate(true)
	slab_report["canonical_plan_sha256"]=SlabPass2.plan_digest(plan,step)
	# The generic planner's clean branch returns the original mesh/axes without
	# work. This fixed authenticated rejected224 artifact must have a conflict;
	# disagreeing metadata is not an accepted-mesh fallback.
	if not plan.refine:return {"error":"226 authenticated rejected pilot unexpectedly has no conflicts; no extra extraction.","conforming_slabs210":slab_report,"refined_artifact226":pilot}
	if prior_edges>=HighPreview2.EDGE_CAP or prior_queries>=HighPreview2.QUERY_CAP:return {"error":"226 cumulative history exhausted the unchanged extraction cap.","conforming_slabs210":slab_report,"refined_artifact226":pilot}
	slab_axes=plan.axes;slab_dimensions=plan.dimensions
	var phase_started: int=Time.get_ticks_msec()
	var field: PackedFloat32Array=_sample_rectilinear210()
	slab_report["cumulative_lattice_visits"]=int(slab_report.historical_lattice_visits)+int(slab_report.lattice_visits_new)
	if _cancelled():return {"cancelled":true,"conforming_slabs210":slab_report,"refined_artifact226":pilot}
	if field.is_empty():return {"error":"226 nonfinite or incomplete rectilinear sampling rejected.","conforming_slabs210":slab_report,"refined_artifact226":pilot}
	var audit: Dictionary=SlabGrid.audit_connectivity(field,slab_dimensions,job,true)
	if not audit.get("ok",false) or audit.get("cancelled",false):audit["refined_artifact226"]=pilot;audit["conforming_slabs210"]=slab_report;return audit
	var sample_time: int=Time.get_ticks_msec();slab_report["refined_sampling_and_audit_ms"]=sample_time-phase_started
	var solver: RefCounted=SlabEdge.create_cumulative(_continuous_extraction_value,step,prior_edges,prior_queries)
	if not solver.error.is_empty():return {"error":solver.error,"conforming_slabs210":slab_report,"refined_artifact226":pilot}
	slab_report.refined_extractions_new=1;slab_report.refinement_passes=2
	var final_mesh: Dictionary=SlabExtractor.new().extract_rectilinear(field,slab_axes,bounds.position,step,job,solver,true)
	slab_report["refined_extraction_ms"]=Time.get_ticks_msec()-sample_time
	var final_edge: Dictionary=final_mesh.get("edge_refinement204",solver.snapshot())
	slab_report["final_edges"]=int(final_edge.get("unique_edges",0));slab_report["final_edge_queries"]=int(final_edge.get("continuous_queries",0))
	slab_report["cumulative_edges"]=prior_edges+int(slab_report.final_edges)
	slab_report["cumulative_edge_queries"]=prior_queries+int(slab_report.final_edge_queries)
	slab_report["cumulative_lattice_visits"]=int(slab_report.historical_lattice_visits)+int(slab_report.lattice_visits_new)
	slab_report["actual_new_edge_queries"]=int(slab_report.final_edge_queries)
	slab_report["refinement_passes"]=2
	final_mesh["conforming_slabs210"]=slab_report.duplicate(true);final_mesh["refined_artifact226"]=pilot
	if final_mesh.has("error") or final_mesh.get("cancelled",false):return final_mesh
	return {"mesh":final_mesh,"field":field,"sample_time":sample_time}

func _sample_coarse210() -> PackedFloat32Array:
	var count := grid_dimensions.x * grid_dimensions.y * grid_dimensions.z
	slab_report["coarse_lattice_planned_visits"]=count
	var field := PackedFloat32Array()
	field.resize(count)
	field.fill(step * 12.0)
	var plane: int = grid_dimensions.x * grid_dimensions.y
	for z in range(grid_dimensions.z):
		if _cancelled():
			return PackedFloat32Array()
		if controls != null:
			controls.set_progress(0.12 + 0.35 * float(z) / float(grid_dimensions.z), "Sampling living tissue")
		@warning_ignore("integer_division")
		var tz: int = z / TILE_CELLS
		for y in range(grid_dimensions.y):
			@warning_ignore("integer_division")
			var ty: int = y / TILE_CELLS
			var bucket_row: int = ty * tile_dimensions.x + tz * tile_dimensions.x * tile_dimensions.y
			var position := bounds.position + Vector3(0.0, y * step, z * step)
			for x in range(grid_dimensions.x):
				slab_report.lattice_visits_new+=1;slab_report.coarse_lattice_visits_new+=1
				@warning_ignore("integer_division")
				var tx: int = x / TILE_CELLS
				var bucket: PackedInt32Array = tiles[bucket_row + tx]
				position.x = bounds.position.x + x * step
				if bucket.is_empty():
					empty_samples += 1
					slab_report.lattice_skips_new+=1;slab_report.coarse_lattice_skips_new+=1
					continue
				field_evaluations += 1
				slab_report.lattice_queries_new+=1;slab_report.coarse_lattice_queries_new+=1
				var value := _field_value(position, bucket)
				if not is_finite(value):return PackedFloat32Array()
				# Never place the isosurface exactly on a grid vertex. This avoids
				# zero-area tetrahedra while preserving determinism and sign.
				if absf(value) < 0.0000001:
					value = 0.0000001
				field[x + y * grid_dimensions.x + z * plane] = value
	return field


func _sample_rectilinear210()->PackedFloat32Array:
	var count: int=slab_dimensions.x*slab_dimensions.y*slab_dimensions.z
	var field: PackedFloat32Array=PackedFloat32Array();field.resize(count);field.fill(step*12.0)
	slab_report["refined_lattice_planned_visits"]=count
	for index in range(count):
		if index%4096==0:
			if _cancelled():return PackedFloat32Array()
			if controls!=null:controls.set_progress(0.12+0.35*float(index)/float(count),"Sampling conforming tissue slabs")
		slab_report.lattice_visits_new+=1;slab_report.refined_lattice_visits_new+=1
		var point: Vector3=SlabGrid.point(index,slab_dimensions,slab_axes,slab_high_preview)
		var bucket: PackedInt32Array=_tile_at(point)
		if bucket.is_empty():
			empty_samples+=1;slab_report.lattice_skips_new+=1;slab_report.refined_lattice_skips_new+=1;continue
		field_evaluations+=1;slab_report.lattice_queries_new+=1;slab_report.refined_lattice_queries_new+=1
		var value: float=_field_value(point,bucket)
		if not is_finite(value):return PackedFloat32Array()
		if absf(value)<0.0000001:value=0.0000001
		field[index]=value
	return field

func _slab_tendon_corner210(p: Vector3,original_point: Vector3)->Vector3:
	var local: Dictionary=SlabGrid.locate_validated(p,slab_axes)
	if not local.get("inside",false):return p
	var center: Vector3i=local.cell;var best: Vector3=p;var best_distance: float=INF
	for z in range(maxi(center.z-8,1),mini(center.z+9,slab_dimensions.z-1)):
		for y in range(maxi(center.y-8,1),mini(center.y+9,slab_dimensions.y-1)):
			for x in range(maxi(center.x-8,1),mini(center.x+9,slab_dimensions.x-1)):
				var index: int=x+y*slab_dimensions.x+z*slab_dimensions.x*slab_dimensions.y
				if attachment_lattice[index]>=-step*0.12:continue
				var candidate: Vector3=SlabGrid.point(index,slab_dimensions,slab_axes,slab_high_preview)
				var distance: float=candidate.distance_squared_to(original_point)
				if distance<best_distance:best=candidate;best_distance=distance
	return best

func _prepare(nodes: Array, quality: int) -> void:
	preparation_errors.clear()
	slab_high_preview2=HighPreview2.enabled(source_dna)
	slab_high_preview=HighPreview.enabled(source_dna)
	var slab_check: Dictionary=SlabPolicy.validate(source_dna)
	if not slab_check.ok:preparation_errors.append(str(slab_check.error));return
	var normal_validation: Dictionary=BoundedNormal.validate(source_dna)
	if not normal_validation.ok:preparation_errors.append(str(normal_validation.error));return
	var edge_validation: Dictionary=EdgeRefinement.validate(source_dna)
	if not edge_validation.ok:
		preparation_errors.append(str(edge_validation.error)); return
	var positive_check:=PositiveGrowth.validate(source_dna)
	if not positive_check.ok:preparation_errors.append(str(positive_check.error));return
	var positive: bool=source_dna.get("settings",{}).get(PositiveGrowth.SETTING,PositiveGrowth.OFF)==PositiveGrowth.MODE
	if not positive:
		var mass_reprofile_context:=MassReprofileField.validate_compilation_context(source_dna)
		if not mass_reprofile_context.ok:
			preparation_errors.append(str(mass_reprofile_context.error)); return
		var mass_reprofile_validation:=MassReprofileField.validate(source_dna)
		if not mass_reprofile_validation.ok:
			preparation_errors.append(str(mass_reprofile_validation.error)); return
		var body_group_context:=BodyGroupField.validate_compilation_context(source_dna)
		if not body_group_context.ok:
			preparation_errors.append(str(body_group_context.error)); return
		var body_group_validation:=BodyGroupField.validate(source_dna)
		if not body_group_validation.ok:
			preparation_errors.append(str(body_group_validation.error)); return
		var envelope_context:=EnvelopeField.validate_compilation_context(source_dna)
		if not envelope_context.ok:
			preparation_errors.append(str(envelope_context.error)); return
	else:
		# Strict206 validation replaces only the old Stage2 context checks.
		# Original shape declarations remain mandatory, not bypassed.
		for checked: Dictionary in [MassReprofileField.validate(source_dna),BodyGroupField.validate(source_dna)]:
			if not checked.ok:preparation_errors.append(str(checked.error));return
	contained_lips.clear()
	preparation_errors.clear()
	var envelope_validation: Dictionary = EnvelopeField.validate(source_dna)
	if not bool(envelope_validation.get("ok",false)):
		preparation_errors.append(str(envelope_validation.get("error","Invalid201 envelope."))); return
	var have_bounds := false
	var group_fields: Dictionary = {}
	var group_requested: bool = source_dna.get("settings",{}).get(GroupField.SETTING,GroupField.OFF) != GroupField.OFF
	for node: Dictionary in nodes:
		if GroupField.marked(node) or node.has(GroupField.LINK): group_requested = true
	if group_requested:
		var validation: Dictionary = GroupField.validate(source_dna)
		if not bool(validation.get("ok",false)):
			preparation_errors.append(str(validation.get("error","Invalid shared sac group."))); return
		for node: Dictionary in nodes:
			if GroupField.marked(node): group_fields[node.id] = GroupField.create(source_dna,node)
	for ni in range(nodes.size()):
		var node: Dictionary = nodes[ni]
		node_ids.append(str(node.get("id", "node_%s" % ni)))
		var material := MATERIALS.find(str(node.get("material", "flesh")))
		material = maxi(material, 0)
		node_materials.append(material)
		node_blends.append(maxf(float(node.get("blend", 0.15)), 0.001))
		# Both biological IDs remain in the arrays; only the owner compiles.
		if BodyGroupField.marked(node) and str(node.id) != str(node.shape[BodyGroupField.KEY].owner_id): continue
		if EnvelopeField.marked(node) and str(node.id) != str(node.shape[EnvelopeField.KEY].owner_id): continue
		var kind := str(node.get("kind", "mass"))
		var is_cavity := kind == "cavity" or str(node.get("operation", "union")) == "subtract"
		if BlobHangingTissue.marked(node) and not BlobHangingTissue.valid_host(source_dna, node):
			preparation_errors.append("Invalid hanging tissue host " + str(node.id)); continue
		if BlobHangingRoot.marked(node) and not BlobHangingRoot.valid_host(source_dna, node):
			preparation_errors.append("Invalid hanging root host " + str(node.id)); continue
		if BlobGrownContact.marked(node) and not BlobGrownContact.valid_host(source_dna,node):
			preparation_errors.append("Invalid versioned Blob grown contact: " + str(node.id)); continue
		if BlobGrown.marked(node) and not BlobGrown.valid_host(source_dna,node):
			preparation_errors.append("Invalid grown envelope host " + str(node.id)); continue
		if (BlobMantle.marked(node) or BlobButtress.marked(node)) and not BlobMantle.valid_host(source_dna,node,BlobButtress.marked(node)):
			preparation_errors.append("Invalid mantle shape host " + str(node.id)); continue
		var patch_mark: Variant = node.get("porous_patch", {})
		var patch_points: Variant = node.get("points", [])
		var patch_requested := str(source_dna.get("type", "")) == "Blob" and patch_mark is Dictionary and bool(patch_mark.get("enabled", false))
		if patch_requested and (kind != "mass" or is_cavity or not patch_points is Array or not patch_points.is_empty() or str(node.get("role", "")) in ["fold", "tendon"] or str(node.get("shape", {}).get("geometry", "")) == "detail"):
			preparation_errors.append("Enabled Blob compound patch requires one additive primary-volume mass node: " + str(node.id))
			continue
		if kind in ["module", "joint", "sensor"] or str(node.get("role", "")) == "tendon" or str(node.get("shape", {}).get("geometry", "")) == "detail":
			continue
		if kind == "curve" or (node.has("points") and node.points.size() > 1):
			var mantle_buttress := BlobButtress.marked(node)
			var grown_contact := BlobGrownContact.marked(node)
			var hanging_root := BlobHangingRoot.marked(node)
			var curve: Dictionary = Curves.sample(node, BlobButtress.SUBDIVISIONS if mantle_buttress or grown_contact or hanging_root else ([3, 5, 7][quality] if not is_cavity else 3), not is_cavity)
			var points: PackedVector3Array = curve.points
			var radii: PackedFloat32Array = curve.radii
			var shape: Dictionary = node.get("shape", {})
			var width := clampf(float(shape.get("width", 1.0)), 0.25, 4.0)
			var depth := clampf(float(shape.get("depth", 1.0)), 0.10, 2.0)
			var previous_across := Vector3.ZERO
			var arc_distance := 0.0
			for si in range(points.size() - 1):
				if points[si].distance_squared_to(points[si + 1]) < 0.0000001:
					continue
				var item := Influence.new()
				item.node_index = ni
				item.material = material
				item.is_curve = true
				if mantle_buttress or grown_contact or hanging_root: item.preserve_thickness = false
				if str(node.get("role", "")) == "fold":
					item.preserve_thickness = false
					item.surface_parent = node_ids.find(str(node.get("parent", "")))
				item.subtract = is_cavity
				item.position = points[si]
				item.end = points[si + 1]
				item.segment = item.end - item.position
				item.inverse_length_squared = 1.0 / item.segment.length_squared()
				item.radius_a = radii[si]
				item.radius_b = radii[si + 1]
				var t0 := float(si) / float(points.size() - 1)
				var t1 := float(si + 1) / float(points.size() - 1)
				item.width_a = width * Curves.profile_value(shape.get("width_profile", []), t0)
				item.width_b = width * Curves.profile_value(shape.get("width_profile", []), t1)
				item.depth_a = depth * Curves.profile_value(shape.get("depth_profile", []), t0)
				item.depth_b = depth * Curves.profile_value(shape.get("depth_profile", []), t1)
				item.elliptical = grown_contact or hanging_root or absf(item.width_a - 1.0) + absf(item.width_b - 1.0) + absf(item.depth_a - 1.0) + absf(item.depth_b - 1.0) > 0.0001
				item.axial = item.segment.normalized()
				item.across = previous_across - item.axial * previous_across.dot(item.axial)
				if item.across.length_squared() < 0.01:
					item.across = item.axial.cross(Vector3.UP if absf(item.axial.y) < 0.9 else Vector3.FORWARD)
				item.across = item.across.normalized()
				item.depth_axis = item.axial.cross(item.across).normalized()
				previous_across = item.across
				item.blend = maxf(float(node.get("blend", 0.12)), 0.001)
				item.amplitude = _noise_amplitude(node, minf(item.radius_a, item.radius_b))
				_configure_deformation(item, node, arc_distance)
				arc_distance += item.segment.length()
				_update_influence_bounds(item)
				influences.append(item)
		else:
			var item := Influence.new()
			item.node_index = ni
			item.material = material
			item.subtract = is_cavity
			item.position = Curves.vector(node.get("position", [0.0, 0.0, 0.0]))
			item.radii = Curves.vector(node.get("size", [0.5, 0.5, 0.5]), Vector3.ONE * 0.5).abs().max(Vector3.ONE * 0.006)
			if str(node.get("role", "")) in ["head", "palm"]:
				item.radii *= clampf(float(node.get("shape", {}).get("carrier_scale", 1.0)), 0.2, 1.0)
			item.shape_power = 2.0 + 2.0 * clampf(float(node.get("shape", {}).get("squareness", 0.0)), 0.0, 1.0)
			item.inverse_radii = Vector3.ONE / item.radii
			item.inverse_squared = Vector3.ONE / (item.radii * item.radii)
			var rotation: Variant = node.get("rotation", node.get("orientation", []))
			if rotation is Array and rotation.size() == 3:
				item.inverse_basis = Basis.from_euler(Curves.vector(rotation)).inverse()
				item.rotated = not Curves.vector(rotation).is_zero_approx()
			elif rotation is Array and rotation.size() == 4:
				item.inverse_basis = Basis(Quaternion(float(rotation[0]), float(rotation[1]), float(rotation[2]), float(rotation[3])).normalized()).inverse()
				item.rotated = true
			item.blend = maxf(float(node.get("blend", 0.16)), 0.001)
			item.amplitude = _noise_amplitude(node, minf(item.radii.x, minf(item.radii.y, item.radii.z)))
			if not is_cavity:
				var irregularity := float(source_dna.get("settings", {}).get("irregularity", 0.45))
				var role := str(node.get("role", "mass"))
				item.sculpt_strength = (0.12 + irregularity * 0.17) * clampf(float(node.get("shape", {}).get("sculpt_strength", 1.0)), 0.0, 1.0)
				if role in ["head", "joint", "digit", "palm", "foot"]:
					item.sculpt_strength *= 0.24
				if role == "palm" and item.shape_power > 2.001:
					item.sculpt_strength = 0.0
				if role == "torso":
					item.sculpt_mode = 1
				elif role in ["core", "abdomen"]:
					item.sculpt_mode = 2
				elif role == "head":
					item.sculpt_mode = 3
				elif role == "pelvis":
					item.sculpt_mode = 4
				elif role in ["joint", "knee", "elbow"]:
					item.sculpt_mode = 5
				item.sculpt_phase = float((int(source_dna.get("seed", 1)) + ni * 7919) % 6283) * 0.001
				# Separate Stage-1 ablations: v3 removes only the elevated core's
				# inappropriate floor plane; v4 also applies pressure profiles.
				# Generation settings select markers. Existing saved shape data
				# is authoritative and is already included in geometry cache keys.
				if str(source_dna.get("type", "")) == "Blob":
					var shape: Dictionary = node.get("shape", {})
					if role == "core" and int(shape.get("loaded_upper_floor_off", 0)) == 1:
						item.sculpt_mode = 0
					var pressure: Dictionary = shape.get("loaded_contact_profile", {})
					if not pressure.is_empty():
						item.loaded_pressure = BlobLoadedPressure.create(pressure, item.radii, item.sculpt_strength, item.sculpt_phase)
						if not bool(item.loaded_pressure.valid):
							preparation_errors.append("Invalid loaded pressure profile " + str(node.id))
							continue
			_configure_deformation(item, node)
			if BodyGroupField.marked(node) or EnvelopeField.marked(node):
				item.body_envelope = MassReprofileField.create(node) if MassReprofileField.marked(node) else (BodyGroupField.create(node) if BodyGroupField.marked(node) else EnvelopeField.create(node))
				if not item.body_envelope.valid:
					preparation_errors.append(str(item.body_envelope.error)); continue
				item.blend = item.body_envelope.blend
				item.amplitude = 0.0; item.sculpt_strength = 0.0; item.sculpt_mode = 0
				for member_id: String in item.body_envelope.member_ids:
					for member_index in range(nodes.size()):
						if str(nodes[member_index].id) == member_id: item.member_indices.append(member_index)
			if BlobHangingTissue.marked(node):
				item.grown_field = BlobHangingTissue.create(node.shape.hanging_tissue, item.radii)
				if not item.grown_field.valid:
					preparation_errors.append("Invalid hanging tissue " + str(node.id)); continue
				item.amplitude = 0.0; item.sculpt_strength = 0.0; item.sculpt_mode = 0
			if BlobGrown.marked(node):
				item.grown_field = BlobGrown.create(node.shape.grown_envelope,item.radii)
				if not item.grown_field.valid:
					preparation_errors.append("Invalid grown envelope " + str(node.id)); continue
				item.amplitude = 0.0; item.sculpt_strength = 0.0; item.sculpt_mode = 0
			if BlobMantle.marked(node):
				item.mantle_field = BlobMantle.create(node.shape.mantle_envelope,item.radii)
				if not item.mantle_field.valid:
					preparation_errors.append("Invalid mantle envelope " + str(node.id)); continue
				item.amplitude = 0.0; item.sculpt_strength = 0.0; item.sculpt_mode = 0
			if patch_requested:
				item.porous_patch = BlobPatchField.create(patch_mark, item.radii)
				if not bool(item.porous_patch.valid):
					preparation_errors.append("Invalid Blob compound patch " + str(node.id) + ": " + str(item.porous_patch.error))
					continue
				item.amplitude = 0.0
				item.sculpt_strength = 0.0
			_update_influence_bounds(item)
			influences.append(item)
	for item in influences:
		var owner_id: String = str(nodes[item.node_index].get(GroupField.LINK,""))
		if group_fields.has(owner_id):
			item.sac_group = group_fields[owner_id]
			_update_influence_bounds(item)
	for item in influences:
		if item.subtract:
			continue
		if not have_bounds:
			bounds = item.bounds
			have_bounds = true
		else:
			bounds = bounds.merge(item.bounds)
	# Explicit Blob-only opt-in. Legacy and unmarked influences are untouched.
	if str(source_dna.get("type", "")) == "Blob" and bool(source_dna.get("settings", {}).get("blob_contained_lip_candidate", false)):
		var scale_value := maxf(float(source_dna.get("settings", {}).get("size", 1.0)), 0.05)
		for item in influences:
			var node: Dictionary = nodes[item.node_index]
			var mark: Dictionary = node.get("contained_lip", {})
			if not item.subtract or item.is_curve or mark.is_empty() or bool(node.get("surface_opening", false)): continue
			var broad_v2 := int(mark.get("version", 0)) == 2 and str(mark.get("profile", "")) == "broad_host_collar_v2" and str(source_dna.get("settings", {}).get("blob_contained_lip_profile", "")) == "broad_host_collar_v2"
			if (int(mark.get("version", 0)) != 1 and not broad_v2) or str(mark.get("composition", "")) != "post_subtraction_union_with_protected_throat": continue
			var safety: Dictionary = node.get("porous_growth", {})
			if not bool(safety.get("complete_rim", false)) or not bool(safety.get("back_wall", false)): continue
			var radius := float(mark.get("radius", 0.0)) * scale_value
			var maximum := minf(minf(float(safety.get("minimum_wall", 0.0)) * scale_value * 0.65, minf(item.radii.x, item.radii.y) * 0.60), minf(item.radii.z * 0.20, float(safety.get("host_thickness", 0.0)) * scale_value * 0.08))
			if broad_v2:
				# Versioned anatomical width, not a resolution-dependent inflation.
				# The existing collar, backing, throat and 2.2-cell gates still apply.
				maximum = minf(minf(float(safety.get("minimum_wall", 0.0)) * scale_value * 0.95, minf(item.radii.x, item.radii.y) * 0.72), minf(item.radii.z * 0.22, float(safety.get("host_thickness", 0.0)) * scale_value * 0.08))
			var owner := node_ids.find(str(mark.get("host_id", "")))
			if radius <= 0.0 or radius > maximum * 1.00001 or owner < 0 or str(nodes[owner].get("kind", "")) == "cavity": continue
			var samples: Array = mark.get("local_intersection_samples", [])
			if samples.size() != 32: continue
			var basis := item.inverse_basis.inverse()
			item.contained_lip_bounds = AABB(item.position + basis * Curves.vector(samples[0]) * scale_value, Vector3.ZERO)
			for sample in samples:
				item.contained_lip_bounds = item.contained_lip_bounds.expand(item.position + basis * Curves.vector(sample) * scale_value)
			item.contained_lip_bounds = item.contained_lip_bounds.grow(radius * 2.0)
			item.contained_lip_radius = radius
			item.contained_lip_minimum_radius = radius * 0.84
			item.contained_lip_owner = owner
			_update_influence_bounds(item)
			contained_lips.append(item)
			bounds = bounds.merge(item.contained_lip_bounds)

	_check_envelope_operations()

func _check_envelope_operations() -> void:
	if source_dna.get("settings",{}).get(EnvelopeField.SETTING,EnvelopeField.OFF)==EnvelopeField.OFF: return
	var expected: Array=[]; var observed: Array=[]; var group: RefCounted=null
	for item: Influence in influences:
		if item.body_envelope!=null: group=item.body_envelope
	if group==null: preparation_errors.append("201b missing unique bounded group."); return
	var evaluated_context: Array=group.descriptor.base_group.union_context if group.descriptor.get("mode")==MassReprofileField.MODE else group.descriptor.union_context
	for entry: Dictionary in evaluated_context:
		if entry.id==group.owner_id or entry.id not in group.member_ids: expected.append({"id":entry.id,"blend":group.blend if entry.id==group.owner_id else float(entry.blend)})
	var cavity_active: bool=Cavity217.enabled(source_dna)
	var observed_voids: Array[String]=[]
	if cavity_active:
		var cavity_checked: Dictionary=Cavity217.validate_restored(source_dna)
		if not cavity_checked.ok:preparation_errors.append(cavity_checked.error);return
	for item: Influence in influences:
		if item.amplitude!=0.0 or item.lip_radius!=0.0 or item.contained_lip_radius!=0.0:
			preparation_errors.append("201b actual field operations exceed the frozen positive union context."); return
		if item.subtract:
			if not cavity_active:
				preparation_errors.append("201b actual field operations exceed the frozen positive union context.");return
			if item.node_index not in [13,14] or item.is_curve or item.sac_group!=null or item.body_envelope!=null or item.sculpt_strength!=0.0:
				preparation_errors.append("217 permits only its two fixed unwarped void influences.");return
			observed_voids.append(node_ids[item.node_index])
			continue
		var entry: Dictionary={"id":node_ids[item.node_index],"blend":item.blend}
		if not observed.is_empty() and observed[-1].id==entry.id:
			if observed[-1]!=entry: preparation_errors.append("201b curve subsegments disagree on their one biological union blend."); return
		else: observed.append(entry)
	if observed!=expected: preparation_errors.append("201b actual evaluated union sequence differs from the frozen descriptor.")
	if cavity_active and observed_voids!=Cavity217.ids_for(source_dna):preparation_errors.append("223 actual one-void suffix differs from its declaration." if Cavity217.single_enabled(source_dna) else "217 actual void suffix differs from the declared two cavities.")

func _tendon_surface(point: Vector3, radius: float, follow: bool, burial_factor: float = 0.20) -> Dictionary:
	var p := point
	if follow and _envelope_value(point) < -radius * 3.5:
		follow = false
	var epsilon := maxf(step * 0.20, 0.002)
	var normal := Vector3.UP
	for iteration in range(6 if follow else 1):
		normal = Vector3(
			_envelope_value(p + Vector3.RIGHT * epsilon) - _envelope_value(p - Vector3.RIGHT * epsilon),
			_envelope_value(p + Vector3.UP * epsilon) - _envelope_value(p - Vector3.UP * epsilon),
			_envelope_value(p + Vector3.BACK * epsilon) - _envelope_value(p - Vector3.BACK * epsilon)).normalized()
		if normal.length_squared() < 0.01:
			normal = Vector3.UP
			break
		if not follow:
			break
		# Keep broad fascicles partly in their host, and away from facial details.
		var burial := radius * (clampf(burial_factor, 0.0, 1.5) + (1.0 - _protection(p)) * 2.5)
		var distance := _envelope_value(p) + burial
		if absf(distance) < step * 0.03:
			break
		p -= normal * clampf(distance, -radius * 1.2, radius * 1.2)
	return {"position": p, "normal": normal}

func _envelope_value(point: Vector3) -> float:
	return _field_value(point, _tile_at(point), true, false)

func _expose_surface_cavities(nodes: Array) -> void:
	# Designer-authored open pockets attach to the true outer union envelope,
	# not to a buried nominal ellipsoid surface. Internal cavities stay internal.
	var offsets: Dictionary = {}
	for item in influences:
		if not item.subtract:
			continue
		var node: Dictionary = nodes[item.node_index]
		if not bool(node.get("surface_opening", false)):
			continue
		var normal := Curves.vector(node.get("normal", [0, 0, -1]), Vector3.FORWARD).normalized()
		var extent := maxf(item.radii.x, maxf(item.radii.y, item.radii.z))
		var crossing := _seat_crossing(item.position, normal, maxf(extent * 2.5, step * 4.0), [])
		if crossing.x < 0.5:
			continue
		var old := item.position
		var surface := old + normal * crossing.y
		item.position = surface - normal * item.radii.z * 0.40
		item.inverse_basis = Curves.attachment_frame(surface, normal).basis.inverse()
		item.rotated = true
		item.lip_radius = clampf(minf(item.radii.x, item.radii.y) * 0.12, step * 0.85, step * 1.6)
		offsets[str(node.get("id", ""))] = {"delta": item.position - old, "rim_delta": surface - old + normal * item.radii.z * 0.18}
		_update_influence_bounds(item)
	for item in influences:
		var cavity_id := str(nodes[item.node_index].get("cavity_id", ""))
		if cavity_id.is_empty() or not offsets.has(cavity_id):
			continue
		var delta: Vector3 = offsets[cavity_id].rim_delta
		item.position += delta
		if item.is_curve:
			item.end += delta
		_update_influence_bounds(item)
	if not offsets.is_empty():
		_build_tiles()

func _surface_material_at(point: Vector3) -> String:
	var nearest := INF
	var material := 0
	for index in _tile_at(point):
		var item := influences[index]
		if item.subtract:
			continue
		var distance := absf(item.distance(point))
		if distance < nearest:
			nearest = distance
			material = item.material
	return MATERIALS[material]

func _attachment_value(point: Vector3) -> float:
	if not slab_axes.is_empty() and not attachment_lattice.is_empty():return SlabGrid.tetrahedral_validated(point,attachment_lattice,slab_dimensions,slab_axes,step*12.0,slab_high_preview)
	# Exact affine field of the SAME six tetrahedra used by MeshExtractor.
	# Analytic and trilinear fields can disagree with a coarse extracted pocket.
	if attachment_lattice.is_empty(): return sample_signed_distance(point)
	var cell := (point - bounds.position) / step
	if cell.x < 0 or cell.y < 0 or cell.z < 0 or cell.x >= grid_dimensions.x - 1 or cell.y >= grid_dimensions.y - 1 or cell.z >= grid_dimensions.z - 1:
		return step * 12.0
	var ix := floori(cell.x); var iy := floori(cell.y); var iz := floori(cell.z)
	var q := cell - Vector3(ix, iy, iz)
	var row := grid_dimensions.x
	var plane := row * grid_dimensions.y
	var base := ix + iy * row + iz * plane
	var first := 1; var second := row
	var high := q.x; var middle := q.y; var low := q.z
	if q.x >= q.y:
		if q.y >= q.z:
			pass
		elif q.x >= q.z:
			second = plane; middle = q.z; low = q.y
		else:
			first = plane; second = 1; high = q.z; middle = q.x; low = q.y
	else:
		if q.x >= q.z:
			first = row; second = 1; high = q.y; middle = q.x; low = q.z
		elif q.y >= q.z:
			first = row; second = plane; high = q.y; middle = q.z; low = q.x
		else:
			first = plane; second = row; high = q.z; middle = q.y; low = q.x
	return attachment_lattice[base] * (1.0 - high) + attachment_lattice[base + first] * (high - middle) + attachment_lattice[base + first + second] * (middle - low) + attachment_lattice[base + 1 + row + plane] * low

func _embed_tendon_endpoint(point: Vector3, radius: float) -> Vector3:
	var p := point
	var epsilon := maxf(step * 0.08, 0.0005)
	var margin := maxf(radius * 0.75, step * 0.18)
	for _iteration in range(16):
		var distance := _attachment_value(p)
		if distance < -margin:
			return p
		var gradient := Vector3(
			_attachment_value(p + Vector3.RIGHT * epsilon) - _attachment_value(p - Vector3.RIGHT * epsilon),
			_attachment_value(p + Vector3.UP * epsilon) - _attachment_value(p - Vector3.UP * epsilon),
			_attachment_value(p + Vector3.BACK * epsilon) - _attachment_value(p - Vector3.BACK * epsilon)).normalized()
		if gradient.length_squared() < 0.01:
			break
		p -= gradient * clampf(distance + margin * 1.1, 0.0, maxf(radius * 2.0, step))
	if _attachment_value(p) < -step * 0.03:
		return p
	# A narrow pocket can trap gradient descent between opposing walls.
	# Search a bounded local neighborhood for an actual negative grid corner.
	# Such corners are strictly inside the extracted tetrahedral surface.
	if not attachment_lattice.is_empty():
		if not slab_axes.is_empty():return _slab_tendon_corner210(p,point)
		var center := Vector3i((p - bounds.position) / step)
		var best := p
		var best_distance := INF
		for z in range(maxi(center.z - 8, 1), mini(center.z + 9, grid_dimensions.z - 1)):
			for y in range(maxi(center.y - 8, 1), mini(center.y + 9, grid_dimensions.y - 1)):
				for x in range(maxi(center.x - 8, 1), mini(center.x + 9, grid_dimensions.x - 1)):
					var index := x + y * grid_dimensions.x + z * grid_dimensions.x * grid_dimensions.y
					if attachment_lattice[index] >= -step * 0.12: continue
					var candidate := bounds.position + Vector3(x, y, z) * step
					var distance := candidate.distance_squared_to(point)
					if distance < best_distance:
						best = candidate; best_distance = distance
		return best
	return p

func _configure_deformation(item: Influence, node: Dictionary, arc_distance: float = 0.0) -> void:
	# Semantic masks come from anatomy, never arithmetic on material indices.
	# The medium field follows local tissue axes; the large band stays in a
	# coherent organism-wide domain. Existing deformation DNA now has effect.
	var role := str(node.get("role", "mass"))
	var deformation: Dictionary = node.get("deformation", {})
	var flow := 1.0 if item.is_curve else 0.15
	if role in ["muscle", "muscle_fan", "tendon", "ligament", "root"]: flow = 0.9
	var joint := 1.0 if role in ["joint", "knee", "elbow", "fold"] else 0.0
	var hard := 1.0 if item.material in [3, 4, 7] else 0.0
	item.noise_context = Vector4(flow, joint, hard, clampf(float(deformation.get("warp", 0.3)), 0.0, 1.0))
	item.fold_frequency = clampf(float(deformation.get("fold_frequency", 2.8)), 0.5, 8.0)
	item.noise_origin = item.position
	item.noise_basis = Basis(item.across, item.axial, item.depth_axis).transposed() if item.is_curve else item.inverse_basis
	var phase := fposmod(float(deformation.get("phase", item.sculpt_phase)), 100.0) * 0.025
	item.noise_offset = Vector3(phase, arc_distance, phase * 0.73)
	if role in ["head", "digit", "palm", "foot"]:
		item.amplitude *= 0.35
	elif hard > 0.5:
		item.amplitude *= 0.55

func _noise_amplitude(node: Dictionary, radius: float) -> float:
	var value: Variant = node.get("noise", 0.06)
	var amplitude := clampf(float(value.get("amplitude", 0.06)) if value is Dictionary else float(value), 0.0, 0.23)
	# Keep material hardness and the authored zero-amplitude control meaningful.
	# Anatomical gains are bounded by local thickness, before face/joint masks.
	var role := str(node.get("role", "mass"))
	var hard := str(node.get("material", "flesh")) in ["chitin", "bone", "crystal"]
	if regional_noise_gain.has(role) and not hard:
		amplitude = minf(amplitude * clampf(float(regional_noise_gain[role]), 0.0, 6.0), 0.35)
	return amplitude * radius

func _update_influence_bounds(item: Influence) -> void:
	var padding := item.blend * 1.05 + item.amplitude * 1.8 + item.lip_radius * 1.5
	if item.contained_lip_radius > 0.0: padding += item.contained_lip_radius * 2.0
	if item.body_envelope != null:
		item.bounds = item.body_envelope.bounds_for_padding(padding)
		if not item.bounds.position.is_finite() or not item.bounds.size.is_finite(): preparation_errors.append("201 finite halo bounds rejected actual padding.")
		return
	if item.sac_group != null:
		# Inverse bounds of the inherited five triangular sculpt operations, then
		# global interval bounds of the shared positive-scale group map.
		var strength: float = item.sculpt_strength
		var extent: Vector3 = item.radii*Vector3(1.0/(1.0-0.65*strength)+1.24*strength,1.0+0.30*strength,1.0/(1.0-0.60*strength)+1.04*strength)+Vector3.ONE*padding
		item.bounds = item.sac_group.forward_bounds(AABB(item.position-extent,extent*2.0))
		return
	if item.grown_field != null:
		var local_box: AABB = item.grown_field.local_bounds
		var basis := item.inverse_basis.inverse()
		item.bounds = AABB(item.position+basis*local_box.position,Vector3.ZERO)
		for corner in range(8):
			item.bounds = item.bounds.expand(item.position+basis*(local_box.position+Vector3(local_box.size.x if corner&1 else 0.0,local_box.size.y if corner&2 else 0.0,local_box.size.z if corner&4 else 0.0)))
		item.bounds = item.bounds.grow(padding)
		return
	if item.mantle_field != null:
		var local_box: AABB = item.mantle_field.local_bounds
		var basis := item.inverse_basis.inverse()
		item.bounds = AABB(item.position+basis*local_box.position,Vector3.ZERO)
		for corner in range(8):
			item.bounds = item.bounds.expand(item.position+basis*(local_box.position+Vector3(local_box.size.x if corner&1 else 0.0,local_box.size.y if corner&2 else 0.0,local_box.size.z if corner&4 else 0.0)))
		item.bounds = item.bounds.grow(padding)
		return
	if item.loaded_pressure != null:
		var local_extent: Vector3 = item.loaded_pressure.local_bounds.size * 0.5
		var basis := item.inverse_basis.inverse()
		var extent := basis.x.abs() * local_extent.x + basis.y.abs() * local_extent.y + basis.z.abs() * local_extent.z + Vector3.ONE * padding
		item.bounds = AABB(item.position - extent, extent * 2.0)
		return
	if item.porous_patch != null:
		var local_box: AABB = item.porous_patch.local_bounds
		var basis := item.inverse_basis.inverse()
		var first := true
		for corner in range(8):
			var local := local_box.position + Vector3(local_box.size.x if corner & 1 else 0.0, local_box.size.y if corner & 2 else 0.0, local_box.size.z if corner & 4 else 0.0)
			var point := item.position + basis * local
			if first: item.bounds = AABB(point, Vector3.ZERO); first = false
			else: item.bounds = item.bounds.expand(point)
		item.bounds = item.bounds.grow(padding)
		return
	if item.is_curve:
		var radius := maxf(item.radius_a, item.radius_b)
		var extent := Vector3.ONE * radius
		if item.elliptical:
			# Conservative oriented ellipsoid support, including axial end caps.
			extent = (item.across.abs() * maxf(item.width_a, item.width_b) + item.depth_axis.abs() * maxf(item.depth_a, item.depth_b) + item.axial.abs()) * radius
		extent += Vector3.ONE * padding
		var low := item.position.min(item.end) - extent
		var high := item.position.max(item.end) + extent
		item.bounds = AABB(low, high - low)
	else:
		var extent := item.radii * (1.0 + item.sculpt_strength * 1.2)
		if item.rotated:
			var basis := item.inverse_basis.inverse()
			extent = (basis.x.abs() * item.radii.x + basis.y.abs() * item.radii.y + basis.z.abs() * item.radii.z) * (1.0 + item.sculpt_strength * 1.2)
		extent += Vector3.ONE * padding
		item.bounds = AABB(item.position - extent, extent * 2.0)

func _conform_surface_folds() -> void:
	# Anatomical ribs/tendon creases follow the sculpted carrier, not its old
	# quadric scaffold. Their narrow cross-section may simplify at preview LOD.
	for item in influences:
		if item.surface_parent < 0:
			continue
		var host: Influence = null
		for candidate in influences:
			if candidate.represents_node(item.surface_parent) and not candidate.is_curve and not candidate.subtract:
				host = candidate
				break
		if host == null:
			continue
		item.position = _project_fold_point(item.position, host, item.radius_a)
		item.end = _project_fold_point(item.end, host, item.radius_b)
		item.segment = item.end - item.position
		item.inverse_length_squared = 1.0 / maxf(item.segment.length_squared(), 0.0000001)
		_update_influence_bounds(item)

func _project_fold_point(point: Vector3, host: Influence, radius: float) -> Vector3:
	var direction := (point - host.position).normalized()
	if direction.length_squared() < 0.01:
		return point
	var p := point
	for _iteration in range(6):
		p -= direction * clampf(host.distance(p), -host.radii.length() * 0.15, host.radii.length() * 0.15)
	return p - direction * radius * 0.28

func _configure_grid(quality: int) -> void:
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	step = maxf(longest / float(QUALITY_AXIS[quality]), 0.004) * budget_spacing_scale
	# Isotropic voxels preserve appendages irrespective of orientation. Total
	# volume budget scales cell size, never truncates an already extracted mesh.
	for _iteration in range(8):
		grid_dimensions = Vector3i(ceili(bounds.size.x / step) + 5, ceili(bounds.size.y / step) + 5, ceili(bounds.size.z / step) + 5)
		var count: int = grid_dimensions.x * grid_dimensions.y * grid_dimensions.z
		if count <= QUALITY_SAMPLES[quality]:
			break
		step *= pow(float(count) / float(QUALITY_SAMPLES[quality]), 1.0 / 3.0) * 1.015
	bounds.position -= Vector3.ONE * (step * 2.0)
	bounds.size = Vector3(grid_dimensions - Vector3i.ONE) * step
	tile_dimensions = Vector3i(ceili(float(grid_dimensions.x) / TILE_CELLS), ceili(float(grid_dimensions.y) / TILE_CELLS), ceili(float(grid_dimensions.z) / TILE_CELLS))

func _preserve_thin_features() -> void:
	for item in influences:
		if item.is_curve and not item.subtract and item.preserve_thickness:
			var minimum := step * 0.95
			if minf(item.radius_a, item.radius_b) < minimum:
				geometry_adjustments.thin_features.append({"node_id": str(node_ids[item.node_index]), "start": _json_point(item.position), "end": _json_point(item.end), "original_radii": [item.radius_a, item.radius_b], "minimum_radius": minimum})
				item.radius_a = maxf(item.radius_a, minimum)
				item.radius_b = maxf(item.radius_b, minimum)
				thin_features_preserved += 1
				_update_influence_bounds(item)

func _ensure_growth_attachments(nodes: Array) -> void:
	# Bulk sculpting can move a nominal parent surface away from a child's
	# original socket. Preserve the graph's explicit connection with a short
	# biological collar when the analytic parent/child fields leave a gap.
	# This repairs the volume before extraction, never deletes detached meshes.
	var groups: Array = []
	groups.resize(nodes.size())
	for i in range(groups.size()):
		groups[i] = []
	for item in influences:
		if not item.subtract:
			groups[item.node_index].append(item)
			if item.body_envelope != null:
				for member_index in item.member_indices:
					if member_index != item.node_index: groups[member_index].append(item)
	var collars: Array[Influence] = []
	for ni in range(nodes.size()):
		var node: Dictionary = nodes[ni]
		if str(node.get("kind", "mass")) == "cavity" or str(node.get("role", "")) == "fold":
			continue
		if not groups[ni].is_empty() and groups[ni][0].porous_patch != null:
			var patch: Influence = groups[ni][0]
			var failure := _validate_porous_patch_attachment(patch, groups)
			if not failure.is_empty():
				preparation_errors.append("Unsafe Blob compound patch attachment " + str(node.id) + ": " + failure)
			else:
				if not geometry_adjustments.has("porous_patch_attachments"): geometry_adjustments["porous_patch_attachments"] = []
				geometry_adjustments.porous_patch_attachments.append({"node_id": str(node.id), "validated_margin_samples": 6, "center_collar_bypassed": true})
			# A failed marked patch is an error, not a solid fallback or a center
			# bridge that could close the intentionally open local pores.
			continue
		var pi := node_ids.find(str(node.get("parent", "")))
		if pi < 0 or groups[ni].is_empty() or groups[pi].is_empty():
			continue
		var child: Influence = groups[ni][0]
		var parent_envelope: Influence = null
		for parent: Influence in groups[pi]:
			if parent.body_envelope != null: parent_envelope = parent
		if child.body_envelope != null and child == parent_envelope:
			# One continuous group, not two copied fields or a generic collar.
			if child.distance(Curves.vector(nodes[ni].position)) >= 0.0 or child.distance(Curves.vector(nodes[pi].position)) >= 0.0:
				preparation_errors.append("201 internal member center is not inside its actual shared envelope.")
			continue
		if parent_envelope != null and child.is_curve:
			var required := child.radius_a * 0.20
			if parent_envelope.distance(child.position) > -required:
				preparation_errors.append("201 unchanged support root lacks required actual shared-parent burial: " + str(node.id))
				continue
		# No implicit repair geometry for a common group. Its actual complete-field
		# root path is qualified before extraction; a failure aborts, not repairs.
		if child.sac_group != null: continue
		var attachment := child.position
		var nearest := Vector3.ZERO
		var nearest_distance := INF
		var parent_radius := step
		for parent: Influence in groups[pi]:
			var candidate := parent.position
			if parent.is_curve:
				var t := clampf((attachment - parent.position).dot(parent.segment) * parent.inverse_length_squared, 0.0, 1.0)
				candidate += parent.segment * t
			var distance := candidate.distance_squared_to(attachment)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
				parent_radius = maxf(parent.radius_a, parent.radius_b) if parent.is_curve else minf(parent.radii.x, minf(parent.radii.y, parent.radii.z))
		if nearest_distance < step * step:
			continue
		var needs_collar := false
		for sample_index in range(1, 12):
			var point := nearest.lerp(attachment, float(sample_index) / 12.0)
			var child_distance := INF
			var parent_distance := INF
			for item: Influence in groups[ni]:
				child_distance = minf(child_distance, item.distance(point))
			for item: Influence in groups[pi]:
				parent_distance = minf(parent_distance, item.distance(point))
			if SDF.smooth_union(child_distance, parent_distance, child.blend) > -step * 0.18:
				needs_collar = true
				break
		if not needs_collar:
			continue
		if parent_envelope != null or child.body_envelope != null:
			preparation_errors.append("201 attachment would require forbidden repair: " + str(node.id))
			continue
		var child_radius := child.radius_a if child.is_curve else minf(child.radii.x, minf(child.radii.y, child.radii.z))
		var collar := Influence.new()
		collar.node_index = ni
		collar.is_curve = true
		collar.position = nearest
		collar.end = attachment
		collar.segment = attachment - nearest
		collar.inverse_length_squared = 1.0 / maxf(collar.segment.length_squared(), 0.0000001)
		collar.radius_a = maxf(step * 1.05, minf(child_radius, parent_radius) * 0.55)
		collar.radius_b = maxf(step * 1.05, child_radius * 0.70)
		collar.blend = minf(child.blend, collar.radius_a)
		collar.amplitude = minf(child.amplitude, collar.radius_a * 0.06)
		collar.material = child.material
		_update_influence_bounds(collar)
		collars.append(collar)
		geometry_adjustments.attachment_collars.append({"node_id": str(node_ids[ni]), "parent_id": str(node_ids[pi]), "start": _json_point(collar.position), "end": _json_point(collar.end), "radii": [collar.radius_a, collar.radius_b], "blend": collar.blend})
		attachment_repairs += 1
	if not collars.is_empty():
		influences.append_array(collars)
		influences.sort_custom(func(a: Influence, b: Influence) -> bool: return a.node_index < b.node_index)

func _validate_porous_patch_attachment(patch: Influence, groups: Array) -> String:
	if not bool(patch.porous_patch.validated_attachment_contract()): return "Missing validated six-margin contract."
	var samples: Array = patch.porous_patch.attachment_samples()
	if samples.size() != 6: return "Expected exactly six attachment margins."
	var basis := patch.inverse_basis.inverse()
	for sample: Dictionary in samples:
		var local: Vector3 = sample.local_point
		var required: float = sample.required_clearance
		var point := patch.position + basis * local
		if patch.porous_patch.distance(local) > -required: return "A declared margin is not inside the actual compound field."
		var host_index := node_ids.find(str(sample.host_id))
		if host_index < 0 or host_index == patch.node_index or groups[host_index].is_empty(): return "A declared existing host is missing."
		var host_distance := INF
		for host: Influence in groups[host_index]:
			# Sculpting is already in distance(); reserve the same bounded
			# anatomical displacement allowance used by influence bounds.
			host_distance = minf(host_distance, host.distance(point) + host.amplitude * 1.8)
		if host_distance > -required: return "A margin lacks required current-host tissue backing."
		for cutter: Influence in influences:
			if cutter.subtract and cutter.distance(point) < required + minf(cutter.blend, step * 1.2): return "A margin conflicts with an existing cavity."
	return ""

func _build_tiles() -> void:
	tiles.clear()
	tiles.resize(tile_dimensions.x * tile_dimensions.y * tile_dimensions.z)
	for i in range(tiles.size()):
		tiles[i] = PackedInt32Array()
	var width := step * float(TILE_CELLS)
	for i in range(influences.size()):
		var box := influences[i].bounds.grow(step * 2.5)
		var low := Vector3i(((box.position - bounds.position) / width).floor()).max(Vector3i.ZERO)
		var high := Vector3i(((box.end - bounds.position) / width).floor()).min(tile_dimensions - Vector3i.ONE)
		for z in range(low.z, high.z + 1):
			for y in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):
					var ti: int = x + y * tile_dimensions.x + z * tile_dimensions.x * tile_dimensions.y
					var bucket: PackedInt32Array = tiles[ti]
					bucket.append(i)
					tiles[ti] = bucket

func _tile_at(point: Vector3) -> PackedInt32Array:
	var cell := Vector3i(((point - bounds.position) / (step * TILE_CELLS)).floor())
	cell = cell.clamp(Vector3i.ZERO, tile_dimensions - Vector3i.ONE)
	return tiles[cell.x + cell.y * tile_dimensions.x + cell.z * tile_dimensions.x * tile_dimensions.y]

func _sample_field() -> PackedFloat32Array:
	var count := grid_dimensions.x * grid_dimensions.y * grid_dimensions.z
	var field := PackedFloat32Array()
	field.resize(count)
	field.fill(step * 12.0)
	var plane: int = grid_dimensions.x * grid_dimensions.y
	for z in range(grid_dimensions.z):
		if _cancelled():
			return PackedFloat32Array()
		if controls != null:
			controls.set_progress(0.12 + 0.35 * float(z) / float(grid_dimensions.z), "Sampling living tissue")
		@warning_ignore("integer_division")
		var tz: int = z / TILE_CELLS
		for y in range(grid_dimensions.y):
			@warning_ignore("integer_division")
			var ty: int = y / TILE_CELLS
			var bucket_row: int = ty * tile_dimensions.x + tz * tile_dimensions.x * tile_dimensions.y
			var position := bounds.position + Vector3(0.0, y * step, z * step)
			for x in range(grid_dimensions.x):
				@warning_ignore("integer_division")
				var tx: int = x / TILE_CELLS
				var bucket: PackedInt32Array = tiles[bucket_row + tx]
				position.x = bounds.position.x + x * step
				if bucket.is_empty():
					empty_samples += 1
					continue
				field_evaluations += 1
				var value := _field_value(position, bucket)
				# Never place the isosurface exactly on a grid vertex. This avoids
				# zero-area tetrahedra while preserving determinism and sign.
				if absf(value) < 0.0000001:
					value = 0.0000001
				field[x + y * grid_dimensions.x + z * plane] = value
	return field

func _continuous_extraction_value(point: Vector3) -> float:
	# Same complete prepared evaluator and spatial buckets used by sampling,
	# including noise/cavities/lips when present. Never a lattice substitute.
	return _field_value(point,_tile_at(point))

func _field_value(point: Vector3, bucket: PackedInt32Array, apply_noise: bool = true, apply_cavities: bool = true, apply_contained_lips: bool = true) -> float:
	var distance := 1.0e20
	var amplitude := 0.0
	var local_point := Vector3.ZERO
	var context := Vector4.ZERO
	var fold_frequency := 2.8
	var last_node: int = -1
	var node_distance := INF
	var node_blend := 0.1
	var node_amplitude := 0.0
	var node_local := Vector3.ZERO
	var node_context := Vector4.ZERO
	var node_fold_frequency := 2.8
	# Curve samples form one component field. Smooth-union between biological
	# components only, not once per curve sample (which would inflate long limbs).
	for ii in bucket:
		var item := influences[ii]
		if item.subtract:
			continue
		if item.node_index != last_node:
			if last_node >= 0:
				var h := clampf(0.5 + 0.5 * (node_distance - distance) / node_blend, 0.0, 1.0)
				distance = lerpf(node_distance, distance, h) - node_blend * h * (1.0 - h)
				amplitude = lerpf(node_amplitude, amplitude, h)
				local_point = node_local.lerp(local_point, h)
				context = node_context.lerp(context, h)
				fold_frequency = lerpf(node_fold_frequency, fold_frequency, h)
			last_node = item.node_index
			node_distance = INF
			node_blend = item.blend
			node_context = item.noise_context
			node_fold_frequency = item.fold_frequency
		primitive_evaluations += 1
		var d := item.distance(point)
		if d < node_distance:
			node_distance = d
			node_amplitude = item.amplitude
			node_local = item.noise_point(point)
	if last_node >= 0:
		var h := clampf(0.5 + 0.5 * (node_distance - distance) / node_blend, 0.0, 1.0)
		distance = lerpf(node_distance, distance, h) - node_blend * h * (1.0 - h)
		amplitude = lerpf(node_amplitude, amplitude, h)
		local_point = node_local.lerp(local_point, h)
		context = node_context.lerp(context, h)
		fold_frequency = lerpf(node_fold_frequency, fold_frequency, h)
	if apply_noise and absf(distance) < amplitude * 2.0 + step * 2.5 and amplitude > 0.00001:
		var protection := _protection(point)
		distance += noise.anatomical_displacement(point, local_point, context, fold_frequency) * amplitude * protection
	var envelope_distance := distance
	for ii in bucket:
		var item := influences[ii]
		if item.subtract and apply_cavities:
			var cavity_distance := item.distance(point)
			distance = SDF.smooth_subtraction(distance, cavity_distance, minf(item.blend, step * 1.2))
			if item.lip_radius > 0.0 and absf(envelope_distance) < item.lip_radius * 3.0 and absf(cavity_distance) < item.lip_radius * 3.0:
				# Grow the lip along the actual intersection of body and void.
				# Unlike a translated ring, it cannot hang outside its carrier.
				var lip := Vector2(envelope_distance, cavity_distance).length() - item.lip_radius
				distance = SDF.smooth_union(distance, lip, item.lip_radius * 0.45)
	for collar in lattice_collars:
		distance = SDF.smooth_union(distance, collar.distance(point), collar.blend)
	if apply_cavities and apply_contained_lips and not contained_lips.is_empty():
		for item in contained_lips:
			var lip := _contained_lip_value(point, envelope_distance, item)
			if lip >= 1.0e19: continue
			var candidate := SDF.smooth_union(distance, lip, item.contained_lip_radius * 0.30)
			# Protect the central open corridor after blending. This is only a
			# restriction on added tissue: min with the original cannot erode
			# any previously tested side wall or back wall.
			var local := item.inverse_basis * (point - item.position)
			var throat := (Vector2(local.x / (item.radii.x * 0.50), local.y / (item.radii.y * 0.50)).length() - 1.0) * minf(item.radii.x, item.radii.y) * 0.50
			candidate = maxf(candidate, -throat)
			for ii in bucket:
				var other := influences[ii]
				if other.subtract and other != item: candidate = maxf(candidate, -other.distance(point))
			distance = minf(distance, candidate)
	return minf(distance, step * 12.0)

func _contained_lip_value(point: Vector3, envelope_distance: float, item: Influence) -> float:
	var radius := item.contained_lip_radius
	if radius <= 0.0 or item.contained_lip_minimum_radius * 2.0 < step * 2.2 or not item.contained_lip_bounds.has_point(point): return 1.0e20
	var local := item.inverse_basis * (point - item.position)
	if local.z <= item.radii.z * 0.12: return 1.0e20
	var phase := atan2(local.y / item.radii.y, local.x / item.radii.x)
	# Unequal thickness follows the actual implicit intersection, not a torus
	# translated onto the host. Its minimum radius remains explicitly bounded.
	var height := radius * (0.92 + 0.08 * cos(phase + 0.7))
	var across := height * 1.10
	var cavity_distance := item.distance(point)
	var offset := across * 0.65
	if absf(envelope_distance) > radius * 2.0 or absf(cavity_distance - offset) > radius * 2.2: return 1.0e20
	var lip := (Vector2(envelope_distance / height, (cavity_distance - offset) / across).length() - 1.0) * height
	return maxf(lip, item.radii.z * 0.12 - local.z)

func _register_lattice_collars(collars: Array) -> void:
	for data in collars:
		var item := Influence.new()
		item.position = data.start
		item.end = data.end
		item.segment = item.end - item.position
		item.inverse_length_squared = 1.0 / maxf(item.segment.length_squared(), 0.0000001)
		item.is_curve = true
		item.radius_a = float(data.radius)
		item.radius_b = item.radius_a
		item.blend = float(data.blend)
		item.amplitude = 0.0
		var nearest := INF
		for index in _tile_at(item.position):
			var candidate := influences[index]
			if candidate.subtract:
				continue
			var distance := absf(candidate.distance(item.position))
			if distance < nearest:
				nearest = distance
				item.node_index = candidate.node_index
				item.material = candidate.material
		_update_influence_bounds(item)
		lattice_collars.append(item)
		geometry_adjustments.lattice_collars.append({"node_id": str(node_ids[item.node_index]), "start": _json_point(item.position), "end": _json_point(item.end), "radii": [item.radius_a, item.radius_b], "blend": item.blend, "island_samples": int(data.get("island_samples", 0))})

func _prepare_masks(modules: Array) -> void:
	for module in modules:
		var p := Curves.vector(module.get("position", [0.0, 0.0, 0.0]))
		var scale_value: Variant = module.get("scale", [0.4, 0.4, 0.4])
		var size := Curves.vector(scale_value, Vector3.ONE * float(scale_value) if scale_value is float or scale_value is int else Vector3.ONE * 0.4)
		var radius := maxf(size.x, size.y) * 0.70
		preservation_masks.append(Vector4(p.x, p.y, p.z, maxf(radius, step * 2.0)))

func _prepare_module_seats(modules: Array) -> void:
	# Record anchors before cutting a recess. Otherwise a mouth would project
	# onto its own throat and sink into the carrier instead of seating its rim.
	var seats: Array[Influence] = []
	for module in modules:
		var p := Curves.vector(module.get("position", [0.0, 0.0, 0.0]))
		var normal := Curves.vector(module.get("normal", [0.0, 0.0, -1.0]), Vector3.FORWARD).normalized()
		var asset := str(module.get("asset", ""))
		var parent_fields: Array[Influence] = []
		if asset.begins_with("palm_") or asset.begins_with("foot_"):
			parent_fields = _local_module_parent(module, p)
		var seat_scale := Curves.vector(module.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE).abs()
		var full_shell := bool(module.get("full_shell", false)) and (asset.begins_with("face_") or (asset.begins_with("palm_") and str(module.get("mounting", "")) == "palm_volume"))
		var anchor := p
		if full_shell:
			if bool(module.get("surface_mount", false)):
				var offset := clampf(float(module.get("shell_surface_offset", 0.25)), 0.0, 0.6) * seat_scale.z
				var nominal := p - normal * offset
				var crossing := _seat_crossing(nominal, normal, maxf(seat_scale.z, step), parent_fields)
				anchor = nominal + normal * (crossing.y + offset) if crossing.x > 0.5 else p
		else:
			var crossing := _seat_crossing(p, normal, maxf(seat_scale.z, step), parent_fields)
			anchor = p + normal * crossing.y if crossing.x > 0.5 else p
		module_surface_anchors[str(module.get("id", ""))] = anchor
		if not asset.is_empty() and not full_shell:
			module_surface_grids[str(module.get("id", ""))] = _surface_grid(module, anchor, normal, parent_fields)
		if asset.begins_with("face_"):
			var height_factor := 1.65 / 1.35 if asset == "face_elongated" else 1.0
			if full_shell:
				# The source now owns the actual cranial sidewalls and back.
				# Clear only anterior host tissue, leaving posterior neck support.
				# No carrier-grid deformation touches the facial loops or normals.
				var deformation: Dictionary = module.get("deformation", {})
				var width_scale := 1.0 + 0.35 * clampf(float(deformation.get("width", 0.0)), -1.0, 1.0)
				var height_scale := 1.0 + 0.35 * clampf(float(deformation.get("height", 0.0)), -1.0, 1.0)
				_add_module_cavity(module, anchor, normal, Vector3(0.0, 0.015 * height_factor * height_scale, 0.10), Vector3(0.48 * width_scale, 0.64 * height_factor * height_scale, 0.36), seats)
				# A moving jaw extends below the static anterior face seat.
				# Clear its front-neck motion envelope, not the posterior neck
				# support. Actual morph fixtures require clearance below y=-.7.
				var jaw_open := maxf(0.78, clampf(float(deformation.get("mouth_open", 0.0)), 0.0, 1.0))
				var jaw_width := width_scale * (1.0 + 0.20 * maxf(float(deformation.get("jaw", 0.0)), 0.0))
				_add_module_cavity(module, anchor, normal, Vector3(0.0, -(0.48 + 0.13 * jaw_open) * height_factor * height_scale, 0.04), Vector3(0.34 * jaw_width, (0.16 + 0.08 * jaw_open) * height_factor * height_scale, 0.25), seats)
			else:
				_add_face_seat(module, anchor, normal, seats)
			var eye_x := 0.222 if asset == "face_mask" else 0.205
			var eye_y := 0.053 if asset == "face_mask" else 0.065
			for side in [-1.0, 1.0]:
				_add_module_cavity(module, anchor, normal, Vector3(side * eye_x, 0.155 * height_factor, -0.035), Vector3(0.125, eye_y * height_factor, 0.25), seats)
			# The carrier is static while the facial rig opens to 0.72 in preview.
			# Reserve that complete motion envelope, including a small clearance.
			var mouth_open := maxf(0.78, clampf(float(module.get("deformation", {}).get("mouth_open", 0.0)), 0.0, 1.0))
			var mouth_center_y := (-0.278 - 0.090 * mouth_open) * height_factor
			var mouth_radius_y := (0.055 + 0.125 * mouth_open) * height_factor
			_add_module_cavity(module, anchor, normal, Vector3(0.0, mouth_center_y, -0.045), Vector3(0.23, mouth_radius_y, 0.34), seats)
		elif asset == "muzzle_short":
			# The conformed oral bowl sits behind its visible muzzle tissue.
			# Clear that narrow floor using the cached, pre-cut carrier grid;
			# do not hollow the whole muzzle or disturb its nasal support.
			_add_module_cavity(module, anchor, normal, Vector3(0.0, -0.145, -0.04), Vector3(0.33, 0.09, 0.12), seats)
		elif asset.begins_with("mouth_") or asset.begins_with("eye_"):
			var footprint := Vector3(0.24, 0.07, 0.15)
			if asset == "mouth_radial":
				footprint.y = 0.21
			elif asset.begins_with("eye_"):
				footprint = Vector3(0.20, 0.12, 0.12)
			_add_module_cavity(module, anchor, normal, Vector3(0.0, 0.0, -0.035), footprint, seats)
	if not seats.is_empty():
		influences.append_array(seats)
		_build_tiles()

func _add_face_seat(module: Dictionary, anchor: Vector3, normal: Vector3, seats: Array[Influence]) -> void:
	var grid: Dictionary = module_surface_grids.get(str(module.get("id", "")), {})
	if grid.is_empty():
		return
	var item := Influence.new()
	item.node_index = maxi(node_ids.find(str(module.get("parent", ""))), 0)
	item.subtract = true
	item.position = anchor
	item.seat_grid = grid
	item.seat_scale = Curves.vector(module.get("scale", [1, 1, 1]), Vector3.ONE).abs().max(Vector3.ONE * 0.01)
	item.seat_height = 1.65 if str(module.get("asset", "")) == "face_elongated" else 1.35
	item.seat_depth = 0.16 + minf(step * 0.4 / item.seat_scale.z, 0.06)
	item.radii = item.seat_scale * Vector3(0.56, item.seat_height * 0.55, 2.1)
	item.inverse_basis = Curves.attachment_frame(anchor, normal, Curves.vector(module.get("up", [0, 1, 0]), Vector3.UP)).basis.inverse()
	item.rotated = true
	item.blend = step * 0.18
	item.amplitude = 0.0
	_update_influence_bounds(item)
	seats.append(item)

func _add_module_cavity(module: Dictionary, anchor: Vector3, normal: Vector3, center: Vector3, footprint: Vector3, seats: Array[Influence]) -> void:
	var module_scale := Curves.vector(module.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE).abs()
	var frame := Curves.attachment_frame(anchor, normal, Curves.vector(module.get("up", [0.0, 1.0, 0.0]), Vector3.UP)).basis
	var grid: Dictionary = module_surface_grids.get(str(module.get("id", "")), {})
	if not grid.is_empty():
		center.z += _grid_height(grid, center.x, center.y)
	var item := Influence.new()
	item.node_index = maxi(node_ids.find(str(module.get("parent", ""))), 0)
	item.subtract = true
	item.position = anchor + frame * (center * module_scale)
	item.radii = (footprint * module_scale).max(Vector3.ONE * step * 0.6)
	item.inverse_radii = Vector3.ONE / item.radii
	item.inverse_squared = Vector3.ONE / (item.radii * item.radii)
	item.inverse_basis = frame.inverse()
	item.rotated = true
	item.blend = step * 0.25
	item.amplitude = 0.0
	_update_influence_bounds(item)
	seats.append(item)

func _grid_height(grid: Dictionary, x: float, y: float) -> float:
	var resolution := int(grid.resolution)
	var gx := clampf((x / float(grid.width) + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var gy := clampf((y / float(grid.height) + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var ix := mini(floori(gx), resolution - 2)
	var iy := mini(floori(gy), resolution - 2)
	var heights: PackedFloat32Array = grid.heights
	return lerpf(lerpf(heights[ix + iy * resolution], heights[ix + 1 + iy * resolution], gx - ix), lerpf(heights[ix + (iy + 1) * resolution], heights[ix + 1 + (iy + 1) * resolution], gx - ix), gy - iy)

func _local_module_parent(module: Dictionary, seat: Vector3) -> Array[Influence]:
	var parent_index := node_ids.find(str(module.get("parent", "")))
	var candidates: Array[Influence] = []
	for item in influences:
		if item.represents_node(parent_index) and not item.subtract:
			candidates.append(item)
	# A foot seated on a limb tip must not climb a higher part of the same
	# curved shin. Mass carriers already have a tight anatomical footprint.
	candidates.sort_custom(func(a: Influence, b: Influence) -> bool: return absf(a.distance(seat)) < absf(b.distance(seat)))
	if candidates.size() > 3:
		candidates.resize(3)
	return candidates

func _seat_field(point: Vector3, local_fields: Array[Influence]) -> float:
	if local_fields.is_empty():
		return _field_value(point, _tile_at(point), true, false)
	var distance := INF
	var amplitude := 0.0
	var closest: Influence = null
	for item in local_fields:
		var d := item.distance(point)
		if d < distance:
			distance = d
			amplitude = item.amplitude
			closest = item
	if closest == null: return distance
	return distance + noise.anatomical_displacement(point, closest.noise_point(point), closest.noise_context, closest.fold_frequency) * amplitude * _protection(point)

func _seat_crossing(tangent: Vector3, normal: Vector3, depth_scale: float, local_fields: Array[Influence]) -> Vector2:
	# Verify a genuinely outside bracket, then take the FIRST inward crossing.
	# Merely testing a fixed deep endpoint misses thin carriers, while a fixed
	# upper endpoint can remain inside an overlapping mass and bury the face.
	var high := depth_scale * 0.35
	var outer_limit := depth_scale * 1.80
	while high < outer_limit and _seat_field(tangent + normal * high, local_fields) < 0.0:
		high = minf(high + depth_scale * 0.35, outer_limit)
	if _seat_field(tangent + normal * high, local_fields) < 0.0:
		return Vector2.ZERO
	var bottom := -depth_scale * 0.90
	var previous := high
	for i in range(1, 19):
		var low := lerpf(high, bottom, float(i) / 18.0)
		if _seat_field(tangent + normal * low, local_fields) <= 0.0:
			var outside := previous
			for _iteration in range(9):
				var mid := (low + outside) * 0.5
				if _seat_field(tangent + normal * mid, local_fields) < 0.0:
					low = mid
				else:
					outside = mid
			return Vector2(1.0, (low + outside) * 0.5)
		previous = low
	return Vector2.ZERO

func _surface_grid(module: Dictionary, anchor: Vector3, normal: Vector3, local_fields: Array[Influence]) -> Dictionary:
	var resolution := 17
	var width := 1.6
	var height := 2.2
	var scale_value := Curves.vector(module.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE).abs().max(Vector3.ONE * 0.01)
	var frame := Curves.attachment_frame(anchor, normal, Curves.vector(module.get("up", [0.0, 1.0, 0.0]), Vector3.UP)).basis
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	var hit_count := 0
	var valid := PackedByteArray()
	valid.resize(resolution * resolution)
	for y in range(resolution):
		for x in range(resolution):
			var local_x := (float(x) / float(resolution - 1) - 0.5) * width
			var local_y := (float(y) / float(resolution - 1) - 0.5) * height
			var tangent := anchor + frame.x * local_x * scale_value.x + frame.y * local_y * scale_value.y
			var crossing := _seat_crossing(tangent, normal, scale_value.z, local_fields)
			if crossing.x > 0.5:
				heights[x + y * resolution] = crossing.y / scale_value.z
				hit_count += 1
				valid[x + y * resolution] = 1
			else:
				heights[x + y * resolution] = -0.70
	# Roll missing carrier samples inward from neighboring valid samples.
	# A fixed fallback plane caused discontinuous steps at a curved skull rim.
	for _iteration in range(resolution * 2):
		var changed := 0
		var next_valid := valid.duplicate()
		var next_heights := heights.duplicate()
		for y in range(resolution):
			for x in range(resolution):
				var index := x + y * resolution
				if valid[index] != 0:
					continue
				var sum := 0.0
				var count := 0
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var nx: int = x + offset.x
					var ny: int = y + offset.y
					if nx >= 0 and nx < resolution and ny >= 0 and ny < resolution and valid[nx + ny * resolution] != 0:
						sum += heights[nx + ny * resolution]
						count += 1
				if count > 0:
					next_heights[index] = maxf(sum / float(count) - 0.09, -1.8)
					next_valid[index] = 1
					changed += 1
		valid = next_valid
		heights = next_heights
		if changed == 0:
			break
	return {"resolution": resolution, "width": width, "height": height, "heights": heights, "hit_fraction": float(hit_count) / float(resolution * resolution), "local_parent_only": not local_fields.is_empty(), "cell_size": step, "recommended_perimeter_burial": 0.65 * step / scale_value.z}

func _protection(point: Vector3) -> float:
	var result := 1.0
	for mask in preservation_masks:
		var distance := point.distance_to(Vector3(mask.x, mask.y, mask.z)) / mask.w
		if distance < 1.0:
			result = minf(result, lerpf(0.12, 1.0, smoothstep(0.20, 1.0, distance)))
	return result

func _lattice_value(point: Vector3, sampled: PackedFloat32Array) -> float:
	if not slab_axes.is_empty():return SlabGrid.trilinear_validated(point,sampled,slab_dimensions,slab_axes,step*12.0,slab_high_preview)
	# Macro shading samples the same bounded SDF that generated the surface.
	# Trilinear reads avoid repeating expensive anatomical primitive queries.
	var cell := (point - bounds.position) / step
	if cell.x < 0.0 or cell.y < 0.0 or cell.z < 0.0 or cell.x > grid_dimensions.x - 1 or cell.y > grid_dimensions.y - 1 or cell.z > grid_dimensions.z - 1:
		return step * 12.0
	var x := clampi(floori(cell.x), 0, grid_dimensions.x - 2)
	var y := clampi(floori(cell.y), 0, grid_dimensions.y - 2)
	var z := clampi(floori(cell.z), 0, grid_dimensions.z - 2)
	var fx := cell.x - float(x)
	var fy := cell.y - float(y)
	var fz := cell.z - float(z)
	var row := grid_dimensions.x
	var plane := grid_dimensions.x * grid_dimensions.y
	var base := x + y * row + z * plane
	return lerpf(lerpf(lerpf(sampled[base], sampled[base + 1], fx), lerpf(sampled[base + row], sampled[base + row + 1], fx), fy), lerpf(lerpf(sampled[base + plane], sampled[base + plane + 1], fx), lerpf(sampled[base + plane + row], sampled[base + plane + row + 1], fx), fy), fz)

func _attribute_vertices(mesh: Dictionary, sampled: PackedFloat32Array) -> void:
	var vertices: PackedVector3Array = mesh.vertices
	var normals: PackedVector3Array = mesh.normals
	var owners := PackedInt32Array()
	var component_indices := PackedInt32Array()
	var component_weights := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	var ambient_occlusion := PackedFloat32Array()
	ambient_occlusion.resize(vertices.size())
	owners.resize(vertices.size())
	component_indices.resize(vertices.size() * 4)
	component_weights.resize(vertices.size() * 4)
	colors.resize(vertices.size())
	uvs.resize(vertices.size())
	uvs2.resize(vertices.size())
	var distances := PackedFloat32Array()
	distances.resize(node_ids.size())
	var relevant := PackedInt32Array()
	for vi in range(vertices.size()):
		if vi % 1024 == 0:
			if _cancelled():
				return
			if controls != null:
				controls.set_progress(0.83 + 0.06 * float(vi) / float(vertices.size()), "Preserving anatomical influences")
		var p := vertices[vi]
		distances.fill(INF)
		relevant.clear()
		var envelope_item: Influence = null
		for ii in _tile_at(p):
			var item := influences[ii]
			if item.subtract:
				continue
			var ni := item.node_index
			if item.body_envelope != null: envelope_item = item
			var d := item.distance(p)
			if distances[ni] == INF:
				relevant.append(ni)
			distances[ni] = minf(distances[ni], d)
		for collar in lattice_collars:
			if not collar.bounds.has_point(p):
				continue
			var ni := collar.node_index
			if distances[ni] == INF:
				relevant.append(ni)
			distances[ni] = minf(distances[ni], collar.distance(p))
		if not contained_lips.is_empty():
			var bucket := _tile_at(p)
			var envelope := _field_value(p, bucket, true, false)
			var added_owner := -1
			var added_distance := INF
			var comparison_ready := false
			var added_here := false
			for item in contained_lips:
				var lip := _contained_lip_value(p, envelope, item)
				if lip > step or item.contained_lip_owner < 0: continue
				var owner := item.contained_lip_owner
				if distances[owner] == INF: relevant.append(owner)
				distances[owner] = minf(distances[owner], lip)
				if not comparison_ready:
					# A retained positive can be deeply negative inside a cutter.
					# Primitive distance alone would assign the post-cut surface
					# to that unrelated overlap instead of this operation's host.
					var without_lip := _field_value(p, bucket, true, true, false)
					var with_lip := _field_value(p, bucket, true, true, true)
					added_here = with_lip < without_lip - maxf(step * 0.0001, 0.000001)
					comparison_ready = true
				if added_here and lip < added_distance:
					added_owner = owner
					added_distance = lip
			if added_owner >= 0:
				# Make the explicitly owned new surface dominant, while keeping
				# ordinary neighboring weights for a smooth skeletal transition.
				var closest_positive := INF
				for ni in relevant: closest_positive = minf(closest_positive, distances[ni])
				distances[added_owner] = minf(distances[added_owner], closest_positive - step * 0.05)
		var best := PackedInt32Array([-1, -1, -1, -1])
		var best_d := PackedFloat32Array([INF, INF, INF, INF])
		var sum := 0.0
		var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		if envelope_item != null:
			var partition := _envelope_component_partition(p,distances,relevant,envelope_item)
			best = partition.indices; weights = partition.weights; sum = 1.0
			var dropped := float(partition.dropped_weight)
			if dropped > 0.0:
				envelope_attribution_reductions += 1
				envelope_attribution_sum_dropped += dropped
				envelope_attribution_max_dropped = maxf(envelope_attribution_max_dropped,dropped)
		else:
			for ni in relevant:
				var d := distances[ni]
				for slot in range(4):
					if d < best_d[slot]:
						for shift in range(3, slot, -1):
							best_d[shift] = best_d[shift - 1]
							best[shift] = best[shift - 1]
						best_d[slot] = d
						best[slot] = ni
						break
			if best[0] < 0:
				best[0] = 0
				best_d[0] = 0.0
			for slot in range(4):
				if best[slot] < 0:
					continue
				var width := maxf(node_blends[best[slot]], step * 1.2)
				weights[slot] = pow(clampf(1.0 - (best_d[slot] - best_d[0]) / (width * 1.5), 0.0, 1.0), 2.0)
				sum += weights[slot]
		owners[vi] = best[0]
		var material_weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
		for slot in range(4):
			var id := maxi(best[slot], 0)
			var weight := weights[slot] / maxf(sum, 0.00001)
			component_indices[vi * 4 + slot] = id
			component_weights[vi * 4 + slot] = weight
			material_weights[node_materials[id]] += weight
		var primary: int = node_materials[best[0]]
		var secondary: int = primary
		var secondary_weight := 0.0
		for material in range(8):
			if material != primary and material_weights[material] > secondary_weight:
				secondary = material
				secondary_weight = material_weights[material]
		var secondary_fraction := secondary_weight / maxf(material_weights[primary] + secondary_weight, 0.00001)
		# Bounded macro occlusion in crevices, distinct from micro normal noise.
		# Subtract the local mesh-to-field error before comparing probe distance.
		var baseline := _lattice_value(p, sampled)
		var occlusion := 0.0
		for probe_index in range(2):
			var radius := step * (2.0 if probe_index == 0 else 5.0)
			var sample_position := p + normals[vi] * radius
			var clearance := _lattice_value(sample_position, sampled) - baseline
			occlusion += clampf(1.0 - clearance / radius, 0.0, 1.0) * (0.55 if probe_index == 0 else 0.45)
		ambient_occlusion[vi] = clampf(1.0 - occlusion * 0.72, 0.28, 1.0)
		colors[vi] = Color(float(primary) / 7.0, noise.tissue_variation(p), 1.0 - _protection(p), 1.0)
		uvs2[vi] = Vector2(float(secondary) / 7.0, secondary_fraction)
		# Stable dominant-axis UVs are supplied for interchange. The organic
		# shader uses object-space triplanar mapping, so these seams are hidden.
		var n := normals[vi].abs()
		if n.y >= n.x and n.y >= n.z:
			uvs[vi] = Vector2(p.x, p.z)
		elif n.x >= n.z:
			uvs[vi] = Vector2(p.z, p.y)
		else:
			uvs[vi] = Vector2(p.x, p.y)
	mesh["ambient_occlusion"] = ambient_occlusion
	mesh["component_ids"] = owners
	mesh["component_indices"] = component_indices
	mesh["component_weights"] = component_weights
	mesh["colors"] = colors
	mesh["uvs"] = uvs
	mesh["uvs2"] = uvs2

func _vertex_bounds(vertices: PackedVector3Array) -> AABB:
	var box := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		box = box.expand(vertex)
	return box

func _collision_proxies(nodes: Array) -> Array:
	var proxies: Array = []
	for node in nodes:
		if str(node.get("kind", "mass")) == "cavity" or str(node.get("role", "")) == "tendon" or str(node.get("shape", {}).get("geometry", "")) == "detail":
			continue
		if str(node.get("kind", "mass")) == "curve":
			var points: Array = node.get("points", [])
			for i in range(points.size() - 1):
				proxies.append({"kind": "capsule", "start": points[i], "end": points[i + 1], "radius": float(node.get("radius", 0.1)), "component": str(node.get("id", ""))})
		else:
			proxies.append({"kind": "ellipsoid", "position": node.get("position", [0.0, 0.0, 0.0]), "radii": node.get("size", [0.5, 0.5, 0.5]), "component": str(node.get("id", ""))})
	return proxies

func _module_anchors(modules: Array, sampled: PackedFloat32Array = PackedFloat32Array()) -> Array:
	var result: Array = []
	for module in modules:
		var p := Curves.vector(module.get("position", [0.0, 0.0, 0.0]))
		var normal := Curves.vector(module.get("normal", [0.0, 0.0, -1.0]), Vector3.FORWARD).normalized()
		var module_id := str(module.get("id", ""))
		var projected: Vector3 = module_surface_anchors[module_id] if module_surface_anchors.has(module_id) else project_to_surface(p, normal)
		var surface_ambient_occlusion := 1.0
		if not sampled.is_empty():
			var carrier_point := projected
			if bool(module.get("full_shell", false)):
				carrier_point -= normal * Curves.vector(module.get("scale", [1,1,1]), Vector3.ONE).z * 0.25
			var baseline := _lattice_value(carrier_point, sampled)
			var occlusion := 0.0
			for probe_index in range(2):
				var radius := step * (2.0 if probe_index == 0 else 5.0)
				var clearance := _lattice_value(carrier_point + normal * radius, sampled) - baseline
				occlusion += clampf(1.0 - clearance / radius, 0.0, 1.0) * (0.55 if probe_index == 0 else 0.45)
			surface_ambient_occlusion = clampf(1.0 - occlusion * 0.72, 0.28, 1.0)
		var anchor := {"surface_ambient_occlusion": surface_ambient_occlusion, "id": str(module.get("id", "")), "position": projected, "normal": normal, "parent": str(module.get("parent", "")), "preservation_radius": step * 2.0, "surface_grid": module_surface_grids.get(module_id, {}), "surface_material": _surface_material_at(projected), "full_shell": bool(module.get("full_shell", false)), "surface_mount": bool(module.get("surface_mount", false)), "mounting": str(module.get("mounting", ""))}
		if build_module_attachment_fields and bool(module.get("full_shell", false)) and str(module.get("mounting", "")) == "palm_volume" and str(module.get("asset", "")) == "palm_humanoid":
			anchor["attachment_field"] = _module_attachment_field(module, projected, normal)
		result.append(anchor)
	return result

func _module_attachment_field(module: Dictionary, anchor: Vector3, normal: Vector3) -> Dictionary:
	# Opt-in diagnostic packet, not an enabled deformation. Sample the exact
	# final six-tet field while it is still owned by this worker. Only the wrist
	# insertion band is covered; frontal face geometry is never involved.
	if attachment_lattice.is_empty(): return {}
	var dimensions := Vector3i(25, 21, 21)
	var origin := Vector3(-0.65, -0.82, -0.45)
	var cell_size := Vector3(1.30, 0.64, 0.90) / Vector3(dimensions - Vector3i.ONE)
	var scale := Curves.vector(module.get("scale", [1,1,1]), Vector3.ONE).abs().max(Vector3.ONE * 0.001)
	var frame := Curves.attachment_frame(anchor, normal, Curves.vector(module.get("up", [0,1,0]), Vector3.UP))
	var distances := PackedFloat32Array()
	var valid := PackedByteArray()
	distances.resize(dimensions.x * dimensions.y * dimensions.z)
	valid.resize(distances.size())
	var index := 0
	for z in range(dimensions.z):
		if _cancelled(): return {}
		for y in range(dimensions.y):
			for x in range(dimensions.x):
				var point := frame * ((origin + Vector3(x,y,z) * cell_size) * scale)
				var cell := (point - bounds.position) / step
				if cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < grid_dimensions.x - 1 and cell.y < grid_dimensions.y - 1 and cell.z < grid_dimensions.z - 1:
					distances[index] = _attachment_value(point)
					valid[index] = 1
				index += 1
	return {"origin": origin, "cell_size": cell_size, "dimensions": dimensions, "distances": distances, "valid": valid, "scale": scale, "band_world": 0.012, "source": "final_extraction_tetrahedra", "domain": "wrist_only"}


func project_to_surface(point: Vector3, outward: Vector3, include_cavities: bool = true) -> Vector3:
	# Used by the renderer to seat a module's embedded collar in the actual
	# displaced tissue, rather than relying on a nominal ellipsoid intersection.
	var normal := outward.normalized()
	if normal.length_squared() < 0.1:
		normal = Vector3.FORWARD
	var p := point
	for _i in range(12):
		var distance := _field_value(p, _tile_at(p), true, include_cavities)
		if absf(distance) < step * 0.04:
			break
		p -= normal * clampf(distance, -step * 3.0, step * 3.0)
	return p

func sample_signed_distance(point: Vector3) -> float:
	return _field_value(point, _tile_at(point))

func _cancelled() -> bool:
	return controls != null and controls.is_cancelled()

static func _json_point(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

func sac_group_qualification() -> Dictionary:
	return GroupQualification.evaluate(self)

func _envelope_component_partition(point: Vector3, distances: PackedFloat32Array, relevant: PackedInt32Array, group_item: Influence) -> Dictionary:
	if source_dna.get("settings",{}).get(BodyGroupField.SETTING,BodyGroupField.OFF)==BodyGroupField.MODE:
		return _body_group_component_partition(point,relevant,group_item)
	# Scalar carrier scores first, authored regional split second. No duplicate
	# geometry evaluation or fabricated per-member distance. The four-component
	# reduction is explicit, deterministic, renormalized and measured.
	var nearest := INF
	for ni in relevant: nearest = minf(nearest,float(distances[ni]))
	var scores: Dictionary = {}
	for ni in relevant:
		var width := maxf(group_item.blend if ni == group_item.node_index else float(node_blends[ni]),step*1.2)
		var score := pow(clampf(1.0-(float(distances[ni])-nearest)/(width*1.5),0.0,1.0),2.0)
		if ni == group_item.node_index:
			var regional: Vector2 = group_item.body_envelope.weights(point)
			for k in range(2):
				var member_index: int = group_item.member_indices[k]
				scores[member_index] = float(scores.get(member_index,0.0))+score*float(regional[k])
		else: scores[ni] = float(scores.get(ni,0.0))+score
	var ranked: Array = scores.keys()
	ranked.sort_custom(func(a: int,b: int) -> bool: return float(scores[a]) > float(scores[b]) or (float(scores[a]) == float(scores[b]) and a < b))
	var indices := PackedInt32Array([-1,-1,-1,-1]); var weights := PackedFloat32Array([0,0,0,0])
	var total := 0.0; var kept := 0.0
	for ni: int in ranked: total += float(scores[ni])
	for k in range(mini(4,ranked.size())):
		indices[k] = int(ranked[k]); weights[k] = float(scores[ranked[k]]); kept += float(weights[k])
	for k in range(4): weights[k] /= maxf(kept,0.000000000001)
	return {"indices":indices,"weights":weights,"dropped_weight":maxf(0.0,(total-kept)/maxf(total,0.000000000001))}


func _body_group_component_partition(point: Vector3,relevant: PackedInt32Array,group_item: Influence) -> Dictionary:
	# Unlike the legacy proximity score,202 uses actual ordered smooth-min
	# coefficients. Curves are reduced by hard min once per biological node,
	# exactly as _field_value. No invented independent member distances.
	var sample: Dictionary=group_item.body_envelope.sample(point,true)
	var value: float=sample.distance
	var scores: Dictionary={}
	for i in range(group_item.member_indices.size()): scores[group_item.member_indices[i]]=float(sample.weights[i])
	var ordinary: Dictionary={}
	var exact_blends: Dictionary={}
	for ii in _tile_at(point):
		var item: Influence=influences[ii]
		if item.subtract or item==group_item or item.node_index not in relevant: continue
		ordinary[item.node_index]=minf(float(ordinary.get(item.node_index,INF)),item.distance(point))
		exact_blends[item.node_index]=item.blend
	var ordered: Array=ordinary.keys(); ordered.sort()
	for index: int in ordered:
		var other: float=ordinary[index]; var k: float=exact_blends[index]
		var h:=clampf(0.5+0.5*(other-value)/k,0.0,1.0)
		value=lerpf(other,value,h)-k*h*(1.0-h)
		for key: int in scores: scores[key]=float(scores[key])*h
		scores[index]=1.0-h
	return _reduce_body_group_scores(scores,value)

func _reduce_body_group_scores(scores: Dictionary,value: float) -> Dictionary:
	var ranked: Array=scores.keys()
	ranked.sort_custom(func(a: int,b: int) -> bool: return float(scores[a])>float(scores[b]) or (float(scores[a])==float(scores[b]) and a<b))
	var indices:=PackedInt32Array([-1,-1,-1,-1]); var weights:=PackedFloat32Array([0,0,0,0])
	var total:=0.0; var kept:=0.0
	for index: int in ranked: total+=float(scores[index])
	for i in range(mini(4,ranked.size())):
		indices[i]=ranked[i]; weights[i]=float(scores[ranked[i]]); kept+=float(weights[i])
	for i in range(4): weights[i]/=maxf(kept,0.000000000001)
	return {"indices":indices,"weights":weights,"dropped_weight":maxf(0.0,(total-kept)/maxf(total,0.000000000001)),"exact_ordered_carrier_weights":scores,"composed_distance":value,"normalization_rounding":"PackedFloat32 four-slot storage"}
