extends RefCounted
## Numeric-only dispatch on the existing cave worker. Providers cannot create
## scene nodes, textures, or physics objects. Empty registries keep old payloads.
const MAX_VERTICES:int=240000
static func decorate(region:Dictionary,configuration:Resource,seed_id:int,height:Callable,thermal_context=null)->Dictionary:
	if configuration==null or not configuration.biome_regions.enabled:return region
	for definition:Resource in configuration.biome_regions.definitions:
		if not definition.enabled or definition.feature_provider==null:continue
		var provider=definition.feature_provider.new()
		if provider.has_method("decorate_region_with_context"):region=provider.decorate_region_with_context(region,height,seed_id,definition.feature_configuration,configuration.maximum_depth_metres,configuration.minimum_rock_cover_metres,thermal_context)
		elif provider.has_method("decorate_region"):region=provider.decorate_region(region,height,seed_id,definition.feature_configuration,configuration.maximum_depth_metres,configuration.minimum_rock_cover_metres)
	if thermal_context!=null:region=thermal_context.annotate_region(region)
	return region
static func build(field,key:Vector3i,seed_id:int,regions:Array,registry:Resource,water:Dictionary)->Dictionary:
	var batches:Array=[];var count:int=0
	if registry==null or not registry.enabled:return {"valid":true,"batches":batches}
	var ids:Array=field.biome_ids_for_cell(key)
	for definition:Resource in registry.definitions:
		if not definition.enabled or definition.feature_provider==null or not ids.has(str(definition.biome_id)):continue
		var result:Dictionary=definition.feature_provider.new().build(field,key,seed_id,regions,definition.feature_configuration,water)
		if not result.get("valid",false):return {"valid":false,"reason":result.get("reason","Invalid cave biome feature result"),"batches":[]}
		for batch:Dictionary in result.get("batches",[]):
			count+=batch.arrays[Mesh.ARRAY_VERTEX].size()
			if count>MAX_VERTICES:return {"valid":false,"reason":"Cave biome feature vertex bound exceeded","batches":[]}
			batch["biome_id"]=str(definition.biome_id);batches.append(batch)
	return {"valid":true,"batches":batches}
