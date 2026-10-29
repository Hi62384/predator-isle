extends RefCounted
##219 explicit two-void suffix. Declaration checks are not geometric safety.
## The thirteen positive carriers and their consumed215 identity stay exact.
const SETTING: String="blob_mantle_cavity_mode"
const PIN_SETTING: String="blob_mantle_cavity_pin217"
const MODE: String="surface_normal_blind_chambers_v1"
const OFF: String="off"
const PIN: String="234febaebac00eba43e3958f3c5da90766b30df821ef573140f41a7075a9e68f"
const KEY: String="mantle_cavities217"
const H: float=0.06132264835698207
const BASELINE_KEY: String="507ba7f69124c1aba8440c160e912dfd00b76f149ced40e51ca906fde57861d6"
const DEPENDENCY4: String="cf33780f55a7d8b0f8a6aa98f7eefdcc573cfe076bedd250e2ebda5cffadb464"
const IDS: Array[String]=["n013","n014"]
const FEATURES: Array[String]=["blob.cavity.mantle_rear.primary","blob.cavity.mantle_rear.secondary"]
const ROLES: Array[String]=["primary","secondary"]
const RADII: Array=[[0.185,0.300,0.520],[0.170,0.235,0.450]]
const ROLLS: Array[float]=[1.15,1.85]
const PREREQUISITES: Dictionary={"blob_pipeline_mode":"iterative_v2","blob_identity_profile":"positive_sacs_v1","blob_positive_growth_mode":"positive_sacs_only_v1","blob_sac_surface_mode":"central_keel_pleat_v1","blob_isosurface_grid_mode":"conflict_slabs_v1","blob_isosurface_normal_mode":"adaptive_field_gradient_v2","blob_isosurface_refinement_mode":"bracketed_field_edges_v1"}
const CONTEXT_KEYS: Array[String]=["version","mode","spec_sha256","coordinate_space","partial_stage","positive_node_ids","cavity_node_ids","carrier_feature_id","frame","reference_cell_m","feature_radius_m","wall_m","territory_half_extents_m","pair_separation_m","cavities","author_complete_field_calls","author_projection_field_calls","author_normal_field_calls"]
const ROW_KEYS: Array[String]=["role","node_id","feature_id","offset_m","radii_m","roll_radians","rotation","surface_hit","center","local_frame"]

const LOCAL_FRAME_KEYS: Array[String]=["version","method","planning_rotation","planning_axis","surface_hit","normal_epsilon_m","normal_values","normal_direction","planning_axis_dot","projected_tangent","local_bitangent","rotation","consumed_basis","consumed_normal","center","center_projection_role","center_normal_role","finite_sampling_only"]

