extends RefCounted
## Bounded Stage-1 grammar-3 study. One envelope replaces ALL upper, belly,
## crest and flank ellipsoids. Two unequal oblique load roots, no small sacs.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Field = preload("res://alien_foundry/scripts/geometry/BlobMantleField.gd")
const Placement = preload("res://alien_foundry/scripts/anatomy/BlobMantlePlacement.gd")
const VERSION := 1

static func selected(settings: Dictionary) -> bool:
	var version: Variant = settings.get("blob_mantle_version", 0)
	return (version is int or version is float) and float(version) in [1.0,2.0,3.0,4.0]

static func build(generator: RefCounted, g: RefCounted, m: Dictionary) -> Dictionary:
	var w := float(m.width); var h := float(m.height); var d := float(m.depth); var mirror := float(m.mirror)
	# Broad crown, descending shoulder, tensioned waist and basal load flare
	# are coupled sections of ONE continuous surface. Width and depth never
	# share a constant radius and the centerline bends in both x and z.
	var sections: Array = [
		[-0.25*mirror,-0.20,1.04,0.64],
		[-0.24*mirror,-0.15,1.04,0.64],
		[-0.05*mirror,-0.02,0.59,0.43],
		[0.20*mirror,0.15,0.70,0.48],
		[0.35*mirror,0.35,1.04,0.68],
		[0.40*mirror,0.45,0.95,0.74],
		[0.32*mirror,0.44,0.76,0.66]]
	var authoring_version := int(g.settings.get("blob_mantle_version",1))
	if authoring_version==2:
		# Coupled volume redistribution: thicken lower/middle tissue, soften
		# the thin basal lip, and retain a descending asymmetric load path.
		sections=[
			[-0.18*mirror,-0.16,1.02,0.96],
			[-0.17*mirror,-0.12,0.98,0.98],
			[-0.02*mirror,0.03,0.79,0.83],
			[0.18*mirror,0.18,0.83,0.79],
			[0.32*mirror,0.30,0.98,0.84],
			[0.36*mirror,0.37,0.92,0.86],
			[0.30*mirror,0.38,0.78,0.78]]
	if authoring_version in [3,4]:
		# Actual sections redistribute a fixed-volume body into a convex lower
		# middle. The old central near-constant-depth slab is not inflated.
		sections=[
			[-0.16*mirror,-0.12,0.90,0.90],
			[-0.15*mirror,-0.10,0.90,0.83],
			[0.02*mirror,-0.06,0.91,1.00],
			[0.16*mirror,0.08,0.91,0.98],
			[0.29*mirror,0.25,0.84,0.82],
			[0.35*mirror,0.36,0.75,0.70],
			[0.32*mirror,0.42,0.65,0.55]]
	var root: String = g.mass("", "core", Vector3(0.0,h*(1.04 if authoring_version in [3,4] else 0.94),0.0),Vector3(w,h*0.94,d),"flesh",true)
	var node: Dictionary = g.node(root)
	node["shape"] = {"mantle_envelope":{"version":VERSION,"sections":sections}}
	node.noise = 0.0; node.blend = w*0.11
	node["blob_region"] = "continuous_hunched_mantle"
	node["surface"] = {"exposure":0.10,"growth":0.10}
	var regions: Dictionary = generator._semantic_regions(g,root,[root])
	g.dna.metadata["mantle_anatomy"] = {"version":authoring_version,"primary_envelopes":1,"subordinate_sacs":0,"buttresses":2,"stage1_only":true,"construction":"closed_bent_variable_section_loft","later_operations":"disabled_for_candidate"}
	return regions

static func supports(g: RefCounted, regions: Dictionary, m: Dictionary) -> Array:
	var w := float(m.width); var h := float(m.height); var d := float(m.depth); var mirror := float(m.mirror)
	var root := str(regions.root); var node: Dictionary = g.node(root)
	var field: RefCounted = Field.create(node.shape.mantle_envelope, Graph.vec(node.size))
	var origin := Graph.vec(node.position)
	if int(g.dna.metadata.mantle_anatomy.version)==3:return _adherent_folds(g,root,field,origin,m)
	if int(g.dna.metadata.mantle_anatomy.version)==4:return _ventral_load_flanks(g,root,field,origin,m)
	var result: Array = []
	var revised := int(g.dna.metadata.mantle_anatomy.version)==2
	# The first segment follows the derivative of an outer meridian downward,
	# starting well inside the shoulder. Not radial feet attached at the waist.
	for i in range(2):
		var t := (0.50 if i==0 else 0.36) if revised else (0.63 if i == 0 else 0.43)
		var angle := (0.30 if mirror > 0.0 else PI-0.30) if i == 0 else (2.62 if mirror > 0.0 else PI-2.62)
		var shell: Vector3 = origin + field.surface(t,angle)
		var center: Vector3 = origin + field.centerline(t)
		var anchor := shell.lerp(center,(0.44 if i==0 else 0.38) if revised else (0.34 if i == 0 else 0.30))
		var tangent: Vector3 = (field.surface(t-0.018,angle)-field.surface(t+0.018,angle)).normalized()
		var radius := w*(0.30 if i == 0 else 0.205)
		var bend := anchor+tangent*h*((0.27 if i==0 else 0.19) if revised else (0.35 if i == 0 else 0.22))
		var foot := Vector3(mirror*w*(1.03 if i == 0 else -0.82),radius*0.56,d*(-0.28 if i == 0 else 0.44))
		var end := foot+Vector3(mirror*w*(0.15 if i == 0 else -0.10),-radius*0.12,-d*0.07)
		if revised:
			# Re-seat shorter oblique roots into the thicker basal tissue.
			# No extra appendage and no compensating leg lengthening.
			foot=Vector3(mirror*w*(0.90 if i==0 else -0.72),radius*0.56,d*(-0.22 if i==0 else 0.34))
			end=foot+Vector3(mirror*w*(0.06 if i==0 else -0.05),-radius*0.12,-d*0.04)
		var id: String = g.curve(root,"limb",[anchor,bend,foot,end],[radius,radius*0.90,radius*0.62,radius*0.48],"flesh",true)
		var support: Dictionary = g.node(id)
		support.noise = 0.0; support.blend = w*(0.17 if i == 0 else 0.13)
		support.shape = {"mantle_buttress_version":1,"swelling":0.0,"twist":0.0,"width":1.22 if i == 0 else 1.10,"depth":0.80,"width_profile":[1.0,1.02,0.94,0.85],"depth_profile":[1.0,0.96,0.90,0.84]}
		support["blob_region"] = "mantle_loaded_buttress" if i == 0 else "mantle_counter_buttress"
		support["surface"] = {"exposure":0.15,"growth":0.08}
		result.append(id)
	return result


