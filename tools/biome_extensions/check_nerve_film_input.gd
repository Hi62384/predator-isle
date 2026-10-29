extends SceneTree
const SOURCE="res://tools/biome_extensions/experiments/nerve_film_v3_albedo.png"
func delta(a:Color,b:Color)->float:return (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3
func _initialize()->void:
	var hashes:Dictionary={}
	for path:String in [SOURCE,"res://tools/biome_extensions/experiments/nerve_film_v3_provenance.json","res://tools/biome_extensions/check_nerve_film_input.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var image:Image=Image.load_from_file(SOURCE);assert(image!=null)
	var width:int=image.get_width();var height:int=image.get_height();var horizontal:float=0;var vertical:float=0;var interior_x:float=0;var interior_y:float=0;var opaque:bool=true
	for y in range(height):
		horizontal+=delta(image.get_pixel(0,y),image.get_pixel(width-1,y))
		for station:int in [1,3,7,11,17,23,31]:
			var x:int=station*width/37;interior_x+=delta(image.get_pixel(x,y),image.get_pixel(x+1,y))/7
		if image.get_pixel(0,y).a<.999 or image.get_pixel(width-1,y).a<.999:opaque=false
	for x in range(width):
		vertical+=delta(image.get_pixel(x,0),image.get_pixel(x,height-1))
		for station:int in [1,3,7,11,17,23,31]:
			var y:int=station*height/37;interior_y+=delta(image.get_pixel(x,y),image.get_pixel(x,y+1))/7
		if image.get_pixel(x,0).a<.999 or image.get_pixel(x,height-1).a<.999:opaque=false
	horizontal/=height;vertical/=width;interior_x/=height;interior_y/=width
	var ratio_x:float=horizontal/maxf(interior_x,.000001);var ratio_y:float=vertical/maxf(interior_y,.000001)
	# Predeclared before measuring: wrap-edge mean colour jumps may be at most
	# twice the corresponding sampled interior adjacent-pixel mean jump.
	var failures:Array=[]
	if width!=height or width<1024:failures.append("Square source at least 1024 pixels required")
	if not opaque:failures.append("Opaque border required")
	if ratio_x>2 or ratio_y>2:failures.append("Generated texture fails predeclared two-times-interior mean wrap-edge jump criterion")
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/check_nerve_film_input.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"width":width,"height":height,"horizontal_mean_edge_jump":horizontal,"vertical_mean_edge_jump":vertical,"horizontal_mean_interior_jump":interior_x,"vertical_mean_interior_jump":interior_y,"horizontal_edge_ratio":ratio_x,"vertical_edge_ratio":ratio_y,"production_adoption":false,"scope":"Private generated-image ingress check, source resolution and border opacity plus predeclared wrap-edge jump criterion. AI appearance is not a photoscan, normal/height map or photometric material measurement. This does not certify all perceptual repetition, actual game rendering or adoption."},"  "))
	print("NERVE_FILM_INPUT width=",width," edge_ratios=",Vector2(ratio_x,ratio_y)," failures=",failures);quit(0 if failures.is_empty() else 1)
