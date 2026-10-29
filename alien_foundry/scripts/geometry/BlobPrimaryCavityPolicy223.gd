extends RefCounted
const HighPreview2=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const HighPreview=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
## 223 explicit SINGLE-primary-chamber anatomy-aware selector.
## Pure policy and declaration reconstruction, never geometric qualification.
## Exactly thirteen unchanged215 positive carriers and one selected n013 void.
const SETTING: String="blob_mantle_cavity_mode"
const PIN_SETTING: String="blob_mantle_cavity_pin217"
const MODE: String="territory_primary_blind_chamber_v1"
const OFF: String="off"
const PIN: String="d601192b5f21a5a48e47ea2e579f46940cd3285dafaf7d503487acf6fd6b700c"
const KEY: String="mantle_cavities217"
const H: float=0.06132264835698207
const BASELINE_KEY: String="507ba7f69124c1aba8440c160e912dfd00b76f149ced40e51ca906fde57861d6"
const DEPENDENCY4: String="cf33780f55a7d8b0f8a6aa98f7eefdcc573cfe076bedd250e2ebda5cffadb464"
const IDS: Array[String]=["n013"]
const FEATURES: Array[String]=["blob.cavity.mantle_rear.primary"]
const ROLES: Array[String]=["primary"]
const RADII: Array=[[0.185,0.300,0.520]]
const ROLLS: Array[float]=[1.15]
const POOL_LAW_VERSION: int=1
const POOL_SIZE: int=13
const MAX_SHORTLIST: int=3
const PREREQUISITES: Dictionary={"blob_pipeline_mode":"iterative_v2","blob_identity_profile":"positive_sacs_v1","blob_positive_growth_mode":"positive_sacs_only_v1","blob_sac_surface_mode":"central_keel_pleat_v1","blob_isosurface_grid_mode":"conflict_slabs_v1","blob_isosurface_normal_mode":"adaptive_field_gradient_v2","blob_isosurface_refinement_mode":"bracketed_field_edges_v1"}
const FRAME_KEYS: Array[String]=["origin","tangent","bitangent","normal","length"]
const CONTEXT_KEYS: Array[String]=["version","mode","spec_sha256","coordinate_space","partial_stage","positive_node_ids","cavity_node_ids","carrier_feature_id","frame","reference_cell_m","feature_radius_m","wall_m","territory_half_extents_m","cavities","author_complete_field_calls","author_projection_field_calls","author_normal_field_calls","selection_decision"]
const SITE_KEYS: Array[String]=["site_id","radius_fraction","angle_index","angle_denominator","role","node_id","feature_id","offset_m","nominal","projection_axis","radii_m","roll_radians","rotation"]
const ROW_KEYS: Array[String]=["site_id","radius_fraction","angle_index","angle_denominator","role","node_id","feature_id","offset_m","nominal","projection_axis","radii_m","roll_radians","rotation","surface_hit","center","local_frame"]
const LOCAL_FRAME_KEYS: Array[String]=["version","method","site_id","planning_rotation","projection_axis","surface_hit","normal_epsilon_m","normal_values","normal_direction","projection_axis_dot","projected_tangent","local_bitangent","rotation","consumed_basis","consumed_normal","center","center_projection_role","center_normal_role","finite_sampling_only"]
const DECISION_KEYS: Array[String]=["version","method","pool_law_version","pool_size","screened_sites","eligible_sites","shortlist_site_ids","shortlist_scores","shortlist_ranks","trial_count","selected_rank","selected_site_id","policy_sha256","positive_input_key","finite_sampling_only","global_optimum"]

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
	if not mode is String or mode not in [OFF,MODE]:return {"error":"223 cavity selector must be an explicit supported string."}
	if options.has(PIN_SETTING) and (mode==OFF or not text_is(options.get(PIN_SETTING),PIN)):return {"error":"223 inactive or stale cavity pin."}
	if mode==OFF:return {"mode":OFF}
	for key: String in PREREQUISITES:
		if not text_is(options.get(key),str(PREREQUISITES[key])):return {"error":"223 missing explicit prerequisite: "+key}
	for pair: Array in [["quality",1.0],["size",1.0],["surface_detail",0.55]]:
		var value: Variant=options.get(str(pair[0]),pair[1])
		if not number(value) or float(value)!=float(pair[1]):return {"error":"223 requires fixed Standard/size1/detail0.55."}
	if not options.get("secondary_enabled",true) is bool or options.get("secondary_enabled",true):return {"error":"223 secondary anatomy remains disabled."}
	if not text_is(options.get("blob_direct_surface_profile",OFF),OFF):return {"error":"223 direct layers remain disabled."}
	var operations: Variant=options.get("surface_operations",[])
	if not operations is Array or not operations.is_empty():return {"error":"223 does not enable the legacy surface-operations dispatcher."}
	return {"mode":MODE}

