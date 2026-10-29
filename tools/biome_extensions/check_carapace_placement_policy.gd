extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var b=preload("res://tools/biome_extensions/carapace_placement_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.alien_infected_coverage=100;b._configure_noise()
	var g=Structures.new();var p:Vector2=b.test_origin
	check(g.can_place_carapace(b,p,240,100),"Dry flat fully infected support admitted")
	b.test_grade=Vector2(.25,.1)
	check(g.can_place_carapace(b,p,240,100),"Steady natural grade admitted despite large total elevation range")
	b.test_grade=Vector2(1,0)
	check(not g.can_place_carapace(b,p,240,100),"Extreme plane grade rejected")
	b.test_grade=Vector2.ZERO;b.cliff=true
	check(not g.can_place_carapace(b,p,240,100),"Abrupt residual cliff rejected")
	b.cliff=false;b.flooded=true
	check(not g.can_place_carapace(b,p,240,100),"Flooded supports rejected")
	b.flooded=false;b.owner=.4
	check(not g.can_place_carapace(b,p,240,100),"Partial infection front preserved")
	b.owner=1;g._protected_sites=[{"position":p,"half":96.0}]
	check(not g.can_place_carapace(b,p,240,100),"Existing cavity approach reserved")
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://tools/biome_extensions/carapace_placement_builder.gd","res://tools/biome_extensions/check_carapace_placement_policy.gd"]:hashes[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_carapace_placement_policy.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"scope":"Test-only affine/step/water/owner fixtures isolate placement policy: natural grade versus abrupt residual relief, dry support, full infection and reserved cavity exclusion. Actual geographic placements are a separate test."},"  "))
	print("CARAPACE_PLACEMENT_POLICY ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
