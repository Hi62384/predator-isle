extends SceneTree
func _initialize()->void:
	var guards:Dictionary={};var results:Dictionary={}
	for name:String in ["check_structure_collision_spatial","check_collision_spatial_dense","check_collision_blocks_bounded_real"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json"
		var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty())
		guards[path]=FileAccess.get_sha256(path)
		for source:String in report.get("source_sha256",{}):
			assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale private evidence "+source);guards[source]=report.source_sha256[source]
		results[name]={"checks":report.get("checks",null),"scope":report.get("scope",null)}
	for name:String in ["structure_collision_blocks_candidate","structure_collision_blocks_bounded_candidate","structure_collision_spatial_candidate","check_structure_collision_spatial","check_collision_spatial_dense","check_collision_blocks_bounded_real","check_structure_collision_blocks_real","check_structure_collision_blocks_dense","save_collision_index_trial"]:
		var path:String="res://tools/biome_extensions/"+name+".gd";guards[path]=FileAccess.get_sha256(path)
	var result:Dictionary={"passed":true,"failures":[],"source_sha256":guards,"results":results,"production_registration":false,"scope":"Private numeric and native collision study. Original contiguous blocks selected conservatively around a whole256m cell plus600m guard. Six real extremal blocks preserve whole-mesh quantization bounds;no dummy geometry. Spatial selection exactly matches prior bounds-preserving scan. Dense original363736triangles become13120;166native contacts and normals exactly agree. Original three default-rarity junctions plus same-root16km parent also match native contacts/normals. Numeric metadata174828bytes excluding object overhead;dense selection0.686ms/index169.131ms,one order full/subset setup693.623/22.188ms;not repeated or end-to-end performance claim. Initial unbounded trial shifted normals;retained as a limitation,not adopted. No production/streamed capsule/motion acceptance yet. Watcher peaks of latest spatial runs not retained,not invented."}
	FileAccess.open("res://tools/biome_extensions/artifacts/collision_index_trial.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("COLLISION_INDEX_TRIAL ",guards.size()," guards");quit()