static func text_is(value: Variant,expected: String)->bool:return value is String and value==expected
static func number(value: Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func integral(value: Variant)->bool:return number(value) and float(value)==floor(float(value))
static func vec(value: Array)->Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
static func arr(value: Vector3)->Array:return [value.x,value.y,value.z]
static func vector(value: Variant,count: int)->bool:
	if not value is Array or value.size()!=count:return false
	for item: Variant in value:
		if not number(item):return false
	return true
static func enabled(dna: Dictionary)->bool:
	var settings: Variant=dna.get("settings",{})
	return settings is Dictionary and text_is(settings.get(SETTING),MODE)
static func bits(value: float)->String:
	var bytes: PackedByteArray=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
static func same(a: Variant,b: Variant)->bool:
	if typeof(a)!=typeof(b):return false
	if a is float:return bits(a)==bits(b)
	if a is Dictionary:
		if a.size()!=b.size():return false
		for key: Variant in a:
			if not b.has(key) or not same(a[key],b[key]):return false
		return true
	if a is Array:
		if a.size()!=b.size():return false
		for i: int in range(a.size()):
			if not same(a[i],b[i]):return false
		return true
	return a==b
static func shadow_same(a: Variant,b: Variant)->bool:
	return same(a,b) or same(a,JSON.parse_string(JSON.stringify(b,"",true,true)))
static func keys_are(value: Variant,expected: Array)->bool:
	if not value is Dictionary or value.size()!=expected.size():return false
	for key: Variant in expected:
		if not value.has(key):return false
	return true
static func selection(options: Dictionary)->Dictionary:
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,MODE]:return {"error":"219 cavity selector must be an explicit supported string."}
	if options.has(PIN_SETTING) and (mode==OFF or not text_is(options.get(PIN_SETTING),PIN)):return {"error":"219 inactive or stale cavity pin."}
	if mode==OFF:return {"mode":OFF}
	for key: String in PREREQUISITES:
		if not text_is(options.get(key),str(PREREQUISITES[key])):return {"error":"219 missing explicit prerequisite: "+key}
	for pair: Array in [["quality",1.0],["size",1.0],["surface_detail",0.55]]:
		var value: Variant=options.get(str(pair[0]),pair[1])
		if not number(value) or float(value)!=float(pair[1]):return {"error":"219 requires fixed Standard/size1/detail0.55."}
	if not options.get("secondary_enabled",true) is bool or options.get("secondary_enabled",true):return {"error":"219 secondary anatomy remains disabled."}
	if not text_is(options.get("blob_direct_surface_profile",OFF),OFF):return {"error":"219 direct layers remain disabled."}
	var operations: Variant=options.get("surface_operations",[])
	if not operations is Array or not operations.is_empty():return {"error":"219 does not enable the legacy surface-operations dispatcher."}
	return {"mode":MODE}

static func positive_projection(dna: Dictionary)->Dictionary:
	var result: Dictionary=dna.duplicate(true)
	if result.get("settings") is Dictionary:
		result.settings.erase(SETTING);result.settings.erase(PIN_SETTING)
	if result.get("metadata") is Dictionary:
		result.metadata.erase(KEY)
		if result.metadata.has("node_count"):result.metadata.node_count=13
	if result.get("nodes") is Array:result.nodes=result.nodes.slice(0,13)
	if result.get("connections") is Array:result.connections=result.connections.slice(0,12)
	if result.get("biological_blueprint") is Dictionary and result.biological_blueprint.get("features") is Array:
		var kept: Array=[]
		for feature: Variant in result.biological_blueprint.features:
			if feature is Dictionary and feature.get("id") in FEATURES:continue
			if feature is Dictionary and feature.get("children") is Array:
				for id: String in FEATURES:feature.children.erase(id)
			kept.append(feature)
		result.biological_blueprint.features=kept
	if result.get("active_feature_ids") is Array:
		for id: String in FEATURES:result.active_feature_ids.erase(id)
	if result.get("feature_realization") is Dictionary:
		for id: String in FEATURES:result.feature_realization.erase(id)
	# The exact codec is filtered, not resealed from possibly rounded JSON.
	if result.get("geometry_numeric_recipe") is Dictionary and result.geometry_numeric_recipe.get("numbers") is Array:
		var entries: Array=[]
		for entry: Variant in result.geometry_numeric_recipe.numbers:
			if entry is Dictionary and entry.get("path") is Array and entry.path.size()>=2 and integral(entry.path[1]):
				if entry.path[0]=="nodes" and int(entry.path[1])>=13:continue
				if entry.path[0]=="connections" and int(entry.path[1])>=12:continue
			entries.append(entry)
		result.geometry_numeric_recipe.numbers=entries
	return result

