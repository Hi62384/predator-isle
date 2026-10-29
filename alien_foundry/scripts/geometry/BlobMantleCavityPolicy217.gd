extends RefCounted
##217 explicit two-void suffix. Declaration checks are not geometric safety.
## The thirteen positive carriers and their consumed215 identity stay exact.
const SETTING: String="blob_mantle_cavity_mode"
const PIN_SETTING: String="blob_mantle_cavity_pin217"
const MODE: String="mantle_blind_chambers_v1"
const OFF: String="off"
const PIN: String="ba2873111f4b8f37da787854a66d19cb71bcd437ea891ccdd49f695bb3e9c6cb"
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
const CONTEXT_KEYS: Array[String]=["version","mode","spec_sha256","coordinate_space","partial_stage","positive_node_ids","cavity_node_ids","carrier_feature_id","frame","reference_cell_m","feature_radius_m","wall_m","territory_half_extents_m","pair_separation_m","cavities","author_complete_field_calls"]
const ROW_KEYS: Array[String]=["role","node_id","feature_id","offset_m","radii_m","roll_radians","rotation","surface_hit","center"]

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
	if not mode is String or mode not in [OFF,MODE]:return {"error":"217 cavity selector must be an explicit supported string."}
	if options.has(PIN_SETTING) and (mode==OFF or not text_is(options.get(PIN_SETTING),PIN)):return {"error":"217 inactive or stale cavity pin."}
	if mode==OFF:return {"mode":OFF}
	for key: String in PREREQUISITES:
		if not text_is(options.get(key),str(PREREQUISITES[key])):return {"error":"217 missing explicit prerequisite: "+key}
	for pair: Array in [["quality",1.0],["size",1.0],["surface_detail",0.55]]:
		var value: Variant=options.get(str(pair[0]),pair[1])
		if not number(value) or float(value)!=float(pair[1]):return {"error":"217 requires fixed Standard/size1/detail0.55."}
	if not options.get("secondary_enabled",true) is bool or options.get("secondary_enabled",true):return {"error":"217 secondary anatomy remains disabled."}
	if not text_is(options.get("blob_direct_surface_profile",OFF),OFF):return {"error":"217 direct layers remain disabled."}
	var operations: Variant=options.get("surface_operations",[])
	if not operations is Array or not operations.is_empty():return {"error":"217 does not enable the legacy surface-operations dispatcher."}
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

static func frame_table(dna: Dictionary)->Dictionary:
	var nodes: Variant=dna.get("nodes")
	if not nodes is Array or nodes.is_empty() or not nodes[0] is Dictionary:return {"error":"217 missing restored core."}
	var node: Dictionary=nodes[0]
	if not text_is(node.get("id"),"n000") or not text_is(node.get("feature_id"),"blob.body.core"):return {"error":"217 requires the original core owner."}
	var shape: Variant=node.get("shape",{})
	if not shape is Dictionary:return {"error":"217 malformed core shape."}
	var mass: Variant=shape.get("mass_reprofile203",{})
	if not mass is Dictionary or not mass.get("base_group") is Dictionary or not mass.base_group.get("host") is Dictionary:return {"error":"217 missing203 host frame."}
	var source: Variant=mass.base_group.host.get("frame")
	if not source is Dictionary or not number(source.get("length")) or float(source.length)<=0.0:return {"error":"217 invalid host length."}
	for key: String in ["origin","n","u","v"]:
		if not vector(source.get(key),3):return {"error":"217 invalid host frame."}
	var length: float=float(source.length)
	var n: Vector3=vec(source.n);var u: Vector3=vec(source.u);var v: Vector3=vec(source.v)
	var origin: Vector3=vec(source.origin)+0.05*length*v
	var normal: Vector3=-n-0.45*u+0.10*v
	if not normal.is_finite() or normal.length_squared()==0.0:return {"error":"217 degenerate normal."}
	normal=normal.normalized()
	var tangent: Vector3=-u-normal*(-u).dot(normal)
	if not tangent.is_finite() or tangent.length_squared()==0.0:return {"error":"217 degenerate tangent."}
	tangent=tangent.normalized()
	var bitangent: Vector3=normal.cross(tangent).normalized()
	var basis: Basis=Basis(tangent,bitangent,normal)
	if not bitangent.is_finite() or basis.determinant()<=0.0:return {"error":"217 invalid handedness."}
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
		if not rotation.is_finite() or not consumed.is_finite() or consumed.determinant()<=0.0:return {"error":"217 invalid consumed cavity basis."}
		rows.append({"role":ROLES[ordinal],"node_id":IDS[ordinal],"feature_id":FEATURES[ordinal],"offset_m":[offset.x,offset.y],"radii_m":[float(RADII[ordinal][0])*length,float(RADII[ordinal][1])*length,float(RADII[ordinal][2])*length],"roll_radians":ROLLS[ordinal],"rotation":arr(rotation)})
	return {"ok":true,"frame":{"origin":arr(origin),"tangent":arr(tangent),"bitangent":arr(bitangent),"normal":arr(normal),"length":length},"reference_cell_m":H,"feature_radius_m":feature_floor,"wall_m":wall,"territory_half_extents_m":[0.85*length,0.75*length],"pair_separation_m":separation,"cavities":rows}

