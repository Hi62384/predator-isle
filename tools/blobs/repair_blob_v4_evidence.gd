extends SceneTree
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
func _initialize()->void:
	for name in DirAccess.open("res://.godot/blob_validation_v4_release").get_files():
		if not name.ends_with(".bin"):continue
		var index:String=name
		var path:String="res://.godot/blob_validation_v4_release/"+name
		var f:=FileAccess.open(path,FileAccess.READ);var data:Dictionary=f.get_var(false);f.close()
		var triangles:int=data.body.indices.size()/3;var vertices:int=data.body.vertices.size()
		var old:Dictionary=data.mesh_integrity
		data.mesh_integrity=Integrity.clean(data.body,true);data.mesh_integrity["previous_cleanup"]=old
		data.statistics.triangles+=data.body.indices.size()/3-triangles;data.statistics.vertices+=data.body.vertices.size()-vertices
		f=FileAccess.open(path,FileAccess.WRITE);f.store_var(data);f.close()
		print("REPAIRED ",index," faces_removed=",triangles-data.body.indices.size()/3," closed=",data.mesh_integrity.boundary_edges==0," nonmanifold=",data.mesh_integrity.nonmanifold_edges)
	quit()
