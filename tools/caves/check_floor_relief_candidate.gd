extends "res://tools/caves/check_crystal_features.gd"
const Candidate=preload("res://tools/caves/floor_relief_field_candidate.gd")
const Relief=preload("res://tools/caves/floor_relief_candidate.gd")
func floor_at(field,x:float,z:float)->float:
	var low:float=16;var high:float=24
	for iteration in range(18):
		var mid:float=(low+high)*.5
		if field.sample(Vector3(x,mid,z))>=0:low=mid
		else:high=mid
	return (low+high)*.5
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/floor_relief_candidate.gd","res://tools/caves/floor_relief_field_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=crystal_fixture();region.nodes[0].chamber_height=36.0;region.nodes.append({"id":"B","point":Vector3(64,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0});region.nodes.append({"id":"C","point":Vector3(96,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0});region.cave_biome_regions.candidates[0].distances["C"]=10000.0
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var old=Field.new();old.include_surface_air=false;var candidate=Candidate.new();candidate.include_surface_air=false;check(old.compile([region],height,[],region.cave_biome_regions) and candidate.compile([region],height,[],region.cave_biome_regions),"Same controlled connected room volume compiled")
	var old_errors:int=0;var protected_errors:int=0;var changed:int=0;var maximum_raise:float=0;var maximum_slope:float=0
	for x in range(-12,121,2):
		for z in range(20,49,2):
			var p:=Vector3(x,20,z);candidate.relief_enabled=false;old_errors+=int(candidate.sample(p)!=old.sample(p) or candidate.normal(p)!=old.normal(p));candidate.relief_enabled=true
			var closest_x:float=clampf(x,-16,96)
			if Vector2(x-closest_x,z-32).length()<=5:protected_errors+=int(candidate.sample(p)!=old.sample(p))
			if x>=54 and x<=74 and z==46:
				var floor_y:float=floor_at(candidate,x,z);maximum_raise=maxf(maximum_raise,floor_y-20);changed+=int(floor_y>20.05);var n:Vector3=candidate.normal(Vector3(x,floor_y,z));maximum_slope=maxf(maximum_slope,acos(clampf(n.y,-1,1)))
	check(old_errors==0 and protected_errors==0,"Full independent OFF scalar/normal and entire finite10m protected passage including rounded endcaps exact over fixed grid");check(changed>0 and maximum_raise>.2 and maximum_raise<=.651 and maximum_slope<PI/4,"Actual same-field rocky relief positive,bounded and below ordinary45degree slope")
	for point:Vector3 in [Vector3(30,20,46),Vector3(-120.25,20,17.5),Vector3(16.125,20,-320.75)]:check(absf(Relief.wave(point)-Relief.wave(point+Vector3(3840,0,0)))<.000001 and absf(Relief.wave(point)-Relief.wave(point+Vector3(0,0,3840)))<.000001,"Signed physical floor phase continuous across macro origins")
	for family:int in [6,7]:
		var locked:Dictionary=region.duplicate(true);locked.cave_family=family;var before=Field.new();before.include_surface_air=false;var after=Candidate.new();after.include_surface_air=false;check(before.compile([locked],height,[],locked.cave_biome_regions) and after.compile([locked],height,[],locked.cave_biome_regions),"Biological locked fixture compiles")
		for x in range(16,81,4):check(before.sample(Vector3(x,20.25,46))==after.sample(Vector3(x,20.25,46)),"Biological cave scalar remains exact despite forced neighboring mineral weights")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private floor relief source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_floor_relief_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"old_errors":old_errors,"protected_errors":protected_errors,"positive_floor_samples":changed,"maximum_raise_m":maximum_raise,"maximum_slope_degrees":rad_to_deg(maximum_slope),"scope":"PRIVATE scalar-only controlled connected mineral/default floor-relief mechanism. One shared floor point offset across room primitives,existing route/shore exclusion,exact OFF scalar/normal,signed phase and biological lock checks. Not production adoption,native geometry/physical walk,actual normal scene or FPS/art completion."},"  "));print("FLOOR_RELIEF_CANDIDATE ",checks," maxraise=",maximum_raise," slope=",rad_to_deg(maximum_slope)," off=",old_errors," protected=",protected_errors," failures=",failures);quit(0 if failures.is_empty() else 1)
