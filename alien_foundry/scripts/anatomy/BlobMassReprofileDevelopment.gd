extends RefCounted
##203 authors shapes for the same body identities, never an added carrier.
const Field=preload("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd")
const Group=preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const Blueprint=preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
static func apply(g: RefCounted) -> Dictionary:
	if g.dna.get("nodes",[]).is_empty(): return {"error":"203 requires existing202 anatomy."}
	var core: Dictionary=g.dna.nodes[0]
	if not Group.marked(core): return {"error":"203 lacks exact202 body group."}
	var base: RefCounted=Group.create(core)
	if not base.valid: return {"error":base.error}
	var roles:=Field.role_map(g.dna,base.descriptor)
	if roles.has("error"): return roles
	var desc: Dictionary={"version":1,"mode":Field.MODE,"pin":Field.PIN,"owner_id":base.owner_id,"member_ids":base.member_ids.duplicate(),"member_feature_ids":base.descriptor.member_feature_ids.duplicate(),"base_group":base.descriptor.duplicate(true),"profile_entries":Field.make_entries(base,roles),"crown_policy":"failed_aesthetic_diagnostic_not_geometry_gate"}
	for id: String in desc.member_ids:
		var node: Dictionary=g.node(id)
		node.shape[Field.KEY]=desc.duplicate(true)
		var feature: Dictionary=Blueprint.feature(g.biological_blueprint,str(node.feature_id))
		feature.geometry_recipe[Field.KEY]={"stage":2,"mode":Field.MODE,"pin":Field.PIN,"role":roles[id],"member_ids":desc.member_ids.duplicate(),"regional_partition":"actual202_union_then_existing201_partition","internal_geometry_contributors":4}
	g.dna.settings[Field.SETTING]=Field.MODE
	var report: Dictionary={"version":1,"mode":Field.MODE,"pin":Field.PIN,"stage":2,"member_ids":desc.member_ids.duplicate(),"member_feature_ids":desc.member_feature_ids.duplicate(),"external_group_evaluations":1,"internal_carriers":4,"supports_unchanged":true,"protected_calls_unchanged":true,"outer_host_changed":true,"aesthetic_diagnostic_retained":true,"actual_volume_pending":true,"visual_acceptance_pending":true,"anatomical_acceptance":false}
	g.dna.metadata[Field.KEY]=report
	var field:=Field.create(core)
	if not field.valid: return {"error":field.error,"mass_reprofile203_qualification":field.qualification}
	return report
