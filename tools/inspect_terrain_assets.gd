extends SceneTree

func _initialize() -> void:
	for asset in ["Rock030", "Grass001", "Ground054", "Ground037", "Ground048", "Gravel020", "Rock035", "Rock034", "Rock028"]:
		var path := "res://assets/textures/ambientcg/%s/%s_2K-JPG_Color.jpg" % [asset,asset]
		var source := Image.load_from_file(path)
		source.resize(512,512,Image.INTERPOLATE_LANCZOS)
		source.save_png("res://tools/"+asset+"_preview.png")
	quit()
