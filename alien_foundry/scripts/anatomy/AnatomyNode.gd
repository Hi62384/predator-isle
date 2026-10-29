extends RefCounted
## Persistent components remain plain dictionaries so saved graphs are portable.
static func make(id: String, parent: String, kind: String, role: String, position: Array, size: Array, material: String = "flesh") -> Dictionary:
	return {"id":id, "parent":parent, "kind":kind, "role":role, "position":position, "size":size,
		"rotation":[0.0,0.0,0.0], "radius":float(size[0]), "points":[], "radii":[], "material":material, "blend":0.18,
		"noise":0.055, "bone":true, "joints":{"motion":"sway", "limits":[-0.3,0.3]},
		"deformation":{}, "mergeable":true, "replaceable":true, "source":""}