## Original217c planning arithmetic is intentionally unchanged, including Euler ordering.
static func frame_table(dna: Dictionary)->Dictionary:
	var nodes: Variant=dna.get("nodes")
	if not nodes is Array or nodes.is_empty() or not nodes[0] is Dictionary:return {"error":"219 missing restored core."}
	var node: Dictionary=nodes[0]
	if not text_is(node.get("id"),"n000") or not text_is(node.get("feature_id"),"blob.body.core"):return {"error":"219 requires the original core owner."}
	var shape: Variant=node.get("shape",{})
	if not shape is Dictionary:return {"error":"219 malformed core shape."}
	var mass: Variant=shape.get("mass_reprofile203",{})
	if not mass is Dictionary or not mass.get("base_group") is Dictionary or not mass.base_group.get("host") is Dictionary:return {"error":"219 missing203 host frame."}
	var source: Variant=mass.base_group.host.get("frame")
	if not source is Dictionary or not number(source.get("length")) or float(source.length)<=0.0:return {"error":"219 invalid host length."}
	for key: String in ["origin","n","u","v"]:
		if not vector(source.get(key),3):return {"error":"219 invalid host frame."}
	var length: float=float(source.length)
	var n: Vector3=vec(source.n);var u: Vector3=vec(source.u);var v: Vector3=vec(source.v)
	var origin: Vector3=vec(source.origin)+0.05*length*v
	var normal: Vector3=-n-0.45*u+0.10*v
	if not normal.is_finite() or normal.length_squared()==0.0:return {"error":"219 degenerate normal."}
	normal=normal.normalized()
	var tangent: Vector3=-u-normal*(-u).dot(normal)
	if not tangent.is_finite() or tangent.length_squared()==0.0:return {"error":"219 degenerate tangent."}
	tangent=tangent.normalized()
	var bitangent: Vector3=normal.cross(tangent).normalized()
	var basis: Basis=Basis(tangent,bitangent,normal)
	if not bitangent.is_finite() or basis.determinant()<=0.0:return {"error":"219 invalid handedness."}
	var feature_floor: float=maxf(0.075*length,1.8*H)
	var wall: float=maxf(0.075*length,maxf(0.85*feature_floor,1.45*H))
	var direction: Vector2=Vector2(0.29,-0.48).normalized()
	var supports: Array[float]=[]
	for ordinal: int in range(2):
		var local: Vector2=direction.rotated(-ROLLS[ordinal])
		supports.append(sqrt(pow(float(RADII[ordinal][0])*length*local.x,2.0)+pow(float(RADII[ordinal][1])*length*local.y,2.0)))
	var separation: float=supports[0]+supports[1]+1.5*wall
	var rows: Array=[]
	for ordinal: int in range(2):
		var sign_value: float=-1.0 if ordinal==0 else 1.0
		var offset: Vector2=Vector2(0.025*length,0.0)+sign_value*0.5*separation*direction
		var rotation: Vector3=(basis*Basis(Vector3.BACK,ROLLS[ordinal])).get_euler()
		var consumed: Basis=Basis.from_euler(rotation)
		if not rotation.is_finite() or not consumed.is_finite() or consumed.determinant()<=0.0:return {"error":"219 invalid consumed cavity basis."}
		rows.append({"role":ROLES[ordinal],"node_id":IDS[ordinal],"feature_id":FEATURES[ordinal],"offset_m":[offset.x,offset.y],"radii_m":[float(RADII[ordinal][0])*length,float(RADII[ordinal][1])*length,float(RADII[ordinal][2])*length],"roll_radians":ROLLS[ordinal],"rotation":arr(rotation)})
	return {"ok":true,"frame":{"origin":arr(origin),"tangent":arr(tangent),"bitangent":arr(bitangent),"normal":arr(normal),"length":length},"reference_cell_m":H,"feature_radius_m":feature_floor,"wall_m":wall,"territory_half_extents_m":[0.85*length,0.75*length],"pair_separation_m":separation,"cavities":rows}


static func _basis_ok(basis: Basis)->bool:
	return basis.is_finite() and basis.x.length_squared()>0.0 and basis.y.length_squared()>0.0 and basis.z.length_squared()>0.0 and basis.determinant()>0.0 and basis.is_equal_approx(basis.orthonormalized())

