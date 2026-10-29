extends RefCounted
## Derived bind-space data only. Never rewrites an extraction node/mesh position.
const Field = preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const VERSION := 1
const PROFILE := "sac_group_bind_v1"
static func enabled(dna: Dictionary) -> bool:
	return dna.get("type") == "Blob" and dna.get("settings",{}).get(Field.SETTING,Field.OFF) == Field.FINAL_MODE
static func artifact_key(dna: Dictionary, geometry_key: String, kind: String) -> String:
	if not enabled(dna): return geometry_key
	return JSON.stringify({"profile": PROFILE,"version": VERSION,"geometry": geometry_key,"kind": kind},"",true,true).sha256_text()
static func record(dna: Dictionary, geometry_key: String) -> Dictionary:
	if not enabled(dna): return {}
	var groups: Array = []
	for n: Dictionary in dna.nodes:
		if Field.marked(n): groups.append({"owner_id": n.id,"feature_id": n.feature_id,"members": n.shape[Field.KEY].members.duplicate()})
	return {"profile": PROFILE,"version": VERSION,"geometry_key": geometry_key,"complete_key": artifact_key(dna,geometry_key,"complete"),"rig_key": artifact_key(dna,geometry_key,"rig"),"groups": groups,"collision_scope": "mapped_26_point_convex_rest_inspection_only","animation_scope": "small_deformation_test_not_gait"}
static func validate_record(dna: Dictionary, geometry_key: String) -> Dictionary:
	if not enabled(dna):
		return {"ok": not dna.has("group_finalization"),"error": "A finalized-group record requires its explicit finalized mode."}
	if not dna.get("group_finalization") is Dictionary: return {"ok": false,"error": "Completed group model is missing its finalization reference."}
	# Canonical JSON tolerates parser int/float enum representation only; all
	# identity strings, membership, keys and declared scope must be exact.
	var persisted: Dictionary = dna.group_finalization.duplicate(true)
	if not Field.number(persisted.get("version")) or float(persisted.version) != float(VERSION): return {"ok": false,"error": "Unsupported group finalization version."}
	persisted["version"] = VERSION
	if JSON.stringify(persisted,"",true,true) != JSON.stringify(record(dna,geometry_key),"",true,true):
		return {"ok": false,"error": "Saved group finalization identity does not match completed geometry."}
	return {"ok": true}
static func context(dna: Dictionary) -> Dictionary:
	var checked: Dictionary = Field.validate(dna)
	if not bool(checked.get("ok",false)): return {"error": checked.get("error","Invalid group map.")}
	var fields: Dictionary = {}; var nodes: Dictionary = {}
	for n: Dictionary in dna.nodes: nodes[n.id] = n
	for n: Dictionary in dna.nodes:
		if not Field.marked(n): continue
		var field: RefCounted = Field.create(dna,n)
		for member: String in n.shape[Field.KEY].members: fields[member] = field
	return {"fields": fields,"nodes": nodes}
static func proxy_points(node: Dictionary, field: RefCounted) -> PackedVector3Array:
	var points := PackedVector3Array(); var center: Vector3 = Field.vec(node.position); var radii: Vector3 = Field.vec(node.size)
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				if x != 0 or y != 0 or z != 0: points.append(field.forward(center+Vector3(x,y,z).normalized()*radii))
	return points
static func prepare_proxies(dna: Dictionary, geometry: Dictionary) -> Dictionary:
	if not enabled(dna): return {"ok": true}
	var ctx: Dictionary = context(dna)
	if ctx.has("error"): return ctx
	var proxies: Array = geometry.get("collision_proxies",[]).duplicate(true); var changed := 0
	for i in range(proxies.size()):
		var proxy: Dictionary = proxies[i]; var id: String = str(proxy.get("component",""))
		if not ctx.fields.has(id): continue
		var node: Dictionary = ctx.nodes[id]; var field: RefCounted = ctx.fields[id]
		var points: PackedVector3Array = proxy_points(node,field)
		if proxy.get("kind") == "mapped_convex":
			if proxy.get("points") != points or proxy.get("group_owner_id") != field.d.owner_id or proxy.get("feature_id") != node.feature_id: return {"error": "Stale mapped inspection proxy."}
			changed += 1
			continue
		if proxy.get("kind") != "ellipsoid" or node.kind != "mass": return {"error": "Unsupported grouped collision proxy."}
		for p: Vector3 in points:
			if not p.is_finite(): return {"error": "Nonfinite mapped inspection proxy."}
		proxies[i] = {"kind": "mapped_convex","points": points,"position": Field.arr(field.forward(Field.vec(node.position))),"component": id,"feature_id": node.feature_id,"group_owner_id": field.d.owner_id,"parent_component": node.parent,"profile": PROFILE}
		changed += 1
	geometry["collision_proxies"] = proxies
	geometry["group_proxy_report"] = {"profile": PROFILE,"mapped_proxies": changed,"points_per_proxy": 26,"scope": "rest_space_coarse_inspection_not_cavity_exact_or_soft_body_collision"}
	return {"ok": true}
