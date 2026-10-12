extends SceneTree
## Finite, irregular buttresses and interrupted shelves; baked once, not per chunk.
const SIZE:=512
var forms: Array[Vector4]=[]
var shelves: Array[Vector4]=[]

func shape(p: Vector2) -> Color:
	var body:=0.0
	var ledge:=0.0
	for f in forms:
		var d:=p-Vector2(f.x,f.y)
		d-=Vector2(roundf(d.x),roundf(d.y))
		var q:=Vector2((d.x+d.y*0.23)/f.z,d.y/f.w)
		# Broad, asymmetric rock shoulder; no cellular tessellation.
		body=maxf(body,pow(maxf(0.0,1.0-q.length_squared()),2.0))
	for s in shelves:
		var d:=p-Vector2(s.x,s.y)
		d-=Vector2(roundf(d.x),roundf(d.y))
		var end:=maxf(0.0,1.0-pow(d.x/s.z,2.0))
		var h:=d.y-d.x*s.w-d.x*d.x*0.6
		# Asymmetric shelf lip and recessed underside, tapered at both ends.
		ledge+=end*end*(exp(-pow((h-0.012)/0.022,2.0))*0.55-exp(-pow((h+0.017)/0.011,2.0))*0.35)
	return Color(body,ledge,clampf(-ledge*2.0,0,1),clampf(ledge,0,1))

func _initialize() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=816394
	for i in range(11): forms.append(Vector4(rng.randf(),rng.randf(),rng.randf_range(0.045,0.16),rng.randf_range(0.065,0.24)))
	for i in range(13): shelves.append(Vector4(rng.randf(),rng.randf(),rng.randf_range(0.07,0.26),rng.randf_range(-0.48,0.4)))
	var heights:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBAH)
	for y in range(SIZE):
		for x in range(SIZE): heights.set_pixel(x,y,shape(Vector2(x,y)/SIZE))
	var slopes:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBAH)
	for y in range(SIZE):
		for x in range(SIZE):
			var dx:=(heights.get_pixel(posmod(x+1,SIZE),y)-heights.get_pixel(posmod(x-1,SIZE),y))*SIZE*0.5
			var dy:=(heights.get_pixel(x,posmod(y+1,SIZE))-heights.get_pixel(x,posmod(y-1,SIZE)))*SIZE*0.5
			slopes.set_pixel(x,y,Color(dx.r,dy.r,dx.g,dy.g))
	for entry in [[heights,"cliff_landforms"],[slopes,"cliff_landform_slopes"]]:
		var data: Image=entry[0]
		data.generate_mipmaps()
		assert(ResourceSaver.save(ImageTexture.create_from_image(data),"res://materials/"+entry[1]+".res")==OK)
	print("PASS finite cliff buttress/shelf assets")
	quit()
