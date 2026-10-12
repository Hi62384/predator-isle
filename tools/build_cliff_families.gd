extends SceneTree
## Independent reusable height families. Composition happens in the material.
const SIZE:=512
var noise:=FastNoiseLite.new()

func field(x: float,y: float,sx: float,sy: float) -> float:
	var u:=x/SIZE;var v:=y/SIZE
	return lerpf(lerpf(noise.get_noise_2d(x*sx,y*sy),noise.get_noise_2d((x-SIZE)*sx,y*sy),u),lerpf(noise.get_noise_2d(x*sx,(y-SIZE)*sy),noise.get_noise_2d((x-SIZE)*sx,(y-SIZE)*sy),u),v)

func _initialize() -> void:
	noise.seed=327183
	noise.frequency=0.009
	noise.fractal_octaves=2
	var heights:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBAH)
	for y in range(SIZE):
		for x in range(SIZE):
			var body:=field(x,y,0.8,0.45)
			var joint:=field(x,y,1.6,0.6)
			var cross_joint:=field(x,y,0.55,1.7)
			# Broad rib/body; intersecting angular break families; local pits.
			var mass:=body*0.35+0.5
			var slab:=0.58-absf(joint)*0.45-absf(cross_joint)*0.28
			var pits:=pow(maxf(0.0,field(x,y,5,4)+0.15),2.0)
			heights.set_pixel(x,y,Color(mass,slab,pits,0.5+field(x,y,0.7,0.7)*0.5))
	var slopes_a:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBAH)
	var slopes_b:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGH)
	for y in range(SIZE):
		for x in range(SIZE):
			var left:=heights.get_pixel(posmod(x-1,SIZE),y)
			var right:=heights.get_pixel(posmod(x+1,SIZE),y)
			var down:=heights.get_pixel(x,posmod(y-1,SIZE))
			var up:=heights.get_pixel(x,posmod(y+1,SIZE))
			var dx:=(right-left)*SIZE*0.5
			var dy:=(up-down)*SIZE*0.5
			slopes_a.set_pixel(x,y,Color(dx.r,dy.r,dx.g,dy.g))
			slopes_b.set_pixel(x,y,Color(dx.b,dy.b,0,1))
	for entry in [[heights,"cliff_families"],[slopes_a,"cliff_family_slopes_a"],[slopes_b,"cliff_family_slopes_b"]]:
		var data: Image=entry[0]
		data.generate_mipmaps()
		assert(ResourceSaver.save(ImageTexture.create_from_image(data),"res://materials/"+entry[1]+".res")==OK)
	print("PASS independent mass/slab/pit family assets")
	quit()