static func positive_projection(dna: Dictionary)->Dictionary:
	#224 budget changes extraction only; the positive-field215 identity stays exact.
	var preview2: Dictionary=HighPreview2.field_projection(dna) if HighPreview2.enabled(dna) else dna
	if preview2.has("error"):return preview2
	var result: Dictionary=HighPreview.field_projection(preview2) if HighPreview.enabled(preview2) else preview2.duplicate(true)
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
				if text_is(entry.path[0],"nodes") and int(entry.path[1])>=13:continue
				if text_is(entry.path[0],"connections") and int(entry.path[1])>=12:continue
			entries.append(entry)
		result.geometry_numeric_recipe.numbers=entries
	return result

## Original219 core-owned planning frame arithmetic remains in the same order.
## The pair separation/offset law is deliberately absent from this new mode.
static func frame_table(dna: Dictionary)->Dictionary:
	var nodes: Variant=dna.get("nodes")
	if not nodes is Array or nodes.is_empty() or not nodes[0] is Dictionary:return _bad("missing restored core.")
	var node: Dictionary=nodes[0]
	if not text_is(node.get("id"),"n000") or not text_is(node.get("feature_id"),"blob.body.core"):return _bad("requires the original core owner.")
	var shape: Variant=node.get("shape",{})
	if not shape is Dictionary:return _bad("malformed core shape.")
	var mass: Variant=shape.get("mass_reprofile203",{})
	if not mass is Dictionary or not mass.get("base_group") is Dictionary or not mass.base_group.get("host") is Dictionary:return _bad("missing203 host frame.")
	var source: Variant=mass.base_group.host.get("frame")
	if not source is Dictionary or not number(source.get("length")) or float(source.length)<=0.0:return _bad("invalid host length.")
	for key: String in ["origin","n","u","v"]:
		if not vector(source.get(key),3):return _bad("invalid host frame.")
	var length: float=float(source.length)
	var n: Vector3=vec(source.n);var u: Vector3=vec(source.u);var v: Vector3=vec(source.v)
	var origin: Vector3=vec(source.origin)+0.05*length*v
	var normal: Vector3=-n-0.45*u+0.10*v
	if not normal.is_finite() or normal.length_squared()==0.0:return _bad("degenerate chart normal.")
	normal=normal.normalized()
	var tangent: Vector3=-u-normal*(-u).dot(normal)
	if not tangent.is_finite() or tangent.length_squared()==0.0:return _bad("degenerate chart tangent.")
	tangent=tangent.normalized()
	var bitangent: Vector3=normal.cross(tangent).normalized()
	var basis: Basis=Basis(tangent,bitangent,normal)
	if not bitangent.is_finite() or basis.determinant()<=0.0:return _bad("invalid chart handedness.")
	var feature_floor: float=maxf(0.075*length,1.8*H)
	var wall: float=maxf(0.075*length,maxf(0.85*feature_floor,1.45*H))
	var frame: Dictionary={"origin":arr(origin),"tangent":arr(tangent),"bitangent":arr(bitangent),"normal":arr(normal),"length":length}
	var sites: Array=[]
	for site_id: int in range(POOL_SIZE):
		var site: Dictionary=site_row(frame,site_id)
		if site.has("error"):return site
		sites.append(site)
	return {"ok":true,"frame":frame,"reference_cell_m":H,"feature_radius_m":feature_floor,"wall_m":wall,"territory_half_extents_m":[0.85*length,0.75*length],"sites":sites}

static func _basis_ok(basis: Basis)->bool:
	return basis.is_finite() and basis.x.length_squared()>0.0 and basis.y.length_squared()>0.0 and basis.z.length_squared()>0.0 and basis.determinant()>0.0 and basis.is_equal_approx(basis.orthonormalized())

static func _frame_ok(value: Variant)->bool:
	if not keys_are(value,FRAME_KEYS) or not number(value.length) or float(value.length)<=0.0:return false
	for key: String in ["origin","tangent","bitangent","normal"]:
		if not vector(value[key],3):return false
	return _basis_ok(Basis(vec(value.tangent),vec(value.bitangent),vec(value.normal)))

