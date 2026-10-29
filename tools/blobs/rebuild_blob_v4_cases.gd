extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Batch=preload("res://tools/blobs/build_blob_v4_batch.gd")
func _initialize()->void:
	for index in [5,23]:
		var data:=Pipeline.new().build(5100+index,0,"auto",7,null,Batch.settings(index))
		if data.has("error"):print(data);quit(1);return
		var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%index,FileAccess.WRITE);f.store_var(data);f.close()
		print("REGENERATED ",index," ",data.mesh_integrity)
	quit()
