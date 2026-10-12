extends SceneTree
func _initialize() -> void:
	var script=load("res://scripts/terrain_mesh_builder.gd")
	var builder=script.new();builder._configure_noise()
	for level in range(1,7):
		builder.chunk_size=256.0*float(1<<level)
		var parent: Array=builder.build(Vector2i(-1,0),16)
		builder.chunk_size/=2.0
		var child: Array=builder.build(Vector2i(-2,0),16)
		for z in range(9):
			for x in range(9):
				var a:=z*17+x;var b:=z*2*17+x*2
				assert(is_equal_approx(parent[Mesh.ARRAY_VERTEX][a].y,child[Mesh.ARRAY_VERTEX][b].y))
				assert(parent[Mesh.ARRAY_NORMAL][a].is_equal_approx(child[Mesh.ARRAY_NORMAL][b]))
				assert(parent[Mesh.ARRAY_TEX_UV2][a].is_equal_approx(child[Mesh.ARRAY_TEX_UV2][b]))
		print("PASS shared parent/child height, normal, surface level ",level)
	quit()