## Fixed finite13 chart law. No field, site retry, fitting, or pair offset.
static func site_row(frame: Dictionary,site_id: int)->Dictionary:
	if not _frame_ok(frame) or site_id<0 or site_id>=POOL_SIZE:return _bad("invalid chart/site input.")
	var radius_fraction: float=0.0
	var angle_index: int=0
	var angle_denominator: int=1
	if site_id>=1 and site_id<=8:
		radius_fraction=0.35;angle_index=site_id-1;angle_denominator=8
	elif site_id>=9:
		radius_fraction=0.70;angle_index=site_id-9;angle_denominator=4
	var theta: float=TAU*float(angle_index)/float(angle_denominator)
	var length: float=float(frame.length)
	var offset: Vector2=Vector2(0.85*length*radius_fraction*cos(theta),0.75*length*radius_fraction*sin(theta))
	var origin: Vector3=vec(frame.origin)
	var tangent: Vector3=vec(frame.tangent);var bitangent: Vector3=vec(frame.bitangent);var normal: Vector3=vec(frame.normal)
	var nominal: Vector3=origin+tangent*offset.x+bitangent*offset.y
	var basis: Basis=Basis(tangent,bitangent,normal)
	var intended: Basis=basis*Basis(Vector3.BACK,ROLLS[0])
	var rotation: Vector3=intended.get_euler()
	var consumed: Basis=Basis.from_euler(rotation)
	if not nominal.is_finite() or not offset.is_finite() or not rotation.is_finite() or not _basis_ok(consumed) or not consumed.is_equal_approx(intended):return _bad("invalid canonical site or planning Euler reconstruction.")
	return {"site_id":site_id,"radius_fraction":radius_fraction,"angle_index":angle_index,"angle_denominator":angle_denominator,"role":ROLES[0],"node_id":IDS[0],"feature_id":FEATURES[0],"offset_m":[offset.x,offset.y],"nominal":arr(nominal),"projection_axis":frame.normal.duplicate(),"radii_m":[float(RADII[0][0])*length,float(RADII[0][1])*length,float(RADII[0][2])*length],"roll_radians":ROLLS[0],"rotation":arr(rotation)}

static func selected_site(plan: Dictionary,site_id: int)->Dictionary:
	var frame: Variant=plan.get("frame")
	if not frame is Dictionary:return _bad("missing selected-site chart.")
	return site_row(frame,site_id)

## Pure arithmetic only. Inputs are retained witnesses, not field certificates.
## projection_axis is the ACTUAL shared chart normal used by the projection.
## planning_rotation is separate provenance; its reconstructed z is NOT the ray.
static func local_frame(frame: Dictionary,row: Dictionary,surface_hit: Array,normal_values: Array)->Dictionary:
	if not _frame_ok(frame) or not keys_are(row,SITE_KEYS):return _bad("invalid local-frame chart/site schema.")
	if not integral(row.site_id) or float(row.site_id)<0.0 or float(row.site_id)>=float(POOL_SIZE):return _bad("invalid local-frame site identity.")
	var canonical: Dictionary=site_row(frame,int(row.site_id))
	if canonical.has("error") or not same(row,canonical):return _bad("noncanonical local-frame planning site.")
	if not vector(surface_hit,3) or not vector(normal_values,6):return _bad("invalid local-frame witness schema.")
	var projection_axis: Vector3=vec(frame.normal)
	var gradient: Vector3=Vector3(float(normal_values[0])-float(normal_values[1]),float(normal_values[2])-float(normal_values[3]),float(normal_values[4])-float(normal_values[5]))
	if not gradient.is_finite() or gradient.length_squared()<=0.0:return _bad("zero or nonfinite F0 finite-difference gradient; no fallback.")
	var normal: Vector3=gradient.normalized()
	var alignment: float=normal.dot(projection_axis)
	if not is_finite(alignment) or alignment<0.72:return _bad("actual chart projection-axis alignment below0.72; no retry.")
	var planning_tangent: Vector3=vec(frame.tangent)
	var tangent: Vector3=planning_tangent-normal*planning_tangent.dot(normal)
	if not tangent.is_finite() or tangent.length_squared()<=0.0:return _bad("zero or nonfinite projected chart tangent; no alternate axis.")
	tangent=tangent.normalized()
	var bitangent: Vector3=normal.cross(tangent)
	var local_basis: Basis=Basis(tangent,bitangent,normal)
	if not _basis_ok(local_basis):return _bad("invalid local-frame orthonormality or handedness.")
	var intended: Basis=local_basis*Basis(Vector3.BACK,float(row.roll_radians))
	var rotation: Vector3=intended.get_euler()
	var consumed: Basis=Basis.from_euler(rotation)
	if not rotation.is_finite() or not _basis_ok(consumed) or not consumed.is_equal_approx(intended):return _bad("failed consumed Euler reconstruction; no alternate axis.")
	var center: Vector3=vec(surface_hit)-0.48*float(row.radii_m[2])*consumed.z
	if not center.is_finite():return _bad("nonfinite fixed normal-buried center.")
	var provenance: Dictionary={"version":1,"method":"fixed223_chart_ray_host_normal_frame_v1","site_id":int(row.site_id),"planning_rotation":row.rotation.duplicate(),"projection_axis":frame.normal.duplicate(),"surface_hit":surface_hit.duplicate(),"normal_epsilon_m":maxf(0.35*H,0.001),"normal_values":normal_values.duplicate(),"normal_direction":arr(normal),"projection_axis_dot":alignment,"projected_tangent":arr(tangent),"local_bitangent":arr(bitangent),"rotation":arr(rotation),"consumed_basis":{"x":arr(consumed.x),"y":arr(consumed.y),"z":arr(consumed.z)},"consumed_normal":arr(consumed.z),"center":arr(center),"center_projection_role":"first_crossing_along_actual_chart_normal","center_normal_role":"cached_F0_six_value_witness","finite_sampling_only":true}
	return {"ok":true,"local_frame":provenance}

