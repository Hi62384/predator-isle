extends RefCounted
## One fixed oblique three-contact completion, not an alternate primary mass.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Contact = preload("res://alien_foundry/scripts/geometry/BlobGrownContactField.gd")
const SETTING := "blob_grown_contacts_version"

static func selected(settings: Dictionary) -> bool:
	var value: Variant=settings.get(SETTING,0)
	return (value is int or value is float) and float(value)==1.0

static func supports(g: RefCounted,regions: Dictionary,m: Dictionary) -> Array:
	if not selected(g.settings):return []
	var body: Dictionary=g.node(regions.root)
	var field: RefCounted=Graph.GrownField.create(body.shape.grown_envelope,Graph.vec(body.size))
	var floor_y: float=field.minimum_surface_y().minimum_y
	var w: float=m.width;var d: float=m.depth
	var specifications: Array=[
		{"name":"leading_right_fluke","root":[0.68,-0.25,-0.69],"shoulder":[0.60,-0.65,-0.55],"end":[1.12,-1.12,1.36,-1.30],"radii":[0.30,0.30,0.25,0.16],"width":1.30,"depth":0.80,"blend":0.13},
		{"name":"rear_left_load_root","root":[-0.78,0.15,0.55],"shoulder":[-0.75,-0.60,0.55],"end":[-1.10,0.65,-1.26,0.81],"radii":[0.30,0.29,0.26,0.20],"width":1.18,"depth":0.92,"blend":0.12},
		{"name":"small_rear_right_contact","root":[0.55,-0.20,0.83],"shoulder":[0.53,-0.64,0.67],"end":[0.78,1.05,0.88,1.20],"radii":[0.20,0.20,0.16,0.11],"width":1.12,"depth":0.88,"blend":0.09}]
	var result: Array=[];var records: Array=[]
	for spec: Dictionary in specifications:
		var radii: Array=[]
		for value in spec.radii:radii.append(float(value)*w)
		var points: Array=[field.surface(Graph.vec(spec.root))*0.45,
			field.surface(Graph.vec(spec.shoulder))*0.85,
			Vector3(float(spec.end[0])*w,floor_y+float(radii[2])*float(spec.depth),float(spec.end[1])*d),
			Vector3(float(spec.end[2])*w,floor_y+float(radii[3])*float(spec.depth),float(spec.end[3])*d)]
		var id: String=g.curve(regions.root,"limb",points,radii,"flesh",true)
		var node: Dictionary=g.node(id)
		node["shape"]={"grown_contact_version":1,"width":spec.width,"depth":spec.depth,"swelling":0.0,"twist":0.0,"taper":0.0}
		node["noise"]=0.0;node["blend"]=w*float(spec.blend)
		node["blob_region"]=spec.name
		# Only the last two authored controls are seated. Buried origins and the
		# fixed primary body's shape are untouched; saved points are authoritative.
		var shifts: Array=[]
		for iteration in range(4):
			var measurement: Dictionary=Contact.minimum(node)
			var shift: float=floor_y-float(measurement.minimum_y)
			if not is_finite(shift) or absf(shift)<0.00002:break
			for i in [2,3]:node.points[i][1]=float(node.points[i][1])+shift
			shifts.append(shift)
		var record: Dictionary=Contact.minimum(node)
		record["id"]=id;record["name"]=spec.name;record["basal_authoring_shifts"]=shifts
		record["target_body_minimum_y"]=floor_y;records.append(record);result.append(id)
	g.dna.metadata.grown_envelope_anatomy["supports"]=3
	g.dna.metadata["grown_contact_anatomy"]={"version":1,"contacts":3,"primary_descriptor_unchanged":true,"layout":"oblique_leading_right_fluke_rear_left_load_root_small_rear_right_contact","authoring":records,"rig_acceptance":"not_run"}
	return result
