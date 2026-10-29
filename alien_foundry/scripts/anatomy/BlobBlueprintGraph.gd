extends "res://alien_foundry/scripts/anatomy/AnatomyGraph.gd"
## The v2 authoring adapter registers meaning BEFORE creating its geometry node.
## Legacy generators continue to instantiate the original AnatomyGraph.
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
var biological_blueprint: Dictionary = {}
var current_iteration := 1
var declared_feature_id := ""
var owner_feature_id := ""
var _feature_counters := {}
var _node_features := {}

func initialize(creature_type: String, seed_value: int, options: Dictionary) -> void:
	super.initialize(creature_type, seed_value, options)
	biological_blueprint = Blueprint.create(seed_value)
	dna["biological_blueprint"] = biological_blueprint

func _add(n: Dictionary) -> String:
	if dna.nodes.size() >= int(dna.budget.nodes): return str(n.get("parent", ""))
	var feature_id := owner_feature_id if not owner_feature_id.is_empty() else declared_feature_id
	var parent_feature := str(_node_features.get(str(n.get("parent", "")), ""))
	if feature_id.is_empty():
		var kind := "limb" if str(n.get("role", "")) in ["limb", "digit"] else "body"
		if str(n.get("kind", "")) == "cavity": kind = "cavity"
		var prefix := "blob.body.core" if str(n.get("parent", "")).is_empty() else "blob.%s.%s" % [kind, str(n.get("role", "part"))]
		var counter := int(_feature_counters.get(prefix, 0))
		_feature_counters[prefix] = counter + 1
		feature_id = prefix if parent_feature.is_empty() else prefix + "." + str(counter)
		var direction: Vector3 = vec(n.get("position", [0, 1, 0])) - center(str(n.get("parent", ""))) if not parent_feature.is_empty() else Vector3.UP
		Blueprint.declare(biological_blueprint, feature_id, kind, parent_feature, current_iteration, direction, n)
	else:
		assert(not Blueprint.feature(biological_blueprint, feature_id).is_empty())
	var id: String = super._add(n)
	Blueprint.bind_node(biological_blueprint, feature_id, node(id), current_iteration)
	_node_features[id] = feature_id
	declared_feature_id = ""
	owner_feature_id = ""
	return id

func feature_for_node(id: String) -> String:
	return str(_node_features.get(id, ""))
