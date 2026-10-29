extends "res://tools/caves/check_crystal_connected_profiles.gd"
const Production=preload("res://scripts/caves/crystal_profiles.gd")
const Shapes=preload("res://scripts/caves/formations.gd")
func wet_fixture(radius:float)->Dictionary:
	var region:Dictionary=fixture();region.nodes[0].chamber_radius=radius;region.nodes[0].chamber_height=28.0
	region["pools"]=[{"id":"A:seepage","center":Vector3(32,20,50),"radius":5.0,"water_radius":4.0,"water_y":19.6,"bed_y":17.0,"depth":3.0,"bed":{"id":"A:bed","point":Vector3(32,17,50),"level":1,"chamber_radius":4.25,"chamber_height":4.5},"bed_lobes":[]}];return region
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_connected_profiles.gd","res://tools/caves/crystal_connected_profiles_candidate.gd","res://scripts/caves/crystal_profiles.gd","res://scripts/caves/field.gd","res://scripts/caves/portal_field.gd","res://scripts/caves/formations.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var controls:Dictionary={"geode_frequency":0.0,"ravine_frequency":0.0,"large_lake_frequency":1.0};var off:Dictionary={"geode_frequency":0.0,"ravine_frequency":0.0,"large_lake_frequency":0.0};var seeds:Array=[73921,17,92881]
	for index in range(33):seeds.append(1000+index)
	var old_unsafe:int=0;var rejected:int=0;var admitted:int=0;var records:Array=[]
	for seed_id:int in seeds:
		for radius:float in [26.0,34.0,40.0]:
			var region:Dictionary=wet_fixture(radius);var original:PackedByteArray=var_to_bytes(region);var old:Dictionary=Candidate.decorate(region,height,seed_id,controls,400,10);var result:Dictionary=Production.decorate(region,height,seed_id,controls,400,10);var selected:bool=result.pools[0].get("crystal_large_lake",false)
			check(var_to_bytes(region)==original,"Admission never mutates cached original basin or host");check(var_to_bytes(Production.decorate(region,height,seed_id,off,400,10))==original,"Exact all-profile-controls-off legacy result")
			if radius<40:
				old_unsafe+=int(old.pools[0].get("crystal_large_lake",false));rejected+=int(not selected);check(not selected and var_to_bytes(result)==original,"Narrow or steep shore rejected without reroll/new air/floor edits")
			else:
				admitted+=int(selected);check(selected and result.pools[0].radius>=8 and result.pools[0].radius<=12,"Actual broad low host retains positive natural8–12m basin")
				var wet_region:Dictionary=wet_fixture(radius);wet_region.pools[0].water_y=20.25;var wet_result:Dictionary=Production.decorate(wet_region,height,seed_id,controls,400,10);check(not wet_result.pools[0].get("crystal_large_lake",false),"Defensive dry-bank admission rejects a retained water level above its actual walking rock even with safe slope/headroom")
				var field=Field.new();field.include_surface_air=false;check(field.compile([result],height,[],result.cave_biome_regions),"Complete accepted basin compiles inside unchanged128-bin/feature limits")
				check(field._protected_shores.size()==1 and Production.dry_bank(field,result.pools[0],result.pools[0].radius),"Full three-width/64station sampled dry bank remains navigable after actual bed enlargement")
				var center:Vector3=result.pools[0].center;var shore_radius:float=result.pools[0].radius+2;var shapes=Shapes.new()
				for station in range(32):
					var p:Vector3=center+Vector3(cos(TAU*station/32)*shore_radius,1,sin(TAU*station/32)*shore_radius);check(field.protected_shore(p,.6,19.5,26.0) and shapes.protected(field,p,.6,19.5,26.0),"Both ordinary formations and whole angled Crystal bounds share complete dry-bank clearance")
				check(not field.protected_shore(center,.5,20,23) and not field.protected_shore(center+Vector3(shore_radius,30,0),.5,49,52),"No whole-lake or high-wall blanket exclusion,only finite walking annulus")
				field.clear();check(field._protected_shores.is_empty() and not field.protected_shore(center,.6,20,26),"Field clear removes old-world shore reservations")
			records.append({"seed":seed_id,"host_radius":radius,"old_admitted":old.pools[0].get("crystal_large_lake",false),"new_admitted":selected,"radius":result.pools[0].radius})
	check(old_unsafe==72 and rejected==72 and admitted==36,"All36fixedseeds:72original unsafe positives rejected;36valid broad-host large-water positives retained")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable measured dry-bank source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_bank_admission.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"old_unsafe_positives":old_unsafe,"rejected_unsafe":rejected,"admitted_broad_hosts":admitted,"records":records,"scope":"Production real existing-field dry shore admission,original unsafe candidate counterfactual,36fixedseeds/narrow26m/steep34m/positive40m low28m hosts,unchanged primitive bounds.192bankstations per candidate/actual SDF normal margin. Shared finite walking-annulus complete-form exclusion/clear/no mutation/off controls. Controlled geology,not normal occurrence/native art/live streaming/FPS or all-user completion."},"  "));print("CRYSTAL_BANK_ADMISSION ",checks," old_unsafe=",old_unsafe," rejected=",rejected," broad=",admitted," failures=",failures);quit(0 if failures.is_empty() else 1)
