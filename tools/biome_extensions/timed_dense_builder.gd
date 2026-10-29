extends "res://tools/biome_extensions/height_cache_builder_candidate.gd"
var canonical_calls:int=0
var canonical_us:int=0
var support_calls:int=0
var support_us:int=0
func _get_height(x:float,z:float,publish:bool=true)->float:
	var start:int=Time.get_ticks_usec();var value:float=super._get_height(x,z,publish);canonical_calls+=1;canonical_us+=Time.get_ticks_usec()-start;return value
func _sample_normal_height(x:float,z:float)->float:
	var start:int=Time.get_ticks_usec();var value:float=super._sample_normal_height(x,z);support_calls+=1;support_us+=Time.get_ticks_usec()-start;return value
