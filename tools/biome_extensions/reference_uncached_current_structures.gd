extends "res://scripts/biome_extension_structures.gd"
## Current morphology with the exact uncached conduit path, not a historical
## morphology golden. Leave any caller's numerical cache metadata untouched.
func build(builder,coordinate:Vector2i,support_steps:PackedFloat64Array=PackedFloat64Array(),portal_provider:Callable=Callable())->Array:
	conduit_cache_enabled=false
	var had_memo:bool=builder.has_meta(CONDUIT_MEMO_KEY);var saved=builder.get_meta(CONDUIT_MEMO_KEY) if had_memo else {}
	var result:Array=super.build(builder,coordinate,support_steps,portal_provider)
	if had_memo:builder.set_meta(CONDUIT_MEMO_KEY,saved)
	return result
