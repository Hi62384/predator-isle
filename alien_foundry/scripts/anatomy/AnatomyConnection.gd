extends RefCounted
static func make(parent: String, child: String, kind: String = "growth", blend: float = 0.18) -> Dictionary:
	return {"from":parent, "to":child, "kind":kind, "blend":blend}
