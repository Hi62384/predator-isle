extends "res://tools/biome_extensions/check_all.gd"
const ARCHIVE="res://tools/biome_extensions/artifacts/revisions/failed_diagnostic_check_junction_custom_walk_diagnostic_seed_92881_scale_0p2_5a66f4a0f73f"
func parse2(value:String)->Vector2:
	var pieces:PackedStringArray=value.trim_prefix("(").trim_suffix(")").split(",");return Vector2(float(pieces[0]),float(pieces[1]))
func run()->void:
	var hashes:Dictionary={}
	var archived_path:String=ARCHIVE+"/evidence/tools/biome_extensions/artifacts/check_junction_custom_walk_diagnostic_seed_92881_scale_0p2.json"
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/check_rejected_steep_approach.gd","res://tools/biome_extensions/artifacts/check_junction_custom_admission.json","res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json",ARCHIVE+"/manifest.json",archived_path]:hashes[source]=FileAccess.get_sha256(source)
	var archived=JSON.parse_string(FileAccess.get_file_as_string(archived_path));check(not archived.passed and not archived.failures.is_empty(),"Original failed route remains explicitly failed, not rewritten as successful")
	var record:Dictionary=archived.cases[0];check(not record.finished and record.seed==92881 and record.feature_scale==.2,"Original failed minimum-scale seed retained")
	check(record.initial_support_probe.initial_capsule_overlap_count>0 and record.max_unsupported_drop_m>.75,"Original embedded spawn and measured initial drop retained")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(ARCHIVE+"/manifest.json"))
	for copy:Dictionary in manifest.files:
		check(FileAccess.get_sha256(copy.snapshot)==copy.sha256,"Immutable original source/evidence snapshot "+copy.original)
		# Preserve the verified original bytes too, not only a manifest pointing
		# at a different historical directory. Final checkpoint guards recheck
		# these copies after all intervening native profiles have completed.
		hashes[copy.snapshot]=copy.sha256
	var original=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"));var navigation=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json"));var p:Vector2=Vector2.INF
	for site:Dictionary in original.cases:
		if int(site.seed)==92881 and site.feature_scale==.2:p=Vector2(site.position[0],site.position[1])
	check(p.is_finite(),"Original geometrically admitted root remains in its separate manifest")
	var rejected:bool=false
	for site:Dictionary in navigation.navigation_rejections:
		# Vector JSON uses Godot's display precision; 5cm is only an identity
		# match for serialized metadata, never a physical collision tolerance.
		if int(site.seed)==92881 and site.scale==.2 and parse2(site.position).distance_to(p)<.05:rejected=true
	check(rejected,"Navigation manifest explicitly records rejection of the original steep site")
	var coordinates:PackedStringArray=record.initial_support_probe.position.trim_prefix("(").trim_suffix(")").split(",");var q:=Vector2(float(coordinates[0]),float(coordinates[2]));var b=make_builder(7,92881);b.settings.alien_infected.feature_scale=.2;b._configure_noise()
	var gx:int=floori(q.x/2);var gz:int=floori(q.y/2);var fx:float=q.x/2-gx;var fz:float=q.y/2-gz
	var a:=Vector3(gx*2,b._get_height(gx*2,gz*2),gz*2);var c:=Vector3(gx*2,b._get_height(gx*2,(gz+1)*2),(gz+1)*2);var d:=Vector3((gx+1)*2,b._get_height((gx+1)*2,(gz+1)*2),(gz+1)*2);var e:=Vector3((gx+1)*2,b._get_height((gx+1)*2,gz*2),gz*2)
	var normal:Vector3=(c-a).cross(e-a).normalized() if fx+fz<=1 else (c-e).cross(d-e).normalized();var grade:float=rad_to_deg(acos(clampf(normal.y,-1,1)))
	check(grade>45,"Current canonical near-triangle still exceeds the unchanged capsule floor limit; terrain was not flattened to pass the fixture")
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable rejected-route source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_rejected_steep_approach.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"preserved_failed_report":archived_path,"current_sampled_start_grade_degrees":grade,"scope":"Expected rejection, NOT a repaired or completed walk: original geometrically admitted seed92881 scale0.2 route remains archived with embedded start/drop, its current near triangle remains steeper than 45 degrees, and the separate navigation discovery explicitly retains its rejection. All immutable original copies are verified. A new navigation-admitted site does not certify every root or arbitrary terrain as walkable."},"  "))
	print("STEEP_APPROACH_REJECTION_CONTROL ",checks," grade=",grade," failures=",failures);quit(0 if failures.is_empty() else 1)
