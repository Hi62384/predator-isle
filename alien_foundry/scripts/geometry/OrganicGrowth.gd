class_name OrganicGrowth
extends RefCounted
## Deterministic surface-guided branching utilities for new anatomical rules.
## Growth begins inside its parent; local repulsion avoids growth through nearby
## nodes. It returns graph data rather than mutating any scene object.
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")

static func branch(parent: Dictionary, neighbours: Array, seed_value: int, length: float, radius: float, direction: Vector3, steps: int = 6) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var origin := Curves.vector(parent.get("position", [0.0, 0.0, 0.0]))
	var parent_size := Curves.vector(parent.get("size", [0.5, 0.5, 0.5]), Vector3.ONE * 0.5)
	var heading := direction.normalized()
	if heading.length_squared() < 0.1:
		heading = Vector3.UP
	var point := origin + heading * minf(parent_size.x, minf(parent_size.y, parent_size.z)) * 0.56
	var positions: Array = [[point.x, point.y, point.z]]
	var radii: Array = [radius * 1.22]
	for i in range(maxi(steps, 2)):
		var avoidance := Vector3.ZERO
		for other in neighbours:
			if str(other.get("id", "")) == str(parent.get("id", "")):
				continue
			var delta := point - Curves.vector(other.get("position", [0.0, 0.0, 0.0]))
			var reach := Curves.vector(other.get("size", [0.2, 0.2, 0.2])).length() + radius
			if delta.length_squared() < reach * reach and delta.length_squared() > 0.001:
				avoidance += delta.normalized() * (1.0 - delta.length() / reach)
		var drift := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.5), rng.randf_range(-0.4, 0.4))
		heading = (heading + drift * 0.30 + avoidance * 0.42).normalized()
		point += heading * length / float(maxi(steps, 2)) * rng.randf_range(0.8, 1.12)
		positions.append([point.x, point.y, point.z])
		radii.append(maxf(radius * pow(1.0 - float(i + 1) / float(steps + 1), 0.72), radius * 0.20))
	return {"id": "growth_%s_%s" % [str(parent.get("id", "root")), str(seed_value)], "parent": str(parent.get("id", "")), "kind": "curve", "position": positions[0], "points": positions, "radii": radii, "radius": radius, "size": [radius, length, radius], "material": "root", "blend": radius * 0.70, "noise": radius * 0.10, "bone": true, "shape": {"swelling": 0.12, "twist": 0.14}}