static func _adherent_folds(g: RefCounted, root: String, field: RefCounted, origin: Vector3, m: Dictionary) -> Array:
	var w:=float(m.width);var mirror:=float(m.mirror)
	var result: Array=[];var seating: Array=[]
	for i in range(2):
		var heights: Array=[0.59,0.38,0.18,0.055] if i==0 else [0.47,0.30,0.14,0.055]
		var angles: Array=[1.60,1.90,2.22,2.28] if i==0 else [-0.45,-0.65,-0.83,-0.88]
		var burial: Array=[0.35,0.20,0.12,0.05] if i==0 else [0.35,0.22,0.12,0.05]
		var points: Array=[]
		for k in range(4):
			var t:=float(heights[k]);var angle:=float(angles[k])
			if mirror<0.0:angle=PI-angle
			# Oblique, wrapping meridians. All four controls originate on the
			# body's real surface, not a free-standing root-to-foot chord.
			var point: Vector3=field.surface(t,angle).lerp(field.centerline(t),float(burial[k]))
			points.append(origin+point)
		var radius:=w*(0.36 if i==0 else 0.28)
		var radii: Array=[radius,radius*0.94,radius*0.86,radius*0.80] if i==0 else [radius,radius*0.92,radius*0.82,radius*0.74]
		var id: String=g.curve(root,"limb",points,radii,"flesh",true)
		var node: Dictionary=g.node(id)
		node.noise=0.0;node.blend=w*(0.12 if i==0 else 0.10)
		node.shape={"mantle_buttress_version":1,"swelling":0.0,"twist":0.0,"width":1.45 if i==0 else 1.30,"depth":0.55,"width_profile":[1.0,1.08,1.12,1.12],"depth_profile":[1.0,0.96,0.94,0.94]}
		node["blob_region"]="mantle_loaded_fold" if i==0 else "mantle_counter_fold"
		node["surface"]={"exposure":0.15,"growth":0.08}
		var contact:=Placement.seat_contact(node);contact["id"]=id;seating.append(contact)
		result.append(id)
	g.dna.metadata["mantle_contact_authoring"]={"target_plane_y":0.0,"contacts":seating,"root_controls_unchanged":true}
	return result


static func _ventral_load_flanks(g: RefCounted, root: String, field: RefCounted, origin: Vector3, m: Dictionary) -> Array:
	# One fixed structural test, not a coefficient sweep. The v3 core is exact.
	# Both flanks occupy the -Z ventral half and stay at opposite outer thirds.
	# Buried upper spheres emerge into substantial, near-round lower loads;
	# their inner sides remain intersecting the core, not free-standing legs.
	var w:=float(m.width);var mirror:=float(m.mirror)
	var result: Array=[];var seating: Array=[]
	for i in range(2):
		var heights: Array=[0.68,0.43,0.20,0.075] if i==0 else [0.48,0.31,0.16,0.075]
		var angles: Array=[-2.60,-2.60,-2.50,-2.45] if i==0 else [-0.55,-0.55,-0.60,-0.64]
		var burial: Array=[0.82,-0.03,-0.13,-0.15] if i==0 else [0.82,0.02,-0.08,-0.12]
		var points: Array=[]
		for k in range(4):
			var t:=float(heights[k]);var angle:=float(angles[k])
			if mirror<0.0:angle=PI-angle
			points.append(origin+field.surface(t,angle).lerp(field.centerline(t),float(burial[k])))
		var radii: Array=[w*0.30,w*0.42,w*0.40,w*0.26] if i==0 else [w*0.25,w*0.32,w*0.30,w*0.23]
		var id: String=g.curve(root,"limb",points,radii,"flesh",true)
		var node: Dictionary=g.node(id)
		node.noise=0.0;node.blend=w*(0.16 if i==0 else 0.13)
		node.shape={"mantle_buttress_version":1,"swelling":0.0,"twist":0.0,"width":1.08 if i==0 else 1.04,"depth":0.95,"width_profile":[1.0,1.0,1.04,1.12 if i==0 else 1.10],"depth_profile":[1.0,1.0,1.02,1.02]}
		node["blob_region"]="mantle_ventral_loaded_flank" if i==0 else "mantle_ventral_counter_flank"
		node["surface"]={"exposure":0.15,"growth":0.08}
		var contact:=Placement.seat_contact(node);contact["id"]=id;seating.append(contact)
		result.append(id)
	g.dna.metadata["mantle_contact_authoring"]={"target_plane_y":0.0,"contacts":seating,"root_controls_unchanged":true}
	return result