## A finite F0 scalar ranking only. This is not metric wall distance or safety.
static func preliminary_score(center_owner: float,thickness: float,required_thickness: float,maximum_shell_scalar: float,wall: float)->Dictionary:
	for value: float in [center_owner,thickness,required_thickness,maximum_shell_scalar,wall]:
		if not is_finite(value):return _bad("nonfinite preliminary score operand.")
	if center_owner<0.70 or required_thickness<=0.0 or wall<=0.0 or thickness<required_thickness or maximum_shell_scalar>-0.35*wall:return _bad("preliminary score requires unchanged screen thresholds.")
	var owner_margin: float=(center_owner-0.70)/0.30
	var thickness_margin: float=thickness/required_thickness-1.0
	var shell_margin: float=(-maximum_shell_scalar-0.35*wall)/(0.35*wall)
	var score: float=minf(owner_margin,minf(thickness_margin,shell_margin))
	if not is_finite(score):return _bad("nonfinite preliminary score.")
	return {"ok":true,"score":score}

## Compact decision declaration; the report/cache, not this data, owns evidence.
static func selection_decision(ids: Array,scores: Array,eligible_count: int,selected_rank: int)->Dictionary:
	var ranks: Array=[]
	for index: int in range(ids.size()):ranks.append(index+1)
	var selected_id: int=-1
	if selected_rank>=1 and selected_rank<=ids.size() and integral(ids[selected_rank-1]):selected_id=int(ids[selected_rank-1])
	var decision: Dictionary={"version":1,"method":"finite13_first_valid_primary_v1","pool_law_version":POOL_LAW_VERSION,"pool_size":POOL_SIZE,"screened_sites":POOL_SIZE,"eligible_sites":eligible_count,"shortlist_site_ids":ids.duplicate(),"shortlist_scores":scores.duplicate(),"shortlist_ranks":ranks,"trial_count":selected_rank,"selected_rank":selected_rank,"selected_site_id":selected_id,"policy_sha256":PIN,"positive_input_key":BASELINE_KEY,"finite_sampling_only":true,"global_optimum":false}
	if not decision_ok(decision):return _bad("invalid bounded selected-site decision.")
	return {"ok":true,"decision":decision}

static func decision_ok(value: Variant)->bool:
	if not keys_are(value,DECISION_KEYS):return false
	for pair: Array in [["version",1],["pool_law_version",POOL_LAW_VERSION],["pool_size",POOL_SIZE],["screened_sites",POOL_SIZE]]:
		if not integral(value[pair[0]]) or float(value[pair[0]])!=float(pair[1]):return false
	if not text_is(value.method,"finite13_first_valid_primary_v1") or not text_is(value.policy_sha256,PIN) or not text_is(value.positive_input_key,BASELINE_KEY):return false
	if not value.finite_sampling_only is bool or not value.finite_sampling_only or not value.global_optimum is bool or value.global_optimum:return false
	if not integral(value.eligible_sites) or float(value.eligible_sites)<1.0 or float(value.eligible_sites)>float(POOL_SIZE):return false
	if not value.shortlist_site_ids is Array or not value.shortlist_scores is Array or not value.shortlist_ranks is Array:return false
	var count: int=value.shortlist_site_ids.size()
	if count!=mini(MAX_SHORTLIST,int(value.eligible_sites)) or value.shortlist_scores.size()!=count or value.shortlist_ranks.size()!=count:return false
	if not integral(value.selected_rank) or float(value.selected_rank)<1.0 or float(value.selected_rank)>float(count) or not integral(value.trial_count) or float(value.trial_count)!=float(value.selected_rank):return false
	if not integral(value.selected_site_id) or float(value.selected_site_id)<0.0 or float(value.selected_site_id)>=float(POOL_SIZE):return false
	var seen: Array=[]
	for index: int in range(count):
		var site_id: Variant=value.shortlist_site_ids[index]
		var score: Variant=value.shortlist_scores[index]
		var rank: Variant=value.shortlist_ranks[index]
		if not integral(site_id) or float(site_id)<0.0 or float(site_id)>=float(POOL_SIZE) or int(site_id) in seen or not number(score) or float(score)<0.0 or not integral(rank) or float(rank)!=float(index+1):return false
		seen.append(int(site_id))
		if index>0:
			var previous_score: float=float(value.shortlist_scores[index-1])
			var previous_id: int=int(value.shortlist_site_ids[index-1])
			if previous_score<float(score) or (previous_score==float(score) and previous_id>int(site_id)):return false
	return int(value.selected_site_id)==int(value.shortlist_site_ids[int(value.selected_rank)-1])