static func adapt_rig(dna: Dictionary, source: Dictionary) -> Dictionary:
	if not enabled(dna): return {"rig": source,"binding_dna": dna}
	var ctx: Dictionary = context(dna)
	if ctx.has("error"): return ctx
	var rig: Dictionary = source.duplicate(true); var bind: Dictionary = dna.duplicate(true)
	var mapped: Array = []; var mapped_indices: Dictionary = {}
	for i in range(rig.bones.size()):
		var bone: Dictionary = rig.bones[i]; var id: String = str(bone.component_id)
		if not ctx.fields.has(id): continue
		var field: RefCounted = ctx.fields[id]
		var start: Vector3 = field.forward(bone.start); var end: Vector3 = field.forward(bone.end)
		var length: float = maxf(bone.start.distance_to(bone.end),0.05)
		var x_landmark: Vector3 = field.forward(bone.start+bone.global_rest.basis.x*length)
		var y: Vector3 = (end-start).normalized()
		var x: Vector3 = (x_landmark-start)-y*(x_landmark-start).dot(y)
		if not start.is_finite() or not end.is_finite() or end.distance_to(start)<0.00001 or x.length_squared()<0.00000001: return {"error": "Degenerate mapped bone frame."}
		x = x.normalized(); var z: Vector3 = x.cross(y).normalized(); x = y.cross(z).normalized()
		bone.start = start; bone.end = end; bone.global_rest = Transform3D(Basis(x,y,z),start)
		bone["group_owner_id"] = field.d.owner_id
		mapped_indices[i] = true
		mapped.append({"bone_index": i,"component_id": id,"feature_id": ctx.nodes[id].feature_id,"group_owner_id": field.d.owner_id,"rest_start": source.bones[i].start,"rest_end": source.bones[i].end,"mapped_start": start,"mapped_end": end,"mapped_x_landmark": x_landmark})
	# Parent order is the existing unchanged skeleton order. A mapped global
	# frame changes its own local rest and the local rest of any direct child.
	for i in range(rig.bones.size()):
		var bone: Dictionary = rig.bones[i]; var parent: int = int(bone.parent)
		if mapped_indices.has(i) or mapped_indices.has(parent):
			bone.rest = rig.bones[parent].global_rest.affine_inverse()*bone.global_rest if parent >= 0 else bone.global_rest
	for node: Dictionary in bind.nodes:
		var id: String = str(node.id)
		if not ctx.fields.has(id): continue
		var field: RefCounted = ctx.fields[id]; var center: Vector3 = field.forward(Field.vec(node.position))
		var extent := Vector3.ZERO
		for p: Vector3 in proxy_points(ctx.nodes[id],field): extent = extent.max((p-center).abs())
		node.position = Field.arr(center); node.size = Field.arr(extent.max(Vector3.ONE*0.00001))
		node["bind_group_owner_id"] = field.d.owner_id
		rig.component_nodes[id] = node
		if node.kind == "cavity":
			var parent: String = str(node.parent)
			if not rig.component_bones.has(parent): return {"error": "Cavity lost its parent carrier during finalization."}
			rig.component_bones[id] = rig.component_bones[parent].duplicate()
	rig["group_binding"] = {"profile": PROFILE,"version": VERSION,"mapped_bones": mapped,"bone_count_unchanged": rig.bones.size() == source.bones.size(),"frame_transport": "forwarded_start_end_and_transverse_chord","source_nodes_immutable": true}
	return {"rig": rig,"binding_dna": bind}
