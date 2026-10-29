@tool
extends Resource
@export var enabled:bool=true
@export var definitions:Array[Resource]=[preload("res://config/caves/biomes/default_cave_definition.tres")]
@export var fallback_biome_id:StringName=&"default"
@export var depth_bands:PackedFloat32Array=PackedFloat32Array([0,40,100,180,280,400])
func discovery_halo()->int:
	if enabled:
		for definition:Resource in definitions:
			if definition!=null and definition.enabled and definition.spawn_chance_percent>0 and definition.maximum_extent_metres>1536:return 2
	return 1
func validation_errors()->Array[String]:
	var errors:Array[String]=[];var ids:Dictionary={};var fallback:bool=false
	if definitions.is_empty() or definitions.size()>16:errors.append("Registry requires1–16definitions")
	if depth_bands.size()!=6:errors.append("Depth bands require six ordered boundaries")
	else:
		for i in range(6):
			if not is_finite(depth_bands[i]) or (i>0 and depth_bands[i]<=depth_bands[i-1]):errors.append("Depth bands must be finite and strictly increasing")
		if depth_bands[0]!=0:errors.append("Depth bands begin at the real terrain surface")
	for definition:Resource in definitions:
		if definition==null or not definition.has_method("validation_errors"):errors.append("Invalid cave biome definition");continue
		errors.append_array(definition.validation_errors())
		if ids.has(definition.biome_id):errors.append("Duplicate cave biome ID "+str(definition.biome_id))
		ids[definition.biome_id]=true
		if definition.biome_id==fallback_biome_id and definition.enabled:fallback=true
	if not fallback:errors.append("An enabled Default fallback is required;unassigned cave air never disappears")
	return errors