static func make_context(plan: Dictionary,row: Dictionary,local: Dictionary,decision: Dictionary,projection_calls: int)->Dictionary:
	if not plan.get("frame") is Dictionary or not decision_ok(decision) or not local_frame_ok(local):return _bad("invalid selected context inputs.")
	if not number(plan.get("feature_radius_m")) or not number(plan.get("wall_m")) or not vector(plan.get("territory_half_extents_m"),2) or projection_calls<2 or projection_calls>79:return _bad("invalid selected context scales/counters.")
	var expected: Dictionary=selected_site(plan,int(decision.selected_site_id))
	if expected.has("error") or not same(row,expected):return _bad("context selected site differs from fixed pool.")
	var rebuilt: Dictionary=local_frame(plan.frame,row,local.surface_hit,local.normal_values)
	if not rebuilt.get("ok",false) or not same(local,rebuilt.local_frame):return _bad("context local pose differs from reconstruction.")
	var saved: Dictionary=row.duplicate(true)
	for key: String in ["rotation","surface_hit","center"]:saved[key]=local[key].duplicate()
	saved["local_frame"]=local.duplicate(true)
	var positive_ids: Array=[]
	for index: int in range(13):positive_ids.append("n%03d"%index)
	var context: Dictionary={"version":4,"mode":MODE,"spec_sha256":PIN,"coordinate_space":"grounded_geometry_input","partial_stage":5,"positive_node_ids":positive_ids,"cavity_node_ids":IDS.duplicate(),"carrier_feature_id":"blob.body.core","frame":plan.frame.duplicate(true),"reference_cell_m":H,"feature_radius_m":plan.feature_radius_m,"wall_m":plan.wall_m,"territory_half_extents_m":plan.territory_half_extents_m.duplicate(),"cavities":[saved],"author_complete_field_calls":projection_calls+6,"author_projection_field_calls":projection_calls,"author_normal_field_calls":6,"selection_decision":decision.duplicate(true)}
	if not context_ok(context):return _bad("invalid selected context declaration.")
	return {"ok":true,"context":context}

static func local_frame_ok(value: Variant)->bool:
	if not keys_are(value,LOCAL_FRAME_KEYS) or not integral(value.version) or float(value.version)!=1.0 or not text_is(value.method,"fixed223_chart_ray_host_normal_frame_v1"):return false
	if not integral(value.site_id) or float(value.site_id)<0.0 or float(value.site_id)>=float(POOL_SIZE):return false
	if not text_is(value.center_projection_role,"first_crossing_along_actual_chart_normal") or not text_is(value.center_normal_role,"cached_F0_six_value_witness") or not value.finite_sampling_only is bool or not value.finite_sampling_only:return false
	for key: String in ["planning_rotation","projection_axis","surface_hit","normal_direction","projected_tangent","local_bitangent","rotation","consumed_normal","center"]:
		if not vector(value[key],3):return false
	if not vector(value.normal_values,6) or not number(value.normal_epsilon_m) or not shadow_same(value.normal_epsilon_m,maxf(0.35*H,0.001)) or not number(value.projection_axis_dot) or float(value.projection_axis_dot)<0.72:return false
	if not keys_are(value.consumed_basis,["x","y","z"]):return false
	for axis: String in ["x","y","z"]:
		if not vector(value.consumed_basis[axis],3):return false
	var basis: Basis=Basis(vec(value.consumed_basis.x),vec(value.consumed_basis.y),vec(value.consumed_basis.z))
	return _basis_ok(basis) and same(value.consumed_normal,value.consumed_basis.z)

