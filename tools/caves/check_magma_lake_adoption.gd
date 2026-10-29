extends "res://tools/caves/check_magma_lake_candidate.gd"
const Production=preload("res://scripts/caves/magma_lake_chambers.gd")
const Magma=preload("res://scripts/caves/magma_features.gd")
func lake_provider():return Production
func output_name()->String:return "check_cave_magma_lake_adoption"
func preflight(region:Dictionary,height:Callable,controls:Dictionary,context,result:Dictionary)->void:
	check(var_to_bytes(Candidate.prepare(region,height,73921,controls,400,10,context))==var_to_bytes(result),"Adopted bounded geometry exactly matches independent private validated profile")
	for family:int in [6,7]:
		var biological:Dictionary=region.duplicate(true);biological.cave_family=family;check(var_to_bytes(Production.prepare(biological,height,73921,controls,400,10,context))==var_to_bytes(biological),"Biological ownership excludes generic large magma banks")
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");check(definition.feature_configuration.large_lake_chambers and definition.feature_configuration.large_lake_chance==.08,"Normal saved large-lake chance remains8percent")
	var deposits:Dictionary=region.duplicate(true);deposits["cave_floor_relief"]={"magma":.45}
	var deposited:Dictionary=Production.prepare(deposits,height,73921,controls,400,10,context)
	check(deposited.pools[0].get("magma_large_lake",false),"Large profile validates actual material assignment when physical deposit marker is present")
	var deposited_field=Field.new();deposited_field.include_surface_air=false
	check(deposited_field.compile([deposited],height,[],deposited.cave_biome_regions) and Production.dry_bank(deposited_field,deposited.pools[0]),"Entire192-probe dry rim stays clear with production deposits active")
func additional_features(parent:Node3D,field,key:Vector3i,region:Dictionary)->int:
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");var payload:Dictionary=Magma.new().build(field,key,73921,[region],definition.feature_configuration,{})
	check(payload.valid,"Full production bank basalt generator accepted")
	for batch:Dictionary in payload.batches:batch["biome_id"]="magma"
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);check(Renderer.attach(parent,payload.batches,config.biome_regions,false,true),"Actual native basalt/obsidian/lava renderer and matching formation collision installed on bank")
	return payload.placements.size()
