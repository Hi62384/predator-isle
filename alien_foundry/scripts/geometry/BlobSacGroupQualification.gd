extends RefCounted
## Fixed finite sections, not a continuous/global curvature or resolution proof.
const Field = preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
const STATIONS := [-0.20,0.10,0.40]
const MIN_WEIGHT := 0.35
const MIN_WIDTH_CELLS := 3.0
const MIN_RELIEF_CELLS := 0.50
static func bucket(volume: RefCounted) -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in range(volume.influences.size()): result.append(i)
	return result
static func value(volume: RefCounted, p: Vector3, all: PackedInt32Array) -> float: return volume._field_value(p,all,true,true,true)
static func surface(volume: RefCounted, group: RefCounted, x: float, y: float, all: PackedInt32Array, detailed: bool) -> Dictionary:
	# Evaluate the actual complete field on a group-frame ray, keeping the
	# same x/y section for macro and detailed maps. Never omit a clipped ray.
	var saved: float = group.amplitude
	if not detailed: group.amplitude = 0.0
	var previous: float = -3.0*group.radii.z
	var a: Vector3 = group.forward(group.origin+group.basis*Vector3(x,y,previous))
	var previous_value: float = value(volume,a,all)
	var bracket: Array = []
	for i in range(1,65):
		var z: float = lerpf(-3.0*group.radii.z,3.0*group.radii.z,float(i)/64.0)
		var point: Vector3 = group.forward(group.origin+group.basis*Vector3(x,y,z))
		var sample: float = value(volume,point,all)
		if previous_value <= 0.0 and sample > 0.0: bracket = [previous,z]
		previous = z; previous_value = sample
	if bracket.is_empty(): group.amplitude = saved; return {"ok": false,"reason": "no_complete_field_exit_in_declared_ray"}
	var low: float = bracket[0]; var high: float = bracket[1]
	for i in range(22):
		var mid: float = (low+high)*0.5
		var p: Vector3 = group.forward(group.origin+group.basis*Vector3(x,y,mid))
		if value(volume,p,all) > 0.0: high = mid
		else: low = mid
	var rest: Vector3 = group.origin+group.basis*Vector3(x,y,(low+high)*0.5)
	var point: Vector3 = group.forward(rest)
	var residual: float = absf(value(volume,point,all))
	group.amplitude = saved
	return {"ok": residual < 0.00002,"point": point,"rest": rest,"residual": residual}