## Pure arithmetic only. The six inputs are not certified field observations here.
## The center is a planning-ray crossing, never relabeled a normal-ray crossing.
static func local_frame(frame: Dictionary,row: Dictionary,surface_hit: Array,normal_values: Array)->Dictionary:
	for key: String in ["origin","tangent","bitangent","normal"]:
		if not vector(frame.get(key),3):return _bad("invalid planning frame input to local frame.")
	if not vector(row.get("rotation"),3) or not vector(row.get("radii_m"),3) or not number(row.get("roll_radians")) or not vector(surface_hit,3) or not vector(normal_values,6):return _bad("invalid local-frame input schema.")
	var planning_basis: Basis=Basis.from_euler(vec(row.rotation))
	if not _basis_ok(planning_basis):return _bad("invalid original consumed planning basis.")
	var planning_axis: Vector3=planning_basis.z
	var gradient: Vector3=Vector3(float(normal_values[0])-float(normal_values[1]),float(normal_values[2])-float(normal_values[3]),float(normal_values[4])-float(normal_values[5]))
	if not gradient.is_finite() or gradient.length_squared()<=0.0:return _bad("zero or nonfinite F0 finite-difference gradient; no fallback.")
	var normal: Vector3=gradient.normalized()
	var alignment: float=normal.dot(planning_axis)
	if not is_finite(alignment) or alignment<0.72:return _bad("original planning-axis alignment below0.72; no realignment retry.")
	var planning_tangent: Vector3=vec(frame.tangent)
	var tangent: Vector3=planning_tangent-normal*planning_tangent.dot(normal)
	if not tangent.is_finite() or tangent.length_squared()<=0.0:return _bad("zero or nonfinite projected territory tangent; no alternate axis.")
	tangent=tangent.normalized()
	var bitangent: Vector3=normal.cross(tangent)
	var local_basis: Basis=Basis(tangent,bitangent,normal)
	if not _basis_ok(local_basis):return _bad("invalid local-frame orthonormality or handedness.")
	var intended: Basis=local_basis*Basis(Vector3.BACK,float(row.roll_radians))
	var rotation: Vector3=intended.get_euler()
	var consumed: Basis=Basis.from_euler(rotation)
	if not rotation.is_finite() or not _basis_ok(consumed) or not consumed.is_equal_approx(intended):return _bad("failed consumed Euler reconstruction; no alternate axis.")
	var center: Vector3=vec(surface_hit)-0.48*float(row.radii_m[2])*consumed.z
	if not center.is_finite():return _bad("nonfinite normal-buried center.")
	var provenance: Dictionary={"version":1,"method":"fixed219_host_normal_frame_v1","planning_rotation":row.rotation.duplicate(),"planning_axis":arr(planning_axis),"surface_hit":surface_hit.duplicate(),"normal_epsilon_m":maxf(0.35*H,0.001),"normal_values":normal_values.duplicate(),"normal_direction":arr(normal),"planning_axis_dot":alignment,"projected_tangent":arr(tangent),"local_bitangent":arr(bitangent),"rotation":arr(rotation),"consumed_basis":{"x":arr(consumed.x),"y":arr(consumed.y),"z":arr(consumed.z)},"consumed_normal":arr(consumed.z),"center":arr(center),"center_projection_role":"first_crossing_along_planning_axis","center_normal_role":"cached_F0_six_value_witness","finite_sampling_only":true}
	return {"ok":true,"local_frame":provenance}

static func local_frame_ok(value: Variant)->bool:
	if not keys_are(value,LOCAL_FRAME_KEYS) or not integral(value.version) or float(value.version)!=1.0 or not text_is(value.method,"fixed219_host_normal_frame_v1"):return false
	if not text_is(value.center_projection_role,"first_crossing_along_planning_axis") or not text_is(value.center_normal_role,"cached_F0_six_value_witness") or not value.finite_sampling_only is bool or not value.finite_sampling_only:return false
	for key: String in ["planning_rotation","planning_axis","surface_hit","normal_direction","projected_tangent","local_bitangent","rotation","consumed_normal","center"]:
		if not vector(value[key],3):return false
	if not vector(value.normal_values,6) or not number(value.normal_epsilon_m) or not shadow_same(value.normal_epsilon_m,maxf(0.35*H,0.001)) or not number(value.planning_axis_dot) or float(value.planning_axis_dot)<0.72:return false
	if not keys_are(value.consumed_basis,["x","y","z"]):return false
	for axis: String in ["x","y","z"]:
		if not vector(value.consumed_basis[axis],3):return false
	var basis: Basis=Basis(vec(value.consumed_basis.x),vec(value.consumed_basis.y),vec(value.consumed_basis.z))
	if not _basis_ok(basis) or not same(value.consumed_normal,value.consumed_basis.z):return false
	return true

