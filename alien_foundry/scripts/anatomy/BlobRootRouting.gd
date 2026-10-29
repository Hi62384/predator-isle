extends RefCounted
## Collision-aware primary fleshy-root routing. Not a surface operation.
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Volume = preload("res://alien_foundry/scripts/geometry/OrganicVolume.gd")

static func body_field(dna: Dictionary) -> Dictionary:
	var volume := Volume.new()
	volume.source_dna = dna
	var masses: Array = []
	for node: Dictionary in dna["nodes"]:
		if node["kind"] == "mass": masses.append(node)
	volume._prepare(masses, 1)
	var bucket := PackedInt32Array()
	for i in range(volume.influences.size()): bucket.append(i)
	return {"volume": volume, "bucket": bucket}

static func check(candidate: Dictionary, previous: Array, body: Dictionary, minimum_gap: float) -> Dictionary:
	var a: Dictionary = Curves.sample(candidate, 5, true)
	var minimum := INF
	for other: Dictionary in previous:
		var b: Dictionary = Curves.sample(other, 5, true)
		for ai in range(a["points"].size()-1):
			for bi in range(b["points"].size()-1):
				var a0: Vector3 = a["points"][ai]; var a1: Vector3 = a["points"][ai+1]
				var b0: Vector3 = b["points"][bi]; var b1: Vector3 = b["points"][bi+1]
				var closest: PackedVector3Array = Geometry3D.get_closest_points_between_segments(a0,a1,b0,b1)
				var ta := a0.distance_to(closest[0])/maxf(a0.distance_to(a1),0.0001)
				var tb := b0.distance_to(closest[1])/maxf(b0.distance_to(b1),0.0001)
				var ra := lerpf(a["radii"][ai],a["radii"][ai+1],ta)
				var rb := lerpf(b["radii"][bi],b["radii"][bi+1],tb)
				var gap := closest[0].distance_to(closest[1])-ra-rb
				var safe_gap := minimum_gap+(float(candidate["blend"])+float(other["blend"]))*0.25
				if gap >= safe_gap: continue
				var witness := closest[0].lerp(closest[1],ra/(ra+rb))
				var inside_body: float = body["volume"]._field_value(witness,body["bucket"],false,false)
				if inside_body < -minimum_gap: continue # only shared buried origins
				minimum=minf(minimum,gap-safe_gap)
				if gap < safe_gap:
					return {"accepted":false,"minimum_margin":minimum,"other":other.get("id",""),"body_distance":inside_body}
	return {"accepted":true,"minimum_margin":minimum if minimum != INF else minimum_gap}
