extends RefCounted
## Tests use independent registry copies,never mutate the cached saved
## resource and never add duplicate definitions after world registration.
static func guards()->Dictionary:
	var result:Dictionary={}
	for path:String in ["res://tools/caves/frozen_fixture.gd","res://config/caves/cave_biome_regions.tres"]:result[path]=FileAccess.get_sha256(path)
	return result
static func registry(original:Resource,definition:Resource)->Resource:
	var result:Resource=original.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for index in range(result.definitions.size()):
		if result.definitions[index].biome_id==definition.biome_id:result.definitions[index]=definition;return result
	result.definitions.append(definition);return result
