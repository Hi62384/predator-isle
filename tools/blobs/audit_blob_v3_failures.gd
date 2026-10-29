extends SceneTree
const Solver=preload("res://tools/blobs/legacy_v3_surface.gd")
func _initialize()->void: call_deferred("run")
func run()->void:
	var rows:Array=[]
	for index in [0,2,4,11]:
		var f:=FileAccess.open("res://.godot/blob_validation_v3/model_%02d.bin"%index,FileAccess.READ); var data:Dictionary=f.get_var(false); f.close()
		var solver:=Solver.new(); solver.configure(data.dna,data.rig,data.body)
		var extreme:=0; var maximum:=1.0; var collapsed:=0
		for frame in 12:
			solver.circulation=TAU*float(frame)/12; solver._update_groups(.0); solver._update_volume()
			var vertices:=PackedVector3Array()
			for i in data.body.vertices.size(): vertices.append(solver.map_bound(data.body.vertices[i],int(data.body.binds[i*4])-1,float(data.body.binds[i*4+1])))
			for i in range(0,data.body.indices.size(),3):
				var a:int=data.body.indices[i]; var b:int=data.body.indices[i+1]; var c:int=data.body.indices[i+2]
				for edge in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
					var ratio:float=vertices[edge.x].distance_to(vertices[edge.y])/maxf(data.body.vertices[edge.x].distance_to(data.body.vertices[edge.y]),.000001)
					maximum=maxf(maximum,ratio)
					if ratio>4: extreme+=1
				var rest:float=(data.body.vertices[b]-data.body.vertices[a]).cross(data.body.vertices[c]-data.body.vertices[a]).length()
				if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length()<rest*.02: collapsed+=1
		rows.append({"seed":data.dna.seed,"maximum_edge_stretch":maximum,"edges_over_4x":extreme,"triangles_below_2percent_area":collapsed}); print(rows[-1])
	DirAccess.make_dir_recursive_absolute("res://data/blobs_v4")
	var file:=FileAccess.open("res://data/blobs_v4/v3_failure_audit.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows,"\t")); file.close(); quit()