static func context_ok(value: Variant)->bool:
	if not keys_are(value,CONTEXT_KEYS):return false
	if not integral(value.version) or float(value.version)!=2.0 or not integral(value.partial_stage) or float(value.partial_stage)!=5.0:return false
	if not text_is(value.mode,MODE) or not text_is(value.spec_sha256,PIN) or not text_is(value.coordinate_space,"grounded_geometry_input") or not text_is(value.carrier_feature_id,"blob.body.core"):return false
	if not value.positive_node_ids is Array or value.positive_node_ids.size()!=13 or not value.cavity_node_ids is Array or value.cavity_node_ids!=IDS:return false
	for i: int in range(13):
		if not text_is(value.positive_node_ids[i],"n%03d"%i):return false
	if not integral(value.author_complete_field_calls) or float(value.author_complete_field_calls)<2.0 or float(value.author_complete_field_calls)>170.0:return false
	if not integral(value.author_projection_field_calls) or float(value.author_projection_field_calls)<2.0 or float(value.author_projection_field_calls)>158.0 or not integral(value.author_normal_field_calls) or float(value.author_normal_field_calls)!=12.0 or float(value.author_complete_field_calls)!=float(value.author_projection_field_calls)+float(value.author_normal_field_calls):return false
	if not keys_are(value.frame,["origin","tangent","bitangent","normal","length"]):return false
	for key: String in ["origin","tangent","bitangent","normal"]:
		if not vector(value.frame[key],3):return false
	if not number(value.frame.length) or float(value.frame.length)<=0.0:return false
	for key: String in ["reference_cell_m","feature_radius_m","wall_m","pair_separation_m"]:
		if not number(value[key]) or float(value[key])<=0.0:return false
	if not vector(value.territory_half_extents_m,2) or not value.cavities is Array or value.cavities.size()!=2:return false
	for i: int in range(2):
		var row: Variant=value.cavities[i]
		if not keys_are(row,ROW_KEYS) or not text_is(row.role,ROLES[i]) or not text_is(row.node_id,IDS[i]) or not text_is(row.feature_id,FEATURES[i]) or not number(row.roll_radians):return false
		if not vector(row.offset_m,2):return false
		for key: String in ["radii_m","rotation","surface_hit","center"]:
			if not vector(row[key],3):return false
		if not local_frame_ok(row.local_frame):return false
		for key: String in ["rotation","surface_hit","center"]:
			if not same(row[key],row.local_frame[key]):return false
		for radius: Variant in row.radii_m:
			if float(radius)<=0.0:return false
	return true

