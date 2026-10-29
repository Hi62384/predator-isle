extends SceneTree
## Import/packing only. Creative bitmap changes belong to image generation.
const SOURCE="res://tools/biome_extensions/experiments/nerve_film_v3_albedo.png"
const OUTPUT="res://materials/biological_color_nerve_v3.res"
func _initialize()->void:
	var ingress=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_nerve_film_input.json"));assert(ingress.passed)
	assert(FileAccess.get_sha256(SOURCE)==ingress.source_sha256[SOURCE])
	var image:=Image.load_from_file(SOURCE);assert(image!=null)
	image.convert(Image.FORMAT_RGB8);image.resize(2048,2048,Image.INTERPOLATE_LANCZOS);assert(image.generate_mipmaps()==OK)
	var expected:Image=image.duplicate();assert(image.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGB)==OK)
	assert(image.get_format()==Image.FORMAT_DXT1 and image.has_mipmaps() and image.get_data_size()==2796216)
	var decoded:Image=image.duplicate();assert(decoded.decompress()==OK)
	var sum_error:float=0;var maximum:float=0;var count:int=0
	for y in range(0,2048,3):
		for x in range(0,2048,3):
			var a:Color=expected.get_pixel(x,y);var b:Color=decoded.get_pixel(x,y)
			var error:float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			maximum=maxf(maximum,error);sum_error+=error;count+=1
	# Predeclared compression-loss bounds, not an artistic quality certificate.
	assert(maximum<=.25 and sum_error/count<=.035)
	if FileAccess.file_exists(OUTPUT):
		var original:Image=load(OUTPUT);assert(original.get_data()==image.get_data(),"Never overwrite a different existing packed asset")
	else:assert(ResourceSaver.save(image,OUTPUT)==OK)
	var hashes:Dictionary={}
	for path:String in [SOURCE,OUTPUT,"res://materials/biological_colors_v3.tres","res://tools/biome_extensions/experiments/nerve_film_v3_provenance.json","res://tools/biome_extensions/build_nerve_film_material.gd","res://tools/biome_extensions/artifacts/check_nerve_film_input.json"]:hashes[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/build_nerve_film_material.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":hashes,"production_registration":false,"native_dimensions":[1254,1254],"packed_dimensions":[2048,2048],"packed_bytes":image.get_data_size(),"samples":count,"maximum_channel_error":maximum,"mean_maximum_channel_error":sum_error/count,"scope":"Private image import: Lanczos resizing, RGB BC1 mipmapped packing with predeclared sampled compression-loss bounds. Old resources untouched. No generated native 2K detail, art acceptance or runtime adoption."},"  "))
	print("NERVE_FILM_PACKED ",image.get_data_size()," bytes; mean/max sampled error ",sum_error/count," / ",maximum);quit()