static func context_ok(value: Variant)->bool:
	if not keys_are(value,CONTEXT_KEYS):return false
	if not integral(value.version) or float(value.version)!=1.0 or not integral(value.partial_stage) or float(value.partial_stage)!=5.0:return false
	if not text_is(value.mode,MODE) or not text_is(value.spec_sha256,PIN) or not text_is(value.coordinate_space,"grounded_geometry_input") or not text_is(value.carrier_feature_id,"blob.body.core"):return false
	if not value.positive_node_ids is Array or value.positive_node_ids.size()!=13 or not value.cavity_node_ids is Array or value.cavity_node_ids!=IDS:return false
	for i: int in range(13):
		if not text_is(value.positive_node_ids[i],"n%03d"%i):return false
	if not integral(value.author_complete_field_calls) or float(value.author_complete_field_calls)<2.0 or float(value.author_complete_field_calls)>158.0:return false
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
		for radius: Variant in row.radii_m:
			if float(radius)<=0.0:return false
	return true

static func _bad(message: String)->Dictionary:return {"ok":false,"error":"217 "+message}
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
		for pair: Array in [["id",IDS[i]],["feature_id",FEATURES[i]],["parent","n000"],["kind","cavity"],["role","cavity"],["operation","subtract"],["material","muscle"],["blob_region","mantle_blind_chamber"],["source","fixed217_mantle_blind_chambers_v1"]]:
			if not text_is(node.get(str(pair[0])),str(pair[1])):return _bad("unexpected void identity or operation.")
		for key: String in ["bone","surface_opening"]:
			if not node.get(key) is bool or node[key]:return _bad("void must not create a bone or auto-reseat its mouth.")
		if not same(node.get("position"),row.center) or not same(node.get("size"),row.radii_m) or not same(node.get("rotation"),row.rotation):return _bad("consumed cavity geometry disagrees with its fixed declaration.")
		if not same(connections[12+i].blend,node.get("blend")):return _bad("owned-void connection blend differs from the cutter.")
		if not vector(node.get("normal"),3) or not number(node.get("radius")) or not number(node.get("noise")) or float(node.noise)!=0.0 or not number(node.get("blend")) or float(node.blend)<=0.0:return _bad("invalid cavity scalar operations.")
		if not node.get("deformation") is Dictionary or not node.deformation.is_empty() or node.has("contained_lip") or node.has("cavity_id") or node.has("porous_patch") or not node.get("points",[]) is Array or not node.get("points",[]).is_empty() or not node.get("radii",[]) is Array or not node.get("radii",[]).is_empty() or not node.get("shape",{}) is Dictionary or not node.get("shape",{}).is_empty():return _bad("unsupported extra cavity operation.")
		var pending: Variant=node.get("porous_growth")
		if not keys_are(pending,["minimum_wall","host_thickness","complete_rim","back_wall","containment_method","burial_ratio","metrics_space"]) or not text_is(pending.get("containment_method"),"fixed217_finite_pending") or not pending.get("complete_rim") is bool or pending.complete_rim or not pending.get("back_wall") is bool or pending.back_wall:return _bad("authored metadata must not pretend to be geometric qualification.")
	# Existing positive validators and the exact numeric codec run separately.
	# Do not compute a cache key here: that would recurse through recipe decoding.
	return {"ok":true}

static func validate_restored(dna: Dictionary)->Dictionary:
	var declaration: Dictionary=validate_declaration(dna)
	if not declaration.ok or not enabled(dna):return declaration
	var context: Dictionary=dna.nodes[13][KEY]
	if not context.version is int or not context.partial_stage is int or not context.author_complete_field_calls is int:return _bad("restored declaration integral tags must retain their types.")
	var expected: Dictionary=frame_table(dna)
	if expected.has("error"):return _bad(expected.error)
	for key: String in ["frame","reference_cell_m","feature_radius_m","wall_m","territory_half_extents_m","pair_separation_m"]:
		if not same(context[key],expected[key]):return _bad("restored fixed frame/table scalar bits differ: "+key)
	for i: int in range(2):
		var row: Dictionary=context.cavities[i]
		var expected_row: Dictionary=expected.cavities[i]
		for key: String in expected_row:
			if not same(row[key],expected_row[key]):return _bad("restored cavity table differs: "+key)
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
	var artifacts: GDScript=load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	var positive: Dictionary=positive_projection(dna)
	if artifacts.geometry_key(positive,5,DEPENDENCY4)!=BASELINE_KEY:return _bad("positive consumed215 geometry/key changed.")
	return {"ok":true}