static func evaluate(volume: RefCounted) -> Dictionary:
	var report := {"ok": true,"method": "fixed_composed_group_sections_v1","finite_sampling_only": true,"global_resolution_proof": false,"step": volume.step,"stations": STATIONS,"minimum_weight": MIN_WEIGHT,"minimum_width_cells": MIN_WIDTH_CELLS,"minimum_composed_relief_cells": MIN_RELIEF_CELLS,"features": [],"roots": [],"cavity_channels": []}
	var all: PackedInt32Array = bucket(volume)
	var nodes: Dictionary = {}; var groups: Dictionary = {}
	for n: Dictionary in volume.source_dna.nodes: nodes[n.id] = n
	for item: RefCounted in volume.influences:
		if item.sac_group != null: groups[item.sac_group.d.owner_id] = item.sac_group
	for id: String in groups:
		var group: RefCounted = groups[id]; var owner: Dictionary = nodes[id]; var host: Dictionary = nodes[owner.parent]
		var root_ok := true; var deepest := -INF; var identity_error := 0.0
		for i in range(17):
			var rest: Vector3 = Field.vec(host.position).lerp(Field.vec(owner.position),float(i)/16.0)
			var p: Vector3 = group.forward(rest)
			var sample: float = value(volume,p,all); deepest = maxf(deepest,sample)
			if sample > -0.12*volume.step: root_ok = false
		# Explicit buried identity neighborhood, not an angular protected island.
		for dx: float in [-0.03,0.0,0.03]:
			for dz: float in [-0.03,0.0,0.03]:
				var p: Vector3 = group.origin+group.basis*Vector3(dx*group.radii.x,group.root_y-0.04*group.radii.y,dz*group.radii.z)
				identity_error = maxf(identity_error,group.forward(p).distance_to(p))
				if value(volume,p,all) > -0.12*volume.step: root_ok = false
		report.roots.append({"owner_id": id,"ok": root_ok and identity_error == 0.0,"root_y": group.root_y,"maximum_path_field": deepest,"identity_error": identity_error,"sample_count": 26})
		if not root_ok or identity_error != 0.0: report.ok = false
		for member: String in group.d.members:
			if nodes[member].kind != "cavity": continue
			var center: Vector3 = Field.vec(nodes[member].position)
			var direction: Vector3 = (center-group.origin).normalized()
			var min_air := INF; var movement := 0.0
			var tangent: Vector3 = direction.cross(Vector3.UP).normalized()
			if tangent.length_squared() < 0.1: tangent = Vector3.RIGHT
			var second: Vector3 = direction.cross(tangent).normalized()
			var channel_radius: float = minf(Field.vec(nodes[member].size).x,minf(Field.vec(nodes[member].size).y,Field.vec(nodes[member].size).z))*0.18
			for i in range(25):
				for offset: Vector3 in [Vector3.ZERO,tangent*channel_radius,-tangent*channel_radius,second*channel_radius,-second*channel_radius]:
					var rest: Vector3 = center+direction*float(i)/24.0*group.radii.length()*1.5+offset
					var p: Vector3 = group.forward(rest)
					min_air = minf(min_air,value(volume,p,all)); movement = maxf(movement,p.distance_to(rest))
			var channel_ok: bool = min_air > volume.step*0.10
			report.cavity_channels.append({"owner_id": id,"cavity_id": member,"ok": channel_ok,"minimum_air_field": min_air,"rest_channel_radius": channel_radius,"maximum_common_map_movement": movement,"sample_count": 125})
			if not channel_ok: report.ok = false
		var feature := {"owner_id": id,"feature_id": group.d.feature_id,"ok": true,"sections": [],"active_sections": 0,"status": "measured"}
		if group.d.creases.is_empty() or group.amplitude == 0.0:
			feature.status = "skipped_zero_amplitude" if not group.d.creases.is_empty() else "declared_smooth_region_or_base_stage"
			report.features.append(feature); continue
		for index in range(group.d.creases.size()):
			var crease: Dictionary = group.d.creases[index]
			for station: float in STATIONS:
				var y: float = station*group.radii.y
				var weight: float = group.gate(y)*exp(-pow((station-0.18)/0.85,4.0))
				var row := {"crease": index,"station": station,"weight": weight,"status": "active","ok": false}
				if weight < MIN_WEIGHT:
					row.status = "omitted_below_declared_root_weight"; row.ok = true; feature.sections.append(row); continue
				feature.active_sections += 1
				var x: float = float(crease.center)*group.radii.x
				var halfwidth: float = float(crease.width)*group.radii.x/sqrt(5.0)
				var center: Dictionary = surface(volume,group,x,y,all,true)
				var macro: Dictionary = surface(volume,group,x,y,all,false)
				var left: Dictionary = surface(volume,group,x-halfwidth,y,all,true)
				var right: Dictionary = surface(volume,group,x+halfwidth,y,all,true)
				if not center.ok or not macro.ok or not left.ok or not right.ok:
					row.status = "unqualified_clipped_or_invalid_composed_section"; feature.ok = false; feature.sections.append(row); continue
				var width: float = left.point.distance_to(right.point)
				var relief: float = (center.point-macro.point).dot(group.basis.z)
				var rest_z: float = (group.inverse_basis*(macro.rest-group.origin)).z
				var before_root: float = group.amplitude*float(crease.strength)*rest_z
				row["width_cells"] = width/volume.step; row["composed_relief_cells"] = relief/volume.step
				row["composed_relief"] = relief; row["single_non_cancelling_envelope_before_root"] = before_root
				row["envelope_after_root_and_axial_fade"] = before_root*weight
				row["surface_residual_max"] = maxf(maxf(center.residual,macro.residual),maxf(left.residual,right.residual))
				row.ok = width >= volume.step*MIN_WIDTH_CELLS and relief >= volume.step*MIN_RELIEF_CELLS
				if not row.ok: feature.ok = false
				feature.sections.append(row)
		if feature.active_sections == 0: feature.ok = false; feature.status = "unqualified_no_active_sections"
		if not feature.ok: report.ok = false
		report.features.append(feature)
	return report
