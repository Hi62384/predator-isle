extends RefCounted
## Correlated biological priors, not fixed meshes. All dimensions and mass
## arrangements are sampled again for each seed, including mixed identities.
const VERSION = 4
const PLANS = ["compact", "flattened", "tower", "multilobe", "elongated", "lopsided", "cluster", "muscular", "sagging", "asymmetric"]
const PROFILES = ["swollen", "porous", "mimic", "tendril", "membranous", "sensory", "muscular", "clustered", "hollow", "rooted", "smooth_mimic", "abnormal"]
const FAMILIES = ["sac", "lattice", "face", "tendril", "membrane", "stalk", "limb", "nodule", "cavity", "fold"]
const MODES = ["roll","vine","limb","contractile","peristaltic","hybrid","drag","pulse","multicontact","undulate"]
const PRIORS = [
	[1.0,.12,.05,.12,.25,.04,.2,.6,.15,.7], [.2,1.0,.08,.4,.4,.12,.15,.18,.7,.25],
	[.35,.3,1.0,.4,.35,.0,.25,.2,.2,.8], [.12,.15,.0,1.0,.45,.2,.2,.15,.12,.35],
	[.25,.5,.1,.55,1.0,.12,.1,.15,.25,.6], [.45,.25,.0,.25,.12,1.0,.15,.2,.15,.2],
	[.2,.0,.07,.12,.05,.0,1.0,.1,.06,.8], [.6,.2,.05,.15,.2,.12,.25,1.0,.15,.4],
	[.1,.8,.12,.4,.55,.15,.2,.25,1.0,.5], [.15,.2,.05,1.0,.25,.07,.65,.2,.15,.35],
	[.06,.0,1.0,.15,.15,.05,.04,.04,.05,.25], [.6,.7,.45,.7,.55,.55,.35,.7,.6,.6]]
const PREFERRED_PLANS = [["multilobe","tower","sagging"], ["compact","tower","asymmetric"], ["tower","lopsided","multilobe"], ["elongated","sagging","asymmetric"], ["lopsided","elongated","sagging"], ["flattened","compact","cluster"], ["muscular","tower","lopsided"], ["cluster","multilobe","asymmetric"], ["tower","sagging","asymmetric"], ["flattened","elongated","lopsided"], ["compact","elongated","lopsided"], ["asymmetric","cluster","tower"]]
const CONTROL_DEFAULTS = {"width":1.0,"height":1.0,"length":1.0,"asymmetry":1.0,"mass_count":0,"mass_variation":1.0,"fusion":1.0,"contact":1.0,"stiffness":0.45,
	"diversity":0.25,"sacs":1.0,"lattice":1.0,"faces":1.0,"limbs":1.0,"tentacles":1.0,"branches":1.0,"membranes":1.0,"cavities":1.0,"stalks":1.0,"fibers":1.0,"folds":1.0,"detail":1.0,"combinations":1.0,
	"palette":-1,"wetness":0.45,"roughness":1.0,"veins":1.0,"translucency":0.5,"microdetail":0.6,
	"circulation":1.0,"softness":0.6,"gravity":0.65,"flattening":0.6,"recovery":0.6,"volume":0.85,"wobble":0.45,"follow_through":0.6,"deformation_quality":1.0}