## Closed finite raw schema permits only integral JSON shadows for int tags.
## The exact numeric codec and canonical reconstruction enforce bits below.
static func context_ok(value: Variant)->bool:
	if not keys_are(value,CONTEXT_KEYS):return false
	if not integral(value.version) or float(value.version)!=4.0 or not integral(value.partial_stage) or float(value.partial_stage)!=5.0:return false
	if not text_is(value.mode,MODE) or not text_is(value.spec_sha256,PIN) or not text_is(value.coordinate_space,"grounded_geometry_input") or not text_is(value.carrier_feature_id,"blob.body.core"):return false
	if not value.positive_node_ids is Array or value.positive_node_ids.size()!=13 or not value.cavity_node_ids is Array or value.cavity_node_ids!=IDS:return false
	for index: int in range(13):
		if not text_is(value.positive_node_ids[index],"n%03d"%index):return false
	if not integral(value.author_projection_field_calls) or float(value.author_projection_field_calls)<2.0 or float(value.author_projection_field_calls)>79.0 or not integral(value.author_normal_field_calls) or float(value.author_normal_field_calls)!=6.0:return false
	if not integral(value.author_complete_field_calls) or float(value.author_complete_field_calls)!=float(value.author_projection_field_calls)+6.0:return false
	if not _frame_ok(value.frame):return false
	for key: String in ["reference_cell_m","feature_radius_m","wall_m"]:
		if not number(value[key]) or float(value[key])<=0.0:return false
	if not shadow_same(value.reference_cell_m,H) or not vector(value.territory_half_extents_m,2):return false
	for extent: Variant in value.territory_half_extents_m:
		if float(extent)<=0.0:return false
	if not decision_ok(value.selection_decision) or not value.cavities is Array or value.cavities.size()!=1:return false
	var row: Variant=value.cavities[0]
	if not keys_are(row,ROW_KEYS) or not text_is(row.role,ROLES[0]) or not text_is(row.node_id,IDS[0]) or not text_is(row.feature_id,FEATURES[0]):return false
	if not integral(row.site_id) or float(row.site_id)!=float(value.selection_decision.selected_site_id) or not integral(row.angle_index) or not integral(row.angle_denominator) or not number(row.radius_fraction) or not number(row.roll_radians):return false
	var site_id: int=int(row.site_id)
	var radius_fraction: float=0.0
	var angle_index: int=0
	var angle_denominator: int=1
	if site_id>=1 and site_id<=8:radius_fraction=0.35;angle_index=site_id-1;angle_denominator=8
	elif site_id>=9:radius_fraction=0.70;angle_index=site_id-9;angle_denominator=4
	if not shadow_same(row.radius_fraction,radius_fraction) or int(row.angle_index)!=angle_index or int(row.angle_denominator)!=angle_denominator or not shadow_same(row.roll_radians,ROLLS[0]):return false
	if not vector(row.offset_m,2):return false
	for key: String in ["nominal","projection_axis","radii_m","rotation","surface_hit","center"]:
		if not vector(row[key],3):return false
	for radius: Variant in row.radii_m:
		if float(radius)<=0.0:return false
	if not local_frame_ok(row.local_frame) or float(row.local_frame.site_id)!=float(row.site_id):return false
	if not same(row.projection_axis,value.frame.normal) or not same(row.local_frame.projection_axis,row.projection_axis):return false
	for key: String in ["rotation","surface_hit","center"]:
		if not same(row[key],row.local_frame[key]):return false
	return true

static func _bad(message: String)->Dictionary:return {"ok":false,"error":"223 "+message}

