extends RefCounted
## Fixed202 growth of the SAME three subordinate biological body members.
## Existing201 host descriptor, authored nodes and supports remain untouched.
const Field=preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const Envelope=preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const Branch=preload("res://alien_foundry/scripts/geometry/BlobBodyBranchField.gd")
const Existing=preload("res://alien_foundry/scripts/anatomy/BlobBodyEnvelopeDevelopment.gd")
const Graph=preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Blueprint=preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
static func apply(g: RefCounted) -> Dictionary:
	var report: Variant=g.dna.get("metadata",{}).get("body_envelope201")
	if not report is Dictionary or not report.get("member_ids") is Array or report.member_ids.size()!=2: return {"error":"202 requires actual201 core/dominant authoring."}
	var core: Dictionary=g.node(str(report.member_ids[0]))
	if not Envelope.marked(core): return {"error":"202 unchanged201 host missing."}
	var host: Dictionary=core.shape[Envelope.KEY].duplicate(true)
	var ids: Array=host.member_ids.duplicate(); var features: Array=host.member_feature_ids.duplicate()
	var branches: Array=[]
	var body_ids: Array=g.dna.metadata.base_volume_development.body_node_ids
	for node: Dictionary in g.dna.nodes:
		if node.id not in body_ids or node.id in host.member_ids: continue
		var feature: Dictionary=Blueprint.feature(g.biological_blueprint,str(node.feature_id))
		if node.get("parent")!=core.id or node.get("kind")!="mass" or feature.get("type")!="body" or Envelope.marked(node): return {"error":"202 refuses unsupported subordinate ownership."}
		var delta:=Graph.vec(node.position)-Graph.vec(core.position)
		if delta.length_squared()<0.00000001: return {"error":"202 attachment axis degenerate; no fallback."}
		var length:=delta.length(); var n:=delta.normalized()
		var v:=Vector3.UP-n*n.dot(Vector3.UP)
		if v.length_squared()<0.00000001: return {"error":"202 load frame degenerate; no fallback."}
		v=v.normalized(); var u:=v.cross(n).normalized()
		var ratio:=float(node.blend)/length
		# Dimensionless arithmetic is pinned, so uniform graph scaling preserves
		# the exact authored controls and nominal rho=3p relation.
		var rho:=Branch.ROOT_P_MULTIPLIER*(1.05*ratio)
		var caps: Array=[[rho,rho,rho],[Existing._support(node,n)/length,Existing._support(node,v)/length,Existing._support(node,u)/length]]
		branches.append({"id":node.id,"feature_id":node.feature_id,"frame":{"origin":Graph.arr(Graph.vec(core.position)),"u":Graph.arr(u),"v":Graph.arr(v),"n":Graph.arr(n),"length":length},"caps":caps,"blend_ratio":ratio,"controls":Branch.controls(caps),"program":Branch.BRANCH_PROGRAM.duplicate()})
		ids.append(node.id); features.append(node.feature_id)
	if branches.size()!=3: return {"error":"202 bounded grammar requires exactly three subordinate carriers."}
	var desc: Dictionary={"version":1,"mode":Field.MODE,"pin":Field.PIN,"owner_id":core.id,"member_ids":ids,"member_feature_ids":features,"host":host,"branches":branches,"union_context":Envelope.union_context(g.dna.nodes),"program":Branch.BRANCH_PROGRAM.duplicate()}
	for id: String in ids:
		var node: Dictionary=g.node(id)
		node.shape[Field.KEY]=desc.duplicate(true)
		var feature: Dictionary=Blueprint.feature(g.biological_blueprint,str(node.feature_id))
		feature.geometry_recipe[Field.KEY]={"stage":2,"mode":Field.MODE,"pin":Field.PIN,"owner_feature_id":core.feature_id,"member_ids":ids.duplicate(),"regional_partition":"actual_internal_smooth_min_then_existing201_partition","internal_geometry_contributors":4}
	g.dna.settings[Field.SETTING]=Field.MODE
	var result: Dictionary={"version":1,"mode":Field.MODE,"pin":Field.PIN,"stage":2,"member_ids":ids,"member_feature_ids":features,"external_group_evaluations":1,"internal_carriers":4,"supports_unchanged":true,"host201_unchanged":true,"finite_witnesses_only":true,"actual_volume_pending":true,"visual_acceptance_pending":true,"anatomical_acceptance":false}
	g.dna.metadata[Field.KEY]=result
	var field:=Field.create(core)
	if not field.valid: return {"error":field.error,"body_group202_qualification":field.qualification}
	return result
