extends "res://tools/caves/index_magma_sources.gd"
func allow_intrusive_sources()->bool:return true
func source_report_name()->String:return "check_cave_magma_intrusive_source_index"+("_"+str(source_seed()) if source_seed()!=73921 else "")
