extends RefCounted
## A fixed primary-organ role, not a resolution correction or a field solver.
## Only the Stage5 owner and its copied registry rule are authored here.
const MODE: String="primary_reinforced_pleats_v1"
const PIN: String="6973df07324d6e4962a280f843d56ddb0678118ae6e29ecbfecae432ac1cf31a"
const SETTING: String="blob_sac_surface_mode"
const PRIMARY_FEATURE: String="blob.sac.primary.0"
const NORMALIZED_AMPLITUDE: float=0.25
const Field=preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")

static func enabled(dna: Dictionary)->bool:
	var settings: Variant=dna.get("settings",{})
	return settings is Dictionary and settings.get(SETTING) is String and settings.get(SETTING)==MODE

static func number(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))

static func creases()->Array:
	return [{"center":-0.50,"width":0.49,"strength":1.0},{"center":0.50,"width":0.49,"strength":0.82}]

static func bits(value: float)->String:
	var bytes: PackedByteArray=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	return bytes.hex_encode()

static func primary_owner(dna: Dictionary)->Dictionary:
	var nodes: Variant=dna.get("nodes")
	if not nodes is Array:return {}
	var found: Dictionary={}
	for node: Variant in nodes:
		if not node is Dictionary:return {}
		if Field.marked(node) and node.get("feature_id") is String and node.feature_id==PRIMARY_FEATURE:
			if not found.is_empty():return {}
			found=node
	return found

static func expected_amplitude(dna: Dictionary,owner: Dictionary)->Dictionary:
	var bad: Dictionary={"ok":false,"error":"214 cannot derive a finite primary depth radius from the actual group frame."}
	if not Field.marked(owner) or not owner.shape[Field.KEY] is Dictionary or not dna.get("settings") is Dictionary or not dna.get("nodes") is Array:return bad
	var size: Variant=dna.settings.get("size",1.0)
	if not number(size) or float(size)!=1.0:return bad
	if not Field.vector(owner.get("size")) or not Field.vector(owner.get("position")) or not owner.get("parent") is String:return bad
	var radii: Vector3=Field.vec(owner.size)
	if minf(radii.x,minf(radii.y,radii.z))<=0.0:return bad
	var descriptor: Dictionary=owner.shape[Field.KEY]
	for key: String in ["across","axial","depth"]:
		if not Field.unit(descriptor.get(key)):return bad
	var across: Vector3=Field.vec(descriptor.across);var axial: Vector3=Field.vec(descriptor.axial);var depth: Vector3=Field.vec(descriptor.depth)
	if absf(across.dot(axial))>0.000001 or absf(across.dot(depth))>0.000001 or absf(axial.dot(depth))>0.000001 or across.cross(axial).dot(depth)<0.99999:return bad
	for key: String in ["fold_amplitude","waist_x","waist_z","swell_x","swell_z"]:
		if not number(descriptor.get(key)):return bad
	var parent_found: bool=false
	for node: Variant in dna.nodes:
		if not node is Dictionary or not node.get("id") is String:return bad
		if node.id==owner.parent:
			if parent_found or not Field.vector(node.get("position")):return bad
			parent_found=true
	if not parent_found:return bad
	# Reuse precisely the production orthonormalized frame/radius calculation.
	# create() computes parameters only; no field/distance sample is performed.
	var group: RefCounted=Field.create(dna,owner)
	var radius: float=group.radii.z
	var amplitude: float=NORMALIZED_AMPLITUDE*radius/float(size)
	if not is_finite(radius) or radius<=0.0 or not is_finite(amplitude) or amplitude<=0.0 or amplitude>0.15:return bad
	return {"ok":true,"amplitude":amplitude,"depth_radius":radius,"normalized_amplitude":NORMALIZED_AMPLITUDE}

static func author_nodes(dna: Dictionary)->Dictionary:
	if not enabled(dna):return {"error":"214 authoring requires its explicit primary role."}
	var owner: Dictionary=primary_owner(dna)
	if owner.is_empty():return {"error":"214 primary owner is missing or ambiguous."}
	var derived: Dictionary=expected_amplitude(dna,owner)
	if not derived.ok:return {"error":derived.error}
	owner.shape[Field.KEY]["creases"]=creases()
	owner.shape[Field.KEY]["fold_amplitude"]=derived.amplitude
	owner.shape[Field.KEY]["fold_amplitude_hex"]=bits(float(derived.amplitude))
	return {"ok":true,"owner_id":owner.id,"feature_id":PRIMARY_FEATURE,"amplitude":derived.amplitude,"depth_radius":derived.depth_radius}

static func author_rules(dna: Dictionary)->Dictionary:
	if not enabled(dna):return {"error":"214 registry authoring requires its explicit primary role."}
	var blueprint: Variant=dna.get("biological_blueprint")
	if not blueprint is Dictionary or not blueprint.get("features") is Array:return {"error":"214 requires the Stage5 registry copy before rule authoring."}
	var owner: Dictionary=primary_owner(dna)
	if owner.is_empty():return {"error":"214 primary owner is missing or ambiguous."}
	var derived: Dictionary=expected_amplitude(dna,owner)
	if not derived.ok:return {"error":derived.error}
	var target: Dictionary={}
	for feature: Variant in blueprint.features:
		if not feature is Dictionary or not feature.get("id") is String:return {"error":"214 registry contains a malformed feature."}
		if feature.id==PRIMARY_FEATURE:
			if not target.is_empty() or not feature.get("detail_rules") is Dictionary:return {"error":"214 primary detail rule is missing or ambiguous."}
			target=feature.detail_rules
	if target.is_empty():return {"error":"214 primary detail rule was not found."}
	# Do not mutate the shared planning registry: the caller supplies the copied
	# Stage5 snapshot after earlier snapshots have received their annotations.
	target["amplitude"]=derived.amplitude
	return {"ok":true}