static func validate_declaration(dna: Dictionary)->Dictionary:
	var settings: Variant=dna.get("settings",{})
	if not settings is Dictionary:return _bad("settings must be a dictionary.")
	var choice: Dictionary=selection(settings)
	if choice.has("error"):return _bad(str(choice.error))
	var nodes: Variant=dna.get("nodes",[])
	if not nodes is Array:return _bad("nodes must be an array.")
	if choice.mode==OFF:
		for inactive_node: Variant in nodes:
			if inactive_node is Dictionary and inactive_node.has(KEY):return _bad("inactive marker is forbidden.")
		var inactive_metadata: Variant=dna.get("metadata")
		if inactive_metadata is Dictionary and inactive_metadata.has(KEY):return _bad("inactive context is forbidden.")
		return {"ok":true}
	if not text_is(settings.get(PIN_SETTING),PIN) or not text_is(dna.get("type"),"Blob") or not integral(dna.get("seed")) or float(dna.seed)!=22.0:return _bad("fixed Blob22 mode/pin is required.")
	var metadata: Variant=dna.get("metadata")
	if not metadata is Dictionary or not integral(metadata.get("iteration_index")) or float(metadata.iteration_index)!=5.0 or nodes.size()!=14:return _bad("requires exactly thirteen positive carriers and one Stage5 primary void.")
	var connections: Variant=dna.get("connections")
	if not connections is Array or connections.size()!=13:return _bad("requires the unchanged twelve links and one owned-primary suffix link.")
	var connection: Variant=connections[12]
	if not keys_are(connection,["from","to","kind","blend"]) or not text_is(connection.from,"n000") or not text_is(connection.to,IDS[0]) or not text_is(connection.kind,"growth") or not number(connection.blend):return _bad("unexpected owned-primary parent connection.")
	for key: String in ["modules","direct_surface_carriers"]:
		var values: Variant=dna.get(key,[])
		if not values is Array or not values.is_empty():return _bad("modules and direct layers remain disabled.")
	for index: int in range(13):
		var positive: Variant=nodes[index]
		if not positive is Dictionary or not text_is(positive.get("id"),"n%03d"%index) or positive.has(KEY) or not text_is(positive.get("operation","union"),"union"):return _bad("positive prefix or order changed.")
	var node: Variant=nodes[13]
	if not node is Dictionary:return _bad("missing primary cavity declaration.")
	var context: Variant=node.get(KEY)
	if not context_ok(context):return _bad("requires a closed finite selected-primary context.")
	if not shadow_same(metadata.get(KEY),context):return _bad("metadata context disagrees with consumed declaration.")
	var row: Dictionary=context.cavities[0]
	for pair: Array in [["id",IDS[0]],["feature_id",FEATURES[0]],["parent","n000"],["kind","cavity"],["role","cavity"],["operation","subtract"],["material","muscle"],["blob_region","mantle_blind_chamber"],["source","fixed223_territory_primary_blind_chamber_v1"]]:
		if not text_is(node.get(str(pair[0])),str(pair[1])):return _bad("unexpected primary identity or operation.")
	for key: String in ["bone","surface_opening"]:
		if not node.get(key) is bool or node[key]:return _bad("primary void must not create a bone or auto-reseat its mouth.")
	if not same(node.get("position"),row.center) or not same(node.get("size"),row.radii_m) or not same(node.get("rotation"),row.rotation):return _bad("consumed primary geometry disagrees with selected pose.")
	if not same(connection.blend,node.get("blend")):return _bad("owned-primary connection blend differs from cutter.")
	if not vector(node.get("normal"),3) or not number(node.get("radius")) or not number(node.get("noise")) or float(node.noise)!=0.0 or not number(node.get("blend")) or float(node.blend)<=0.0:return _bad("invalid primary scalar operations.")
	if not node.get("deformation") is Dictionary or not node.deformation.is_empty() or node.has("contained_lip") or node.has("cavity_id") or node.has("porous_patch") or not node.get("points",[]) is Array or not node.get("points",[]).is_empty() or not node.get("radii",[]) is Array or not node.get("radii",[]).is_empty() or not node.get("shape",{}) is Dictionary or not node.get("shape",{}).is_empty():return _bad("unsupported extra primary operation.")
	var pending: Variant=node.get("porous_growth")
	if not keys_are(pending,["minimum_wall","host_thickness","complete_rim","back_wall","containment_method","burial_ratio","metrics_space"]) or not text_is(pending.get("containment_method"),"fixed223_finite_pending") or not pending.get("complete_rim") is bool or pending.complete_rim or not pending.get("back_wall") is bool or pending.back_wall:return _bad("authored metadata must not pretend to be geometric qualification.")
	for key: String in ["minimum_wall","host_thickness","burial_ratio"]:
		if not number(pending[key]):return _bad("nonfinite pending primary scalar.")
	if not text_is(pending.metrics_space,"grounded_geometry_input"):return _bad("invalid pending coordinate space.")
	# No geometry key here: recipe decoding would recurse through validation.
	return {"ok":true}

static func _float_vector(value: Variant,count: int)->bool:
	if not vector(value,count):return false
	for component: Variant in value:
		if not component is float:return false
	return true