static func _bad(message: String)->Dictionary:return {"ok":false,"error":"219 "+message}
static func validate_declaration(dna: Dictionary)->Dictionary:
	var settings: Variant=dna.get("settings",{})
	if not settings is Dictionary:return _bad("settings must be a dictionary.")
	var choice: Dictionary=selection(settings)
	if choice.has("error"):return _bad(choice.error)
	var nodes: Variant=dna.get("nodes",[])
	if not nodes is Array:return _bad("nodes must be an array.")
	if choice.mode==OFF:
		for node: Variant in nodes:
			if node is Dictionary and node.has(KEY):return _bad("inactive marker is forbidden.")
		var inactive_metadata: Variant=dna.get("metadata")
		if inactive_metadata is Dictionary and inactive_metadata.has(KEY):return _bad("inactive context is forbidden.")
		return {"ok":true}
	if not text_is(settings.get(PIN_SETTING),PIN) or not text_is(dna.get("type"),"Blob") or not integral(dna.get("seed")) or float(dna.seed)!=22.0:return _bad("fixed Blob22 mode/pin is required.")
	var metadata: Variant=dna.get("metadata")
	if not metadata is Dictionary or not integral(metadata.get("iteration_index")) or float(metadata.iteration_index)!=5.0 or nodes.size()!=15:return _bad("requires exactly thirteen positive carriers and two Stage5 voids.")
	var connections: Variant=dna.get("connections")
	if not connections is Array or connections.size()!=14:return _bad("requires the unchanged twelve links and exact two owned-void suffix links.")
	for i: int in range(2):
		var connection: Variant=connections[12+i]
		if not keys_are(connection,["from","to","kind","blend"]) or not text_is(connection.from,"n000") or not text_is(connection.to,IDS[i]) or not text_is(connection.kind,"growth") or not number(connection.blend):return _bad("unexpected owned-void parent connection.")
	for key: String in ["modules","direct_surface_carriers"]:
		var values: Variant=dna.get(key,[])
		if not values is Array or not values.is_empty():return _bad("modules and direct layers remain disabled.")
	for i: int in range(13):
		var positive: Variant=nodes[i]
		if not positive is Dictionary or not text_is(positive.get("id"),"n%03d"%i) or positive.has(KEY) or not text_is(positive.get("operation","union"),"union"):return _bad("positive prefix or order changed.")
	var context: Variant=nodes[13].get(KEY) if nodes[13] is Dictionary else null
	if not context_ok(context):return _bad("requires a typed finite fixed context, not an arbitrary dictionary.")
	if not shadow_same(metadata.get(KEY),context):return _bad("metadata context disagrees with the consumed declaration.")
	for i: int in range(2):
		var node: Variant=nodes[13+i]
		var row: Dictionary=context.cavities[i]
		if not node is Dictionary or not same(node.get(KEY),context):return _bad("both voids require the same consumed context.")
		for pair: Array in [["id",IDS[i]],["feature_id",FEATURES[i]],["parent","n000"],["kind","cavity"],["role","cavity"],["operation","subtract"],["material","muscle"],["blob_region","mantle_blind_chamber"],["source","fixed219_surface_normal_blind_chambers_v1"]]:
			if not text_is(node.get(str(pair[0])),str(pair[1])):return _bad("unexpected void identity or operation.")
		for key: String in ["bone","surface_opening"]:
			if not node.get(key) is bool or node[key]:return _bad("void must not create a bone or auto-reseat its mouth.")
		if not same(node.get("position"),row.center) or not same(node.get("size"),row.radii_m) or not same(node.get("rotation"),row.rotation):return _bad("consumed cavity geometry disagrees with its fixed declaration.")
		if not same(connections[12+i].blend,node.get("blend")):return _bad("owned-void connection blend differs from the cutter.")
		if not vector(node.get("normal"),3) or not number(node.get("radius")) or not number(node.get("noise")) or float(node.noise)!=0.0 or not number(node.get("blend")) or float(node.blend)<=0.0:return _bad("invalid cavity scalar operations.")
		if not node.get("deformation") is Dictionary or not node.deformation.is_empty() or node.has("contained_lip") or node.has("cavity_id") or node.has("porous_patch") or not node.get("points",[]) is Array or not node.get("points",[]).is_empty() or not node.get("radii",[]) is Array or not node.get("radii",[]).is_empty() or not node.get("shape",{}) is Dictionary or not node.get("shape",{}).is_empty():return _bad("unsupported extra cavity operation.")
		var pending: Variant=node.get("porous_growth")
		if not keys_are(pending,["minimum_wall","host_thickness","complete_rim","back_wall","containment_method","burial_ratio","metrics_space"]) or not text_is(pending.get("containment_method"),"fixed219_finite_pending") or not pending.get("complete_rim") is bool or pending.complete_rim or not pending.get("back_wall") is bool or pending.back_wall:return _bad("authored metadata must not pretend to be geometric qualification.")
	# Existing positive validators and the exact numeric codec run separately.
	# Do not compute a cache key here: that would recurse through recipe decoding.
	return {"ok":true}

