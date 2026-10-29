extends RefCounted
## 201 authoring: the existing core/dominant-lobe identities become contributors
## to one shared anatomical envelope. No graph geometry, counts or IDs move.
const Field = preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
static func _support(node: Dictionary, direction: Vector3) -> float:
	var basis := Graph.node_basis(node)
	var radii := Graph.vec(node.size)
	return Vector3(basis.x.dot(direction)*radii.x,basis.y.dot(direction)*radii.y,basis.z.dot(direction)*radii.z).length()
static func apply(g: RefCounted) -> Dictionary:
	var trace: Dictionary = g.dna.get("metadata", {}).get("base_volume_development", {})
	if not trace.get("allocations") is Array or trace.allocations.is_empty() or not trace.get("body_node_ids") is Array: return {"error":"201 requires the actual195 development trace."}
	var core: Dictionary = g.node(str(trace.body_node_ids[0])); var child: Dictionary = g.node(str(trace.allocations[0].node_id))
	if core.is_empty() or child.is_empty() or child.get("parent") != core.id: return {"error":"201 attachment pair is invalid."}
	var delta := Graph.vec(child.position)-Graph.vec(core.position)
	if delta.length_squared()<0.00000001: return {"error":"201 attachment axis is degenerate; no fallback."}
	var length := delta.length(); var n := delta.normalized()
	var v := Vector3.UP-n*n.dot(Vector3.UP)
	if v.length_squared()<0.00000001: return {"error":"201 load frame is degenerate; no fallback."}
	v=v.normalized(); var u := v.cross(n).normalized()
	var caps: Array = []
	var pair_volume := 0.0
	for node: Dictionary in [core,child]:
		caps.append([_support(node,n)/length,_support(node,v)/length,_support(node,u)/length])
		var size := Graph.vec(node.size)
		pair_volume += 4.0*PI*size.x*size.y*size.z/3.0
	var members := [str(core.id),str(child.id)]; var features := [str(core.feature_id),str(child.feature_id)]
	var desc := {"version":2,"mode":Field.MODE,"pin":Field.PIN,"owner_id":core.id,"member_ids":members,"member_feature_ids":features,
		"frame":{"origin":Graph.arr(Graph.vec(core.position)),"u":Graph.arr(u),"v":Graph.arr(v),"n":Graph.arr(n),"length":length},
		"caps":caps,"profiles":Field.authored_profiles(caps),"blend_ratio":maxf(float(core.blend),float(child.blend))/length,
		"pair_nominal_volume_ratio":pair_volume/pow(length,3.0),"program":Field.PROGRAM.duplicate(),"union_context":Field.union_context(g.dna.nodes)}
	for node: Dictionary in [core,child]:
		var feature: Dictionary = Blueprint.feature(g.biological_blueprint,str(node.feature_id))
		if feature.is_empty() or feature.type != "body" or node.kind != "mass": return {"error":"201 refuses non-body members."}
		node.shape[Field.KEY]=desc.duplicate(true)
		feature.geometry_recipe["body_envelope201"]={"stage":2,"mode":Field.MODE,"pin":Field.PIN,"owner_feature_id":core.feature_id,"member_ids":members.duplicate(),"regional_partition":"axial_smootherstep_0.25_0.75"}
	g.dna.settings[Field.SETTING]=Field.MODE
	var result := {"version":1,"mode":Field.MODE,"pin":Field.PIN,"stage":2,"member_ids":members,"member_feature_ids":features,
		"scalar_evaluations":1,"supports_unchanged":true,"other_masses_unchanged":true,"actual_volume_pending":true,"visual_acceptance_pending":true,"anatomical_acceptance":false}
	g.dna.metadata["body_envelope201"]=result
	# Qualification is deterministic and rejects this fixed recipe. It must not
	# quietly switch coefficients, pick a seed or restore two primitive carriers.
	var field: RefCounted = Field.create(core)
	if not field.valid: return {"error":field.error,"body_envelope201_qualification":field.qualification}
	return result