static func validate_restored(dna: Dictionary)->Dictionary:
	var declaration: Dictionary=validate_declaration(dna)
	if not declaration.ok or not enabled(dna):return declaration
	var node: Dictionary=dna.nodes[13]
	var context: Dictionary=node[KEY]
	for key: String in ["version","partial_stage","author_complete_field_calls","author_projection_field_calls","author_normal_field_calls"]:
		if not context[key] is int:return _bad("restored context integer tags must retain their types.")
	var expected: Dictionary=frame_table(dna)
	if expected.has("error"):return expected
	for key: String in ["frame","reference_cell_m","feature_radius_m","wall_m","territory_half_extents_m"]:
		if not same(context[key],expected[key]):return _bad("restored fixed chart scalar bits differ: "+key)
	var decision: Dictionary=context.selection_decision
	for key: String in ["version","pool_law_version","pool_size","screened_sites","eligible_sites","trial_count","selected_rank","selected_site_id"]:
		if not decision[key] is int:return _bad("restored decision integer tags must retain their types.")
	for key: String in ["shortlist_site_ids","shortlist_ranks"]:
		for value: Variant in decision[key]:
			if not value is int:return _bad("restored shortlist integer tags must retain their types.")
	for value: Variant in decision.shortlist_scores:
		if not value is float:return _bad("restored shortlist scores must preserve float types.")
	var decision_rebuilt: Dictionary=selection_decision(decision.shortlist_site_ids,decision.shortlist_scores,int(decision.eligible_sites),int(decision.selected_rank))
	if not decision_rebuilt.get("ok",false) or not same(decision,decision_rebuilt.decision):return _bad("restored selected decision differs from canonical schema.")
	var row: Dictionary=context.cavities[0]
	var expected_row: Dictionary=selected_site(expected,int(decision.selected_site_id))
	if expected_row.has("error"):return expected_row
	for key: String in SITE_KEYS:
		if key=="rotation":continue
		if not same(row[key],expected_row[key]):return _bad("restored selected site differs: "+key)
	if not _float_vector(row.surface_hit,3) or not _float_vector(row.local_frame.normal_values,6):return _bad("restored site witnesses must preserve float types.")
	if not row.local_frame.version is int or not row.local_frame.site_id is int:return _bad("restored local-pose integer tags must retain their types.")
	var reconstructed: Dictionary=local_frame(expected.frame,expected_row,row.surface_hit,row.local_frame.normal_values)
	if not reconstructed.get("ok",false) or not same(row.local_frame,reconstructed.local_frame):return _bad("restored local pose/provenance differs from exact reconstruction.")
	for key: String in ["rotation","surface_hit","center"]:
		if not same(row[key],reconstructed.local_frame[key]):return _bad("restored selected pose scalar bits differ.")
	var basis: Basis=Basis.from_euler(vec(row.rotation))
	var center: Vector3=vec(row.surface_hit)-0.48*float(row.radii_m[2])*basis.z
	if not same(row.center,arr(center)) or not same(node.get("normal"),arr(basis.z)):return _bad("fixed center/basis relationship differs.")
	if not same(node.noise,0.0) or not same(node.radius,row.radii_m[0]) or not same(node.blend,0.025*float(context.frame.length)):return _bad("unchanged primary radius/noise/blend differs.")
	var pending: Dictionary=node.porous_growth
	if not same(pending.minimum_wall,context.wall_m) or not same(pending.host_thickness,0.0) or not same(pending.burial_ratio,0.48):return _bad("pending primary scalars differ.")
	var blueprint: Variant=dna.get("biological_blueprint")
	if not blueprint is Dictionary or not blueprint.get("features") is Array:return _bad("missing primary feature intention.")
	var found: Array=[]
	for feature_value: Variant in blueprint.features:
		if not feature_value is Dictionary:continue
		var feature_id: Variant=feature_value.get("id")
		if feature_id is String and feature_id.begins_with("blob.cavity.") and feature_id!=FEATURES[0]:return _bad("secondary or other cavity intentions are forbidden in the single-primary mode.")
		if text_is(feature_id,FEATURES[0]):found.append(feature_value)
	if found.size()!=1:return _bad("requires exactly one primary feature intention.")
	var feature: Dictionary=found[0]
	var expected_recipe: Dictionary={"version":4,"mode":MODE,"spec_sha256":PIN,"role":ROLES[0],"parent_node_id":"n000","carrier_feature_id":"blob.body.core","radii_over_L":RADII[0].duplicate(),"roll_radians":ROLLS[0],"site_id":int(row.site_id)}
	if not shadow_same(feature.get("geometry_recipe"),expected_recipe) or not shadow_same(feature.get("growth_direction"),arr(vec(row.local_frame.consumed_normal).normalized())):return _bad("primary intention recipe/direction disagrees with selected pose.")
	var artifacts: GDScript=load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	var positive: Dictionary=positive_projection(dna)
	if artifacts.geometry_key(positive,5,DEPENDENCY4)!=BASELINE_KEY:return _bad("positive consumed215 geometry/key changed.")
	return {"ok":true}
