extends "res://tools/caves/check_floor_relief_candidate.gd"
const Original=preload("res://tools/caves/references/floor_relief_original_portal.gd")
const FrozenCandidate=preload("res://tools/caves/references/floor_relief_original_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://tools/caves/references"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/crystal_cave_definition.tres","res://tools/caves/floor_relief_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");check(definition.validation_errors().is_empty() and definition.feature_configuration.floor_ridges,"Bounded independent floor controls validate")
	var region:Dictionary=crystal_fixture();region.nodes[0].chamber_height=36.0;region.nodes.append({"id":"B","point":Vector3(64,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0});region.nodes.append({"id":"C","point":Vector3(96,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0});region.cave_biome_regions.candidates[0].distances["C"]=10000.0
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var unassigned:Dictionary=region.duplicate(true);unassigned.cave_biome_regions.candidates=[];check(var_to_bytes(Crystal.new().decorate_region(unassigned,height,73921,definition.feature_configuration,400,10))==var_to_bytes(unassigned),"No modifier on unassigned Default region;complete original dictionary exact")
	var low_roof:Callable=func(_x:float,_z:float)->float:return 60.0
	check(var_to_bytes(Crystal.new().decorate_region(region,low_roof,73921,definition.feature_configuration,400,10))==var_to_bytes(region),"Insufficient cover rejects floor marker together with chamber growth")
	var original=Original.new();var expected=FrozenCandidate.new();var off=Field.new();var actual=Field.new()
	var enabled:Dictionary=region.duplicate(true);enabled["cave_floor_relief"]={"crystal":.65}
	for item in [original,expected,off,actual]:item.include_surface_air=false
	check(original.compile([region],height,[],region.cave_biome_regions) and expected.compile([region],height,[],region.cave_biome_regions) and off.compile([region],height,[],region.cave_biome_regions) and actual.compile([enabled],height,[],region.cave_biome_regions),"Independent frozen old,private candidate and actual production fields compile")
	var scalar_errors:int=0;var normal_errors:int=0;var off_errors:int=0;var probes:int=0
	for x in range(-16,129,4):
		for z in range(8,57,4):
			for y:float in [16.0,19.5,20.0,20.25,20.65,21.0,24.0,32.0,48.0,60.0]:
				var point:=Vector3(x,y,z);probes+=1;scalar_errors+=int(actual.sample(point)!=expected.sample(point));off_errors+=int(off.sample(point)!=original.sample(point));normal_errors+=int(actual.normal(point)!=expected.normal(point) or off.normal(point)!=original.normal(point))
	check(scalar_errors==0 and normal_errors==0 and off_errors==0,"Production single-pass scalar/normals exact independent frozen private prototype;OFF exact full original")
	for key:Vector3i in [Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0)]:
		check(var_to_bytes(Mesher.new().build(actual,key,2))==var_to_bytes(Mesher.new().build(expected,key,2)),"Entire production mesh positions/normals/indices exact independent frozen private candidate")
		check(var_to_bytes(Mesher.new().build(off,key,2))==var_to_bytes(Mesher.new().build(original,key,2)),"Entire independent old mesh exact OFF")
	check(actual.numeric_bytes()-off.numeric_bytes()==32,"Only one bounded numeric modifier entry;no added primitive/job/node/collider or second volume")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable production floor adoption source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_floor_relief_adoption.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"probes":probes,"scalar_errors":scalar_errors,"normal_errors":normal_errors,"off_errors":off_errors,"scope":"Actual one-pass production kernel versus full independently frozen old/private field,whole scalar/normal and3native mesh arrays exact,OFF exact. Original routes/locked biomes tested by private predecessor;actual generated production walking follows. No FPS/art/all-user completion claim."},"  "));print("FLOOR_RELIEF_ADOPTION ",checks," probes=",probes," scalar=",scalar_errors," normals=",normal_errors," off=",off_errors," failures=",failures);quit(0 if failures.is_empty() else 1)