static func validate_restored(dna: Dictionary)->Dictionary:
	var declaration: Dictionary=validate_declaration(dna)
	if not declaration.ok or not enabled(dna):return declaration
	var context: Dictionary=dna.nodes[13][KEY]
	if not context.version is int or not context.partial_stage is int or not context.author_complete_field_calls is int or not context.author_projection_field_calls is int or not context.author_normal_field_calls is int:return _bad("restored declaration integral tags must retain their types.")
	var expected: Dictionary=frame_table(dna)
	if expected.has("error"):return _bad(expected.error)
	for key: String in ["frame","reference_cell_m","feature_radius_m","wall_m","territory_half_extents_m","pair_separation_m"]:
		if not same(context[key],expected[key]):return _bad("restored fixed frame/table scalar bits differ: "+key)
	for i: int in range(2):
		var row: Dictionary=context.cavities[i]
		var expected_row: Dictionary=expected.cavities[i]
		for key: String in expected_row:
			if key=="rotation":continue
			if not same(row[key],expected_row[key]):return _bad("restored cavity table differs: "+key)
		if not row.local_frame.version is int or not row.local_frame.normal_epsilon_m is float or not row.local_frame.planning_axis_dot is float:return _bad("restored local frame scalar types differ.")
		for value: Variant in row.local_frame.normal_values:
			if not value is float:return _bad("restored center normal values must preserve float types.")
		var reconstructed: Dictionary=local_frame(expected.frame,expected_row,row.surface_hit,row.local_frame.normal_values)
		if not reconstructed.get("ok",false) or not same(row.local_frame,reconstructed.get("local_frame")):return _bad("restored local frame/provenance differs from exact reconstruction.")
		for key: String in ["surface_hit","center"]:
			for value: Variant in row[key]:
				if not value is float:return _bad("restored spatial components must preserve float types.")
		var basis: Basis=Basis.from_euler(vec(row.rotation))
		var center: Vector3=vec(row.surface_hit)-0.48*float(row.radii_m[2])*basis.z
		if not same(row.center,arr(center)) or not same(dna.nodes[13+i].get("normal"),arr(basis.z)):return _bad("center/basis relationship differs.")
		if not same(dna.nodes[13+i].noise,0.0) or not same(dna.nodes[13+i].radius,row.radii_m[0]):return _bad("restored noise/radius must preserve exact float values.")
		if not same(dna.nodes[13+i].blend,0.025*float(context.frame.length)):return _bad("unchanged cutter blend differs.")
		var pending: Dictionary=dna.nodes[13+i].porous_growth
		if not same(pending.get("minimum_wall"),context.wall_m) or not same(pending.get("host_thickness"),0.0) or not same(pending.get("burial_ratio"),0.48) or not text_is(pending.get("metrics_space"),"grounded_geometry_input"):return _bad("pending cavity metadata differs.")
	var blueprint: Variant=dna.get("biological_blueprint")
	if not blueprint is Dictionary or not blueprint.get("features") is Array:return _bad("missing cavity feature intentions.")
	for i: int in range(2):
		var found: Array=[]
		for feature: Variant in blueprint.features:
			if feature is Dictionary and feature.get("id")==FEATURES[i]:found.append(feature)
		if found.size()!=1:return _bad("requires each exact cavity feature intention once.")
		var feature: Dictionary=found[0]
		var row: Dictionary=context.cavities[i]
		var expected_recipe: Dictionary={"version":2,"mode":MODE,"spec_sha256":PIN,"role":ROLES[i],"parent_node_id":"n000","carrier_feature_id":"blob.body.core","radii_over_L":RADII[i].duplicate(),"roll_radians":ROLLS[i]}
		if not shadow_same(feature.get("geometry_recipe"),expected_recipe) or not shadow_same(feature.get("growth_direction"),arr(vec(row.local_frame.consumed_normal).normalized())):return _bad("cavity intention recipe/direction disagrees with consumed local frame.")
	var artifacts: GDScript=load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	var positive: Dictionary=positive_projection(dna)
	if artifacts.geometry_key(positive,5,DEPENDENCY4)!=BASELINE_KEY:return _bad("positive consumed215 geometry/key changed.")
	return {"ok":true}