static func plan(seed_value: int, mode: String, options: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("predator_blob_v2:%d" % seed_value).hash()
	var c: Dictionary = CONTROL_DEFAULTS.duplicate()
	for key in c:
		if options.has(key): c[key] = clampf(float(options[key]), -1.0 if key == "palette" else 0.0, 12.0 if key == "mass_count" else (4.0 if key=="palette" else 2.0))
	var profile := str(options.get("profile", "auto"))
	if profile not in PROFILES: profile = PROFILES[rng.randi_range(0, PROFILES.size()-1)]
	var primary := PROFILES.find(profile)
	var secondary := rng.randi_range(0, PROFILES.size()-1)
	var mix_amount := rng.randf_range(0.0, .3) * float(c.diversity)
	var weights: Dictionary = {}
	var multipliers := [c.sacs,c.lattice,c.faces,c.tentacles,c.membranes,c.stalks,c.limbs,1.0,c.cavities,c.folds]
	for i in FAMILIES.size(): weights[FAMILIES[i]] = lerpf(PRIORS[primary][i], PRIORS[secondary][i], mix_amount) * float(multipliers[i])
	var plan_id := str(options.get("body_plan","auto"))
	if plan_id not in PLANS:
		var choices: Array = PREFERRED_PLANS[primary]
		plan_id = choices[rng.randi_range(0, choices.size()-1)] if rng.randf() < .8 else PLANS[rng.randi_range(0, PLANS.size()-1)]
	var dimensions := Vector3.ONE
	match plan_id:
		"compact": dimensions = Vector3(1,.86,.95)
		"flattened": dimensions = Vector3(1.65,.43,1.25)
		"tower": dimensions = Vector3(.78,1.65,.8)
		"multilobe": dimensions = Vector3(1.35,.84,1.22)
		"elongated": dimensions = Vector3(.82,.66,1.95)
		"lopsided": dimensions = Vector3(1.35,1.05,.86)
		"cluster": dimensions = Vector3(1.2,1.1,1.05)
		"muscular": dimensions = Vector3(1.26,1.03,1.15)
		"sagging": dimensions = Vector3(1.25,.73,1.5)
		"asymmetric": dimensions = Vector3(1.1,1.32,1.5)
	dimensions *= Vector3(rng.randf_range(.8,1.2)*float(c.width),rng.randf_range(.82,1.18)*float(c.height),rng.randf_range(.8,1.2)*float(c.length))
	dimensions = dimensions.max(Vector3.ONE * .22)
	var locomotion := mode
	if mode == "creep": locomotion = "limb"
	if locomotion not in MODES:
		locomotion = "roll" if plan_id in ["compact","multilobe","lopsided"] else ("limb" if profile == "muscular" else ["drag","undulate","hybrid"][rng.randi_range(0,2)])
	if mode=="auto" and profile in ["rooted","tendril"]: locomotion="vine"
	if locomotion in ["vine","multicontact"]: weights.tendril=maxf(weights.tendril,.85)
	if locomotion=="limb": weights.limb=maxf(weights.limb,.65)
	if locomotion == "roll": dimensions.z = maxf(dimensions.z, dimensions.y * .8)
	var size := rng.randf_range(1.05,1.55)
	var mass_count := rng.randi_range(4,8) if plan_id in ["cluster","multilobe","asymmetric"] else rng.randi_range(2,5)
	if int(c.mass_count) > 0: mass_count = clampi(int(c.mass_count),1,12)
	var dna := {"version": VERSION,"seed":seed_value,"controls":c,"body_plan":plan_id,"profile":profile,"secondary_profile":PROFILES[secondary],"mix":mix_amount,"weights":weights,
		"size":size,"core_radii":dimensions*size,"locomotion":locomotion,"mass_count":mass_count,"squishiness":c.softness,"irregularity":rng.randf_range(.25,.65),
		"asymmetry":rng.randf_range(.18,.75)*float(c.asymmetry),"wetness":c.wetness,"palette":rng.randi_range(0,4) if int(c.palette)<0 else int(c.palette),
		"center_of_mass":Vector3.ZERO,"rolling_axis":Vector3.RIGHT,"ground_contact":Vector3(0,-dimensions.y*size,0),"detail_intensity":rng.randf_range(.55,1.0)*float(c.detail)}
	dna["descriptor"] = descriptor(dna)
	return dna

static func descriptor(dna: Dictionary) -> PackedFloat32Array:
	var r: Vector3 = dna.core_radii
	var v := PackedFloat32Array([r.x/r.y/5.0,r.z/r.y/5.0,float(dna.mass_count)/12.0,float(dna.asymmetry),float(PLANS.find(dna.body_plan))/10.0])
	for family in FAMILIES: v.append(float(dna.weights[family]))
	v.append(float(MODES.find(dna.locomotion))/5.0)
	return v

static func distance(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var total := 0.0
	for i in mini(a.size(), b.size()): total += absf(a[i]-b[i])
	return total / float(maxi(a.size(),1))
