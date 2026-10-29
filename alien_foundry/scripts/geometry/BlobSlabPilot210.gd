extends RefCounted
## Strict retained pilot optimization for the single approved specimen.
## Ordinary mode creates its own coarse artifact; callers cannot supply a plan.
const Policy=preload("res://alien_foundry/scripts/geometry/BlobSlabPolicy210.gd")
const Artifacts=preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const Exact=preload("res://alien_foundry/scripts/geometry/BlobMassOuterProfile203.gd")
const POSITIONS_SHA: String="500edfa316e6746d2fd5274b49049b371c76e1e3251544177155b492a65e7ae2"
const NORMALS_SHA: String="ce632f580026cda8c375ef3abc7e94a2b1a11eb302c43926a795540e650018b6"
const INDICES_SHA: String="6096eccc6d486484b2ef20ab412c5ea57e1dde5c48be0925a99922d780e17f04"

static func digest(bytes: PackedByteArray)->String:
	var context: HashingContext=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()

static func load_retained(path: String,dna: Dictionary,dims: Vector3i,origin: Vector3,cell: float)->Dictionary:
	if path.is_empty():return {"error":"210 retained pilot path is empty."}
	var file: FileAccess=FileAccess.open(path,FileAccess.READ)
	if file==null:return {"error":"210 retained pilot cannot be read."}
	if file.get_length()>64*1024*1024:file.close();return {"error":"210 retained pilot exceeds bounded raw size."}
	if FileAccess.get_sha256(path)!=Policy.RETAINED_SHA:file.close();return {"error":"210 retained pilot raw hash mismatch."}
	var packet: Variant=file.get_var(false);file.close()
	if not packet is Dictionary:return {"error":"210 retained pilot is not a typed packet."}
	var checked: Dictionary=verify_packet(packet,dna,dims,origin,cell)
	if checked.has("error"):return checked
	checked["raw_sha256"]=Policy.RETAINED_SHA;return checked

static func verify_packet(packet: Dictionary,dna: Dictionary,dims: Vector3i,origin: Vector3,cell: float)->Dictionary:
	var declaration: Dictionary=Policy.validate(dna)
	if not declaration.ok:return {"error":declaration.error}
	if not Policy.enabled(dna):return {"error":"210 pilot requires explicit candidate mode."}
	if dims!=Policy.RETAINED_GRID or PackedVector3Array([origin]).to_byte_array().hex_encode()!=Policy.RETAINED_ORIGIN_BITS or Policy.scalar_bits(cell)!=Policy.RETAINED_CELL_BITS:return {"error":"210 retained pilot base grid/origin/cell bytes mismatch."}
	if not packet.get("seed") is int or packet.seed!=22 or not packet.get("stage") is int or packet.stage!=4 or not Policy.text_is(packet.get("geometry_key"),Policy.RETAINED_KEY) or not packet.get("dna") is Dictionary or not packet.get("mesh_data") is Dictionary:return {"error":"210 retained pilot identity/header mismatch."}
	if not Policy.text_is(packet.get("pinned_spec_sha256"),"2d077d51b7556d5d6ff83a75966b25918c0aa2d3636012857cba480062d33c50") or not Policy.text_is(packet.get("normal_policy_sha256"),"5eb7722334a080e7fdd428f17f732877ac15b7c41defb2604d2c9fe95cc1ac00"):return {"error":"210 retained pilot source-policy pins mismatch."}
	var base: Dictionary=dna.duplicate(true);base.settings.erase(Policy.SETTING);base.settings.erase(Policy.PIN_SETTING)
	var source: Dictionary=Artifacts.decode_geometry_recipe(packet.dna)
	if source.has("error") or not Exact.typed_equal(Artifacts._consumed_inputs(base),source.get("inputs",{})):return {"error":"210 retained pilot consumed recipe differs from candidate field."}
	if Artifacts.geometry_key(base,4,Policy.RETAINED_DEPENDENCY)!=Policy.RETAINED_KEY or Artifacts.geometry_key(packet.dna,4,Policy.RETAINED_DEPENDENCY)!=Policy.RETAINED_KEY:return {"error":"210 retained pilot stage/dependency/organism key mismatch."}
	var mesh: Dictionary=packet.mesh_data
	if not Policy.text_is(mesh.get("error"),Policy.FACE_ERROR) or not mesh.get("rejected") is bool or not mesh.rejected or not mesh.get("raw_snapshot_complete") is bool or not mesh.raw_snapshot_complete or not Policy.text_is(mesh.get("raw_snapshot_status"),"completed_finite_index_safe_rejected_before_attribution"):return {"error":"210 retained pilot is not the eligible completed face rejection."}
	if not mesh.get("vertices") is PackedVector3Array or not mesh.get("normals") is PackedVector3Array or not mesh.get("indices") is PackedInt32Array:return {"error":"210 retained pilot physical buffers are not typed."}
	if digest(mesh.vertices.to_byte_array())!=POSITIONS_SHA or digest(mesh.normals.to_byte_array())!=NORMALS_SHA or digest(mesh.indices.to_byte_array())!=INDICES_SHA:return {"error":"210 retained pilot physical buffer bytes mismatch."}
	var edge: Variant=mesh.get("edge_refinement204")
	if not edge is Dictionary or not edge.get("unique_edges") is int or edge.unique_edges!=13384 or not edge.get("continuous_queries") is int or edge.continuous_queries!=478996:return {"error":"210 retained pilot historical edge/query counts mismatch."}
	for counter: String in ["fallbacks","repairs","normal_replacements"]:
		if not edge.get(counter) is int or edge.get(counter)!=0:return {"error":"210 retained pilot must preserve zero repairs/fallbacks/replacements."}
	if not Policy.text_is(edge.get("error"),Policy.FACE_ERROR) or not Policy.text_is(edge.get("mode"),"bracketed_field_edges_v1") or not Policy.text_is(edge.get("pin"),"505802d0b619bd74bf45c312800eda4e16e0a802de3a92d10397f73f2d80ca02"):return {"error":"210 retained pilot root-policy evidence mismatch."}
	var normal: Variant=edge.get("adaptive_normal207")
	if not normal is Dictionary or not Policy.text_is(normal.get("mode"),"adaptive_field_gradient_v2") or not Policy.text_is(normal.get("pin"),"5eb7722334a080e7fdd428f17f732877ac15b7c41defb2604d2c9fe95cc1ac00") or not normal.get("converged_edges") is int or normal.converged_edges!=13384 or not normal.get("rejected_edges") is int or normal.rejected_edges!=0:return {"error":"210 retained pilot normal-policy evidence mismatch."}
	return {"mesh":mesh,"historical_edges":13384,"historical_queries":478996,"historical_lattice_visits":454936,"geometry_key":Policy.RETAINED_KEY,"dependency":Policy.RETAINED_DEPENDENCY}

static func plan_digest(plan: Dictionary,reference_cell: float)->String:
	# Face IDs/traversal diagnostics do not define the canonical split grid.
	var canonical: Dictionary={"pin":Policy.PIN,"reference_cell":reference_cell,"base_dimensions":plan.get("base_dimensions"),"base_axes":plan.get("base_axes"),"split_intervals":plan.get("split_intervals"),"dimensions":plan.get("dimensions"),"axes":plan.get("axes")}
	return digest(var_to_bytes(canonical))
