extends "res://tools/caves/render_magma_world.gd"
func index_path()->String:return "res://tools/biome_extensions/artifacts/check_cave_magma_intrusive_source_index_17.json"
func selected_case(catalogue:Dictionary)->Dictionary:
	var row:Dictionary=catalogue.first_molten
	if row.is_empty():return {}
	var ordinal:int=-1
	for index in range(catalogue.rows.size()):
		if catalogue.rows[index].site==row.site:ordinal=index;break
	return {"ordinal":ordinal,"host":"volcanic","seed":int(catalogue.seed),"site":row.site,"rooms":[{"room":{"id":str(row.molten_pools[0].id).trim_suffix(":seepage")}}],"pool_id":row.molten_pools[0].id}
func selected_pool_id(selected:Dictionary)->String:return selected.pool_id
func report_basename()->String:return "render_cave_magma_intrusive_world"
func capture_prefix()->String:return "magma_intrusive_world"
func visibility_prefix()->String:return "CaveBiome_magma_molten_volcanic"
func requires_cooled_forms()->bool:return false
func scope_description()->String:return "Exact FIRST normal source-backed molten pool from full fixed17seed/97x97source-grid/unique3x3cave-neighbour catalogue,all negatives retained. First declared seed in six-seed continuation;remaining seeds are separate inventory validation. Explicit modeled intrusive body OR actual retained surface source is identified in pool metadata;normal22percent biome/4percent active source/14percent molten controls unchanged. Actual neighbouring compiled field/native clipped lava material/collision/frontiers,original environment/test-only lamp,pool-only geometry-off/exactreturn. Lava clock frozen only in diagnostic engine for pixels;original connected60m passage prefix return. Not full live Magma return,FPS,reference art or all-user completion."
