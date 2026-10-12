extends SceneTree
## Sparse structural recesses with deliberately large quiet faces.
const SIZE:=1024
var rock:=FastNoiseLite.new()
var rng:=RandomNumberGenerator.new()
var map: Image

func periodic(p: Vector2) -> float:
	var f:=p/float(SIZE)
	return lerpf(lerpf(rock.get_noise_2d(p.x,p.y),rock.get_noise_2d(p.x-SIZE,p.y),f.x),lerpf(rock.get_noise_2d(p.x,p.y-SIZE),rock.get_noise_2d(p.x-SIZE,p.y-SIZE),f.x),f.y)

func carve(a: Vector2,b: Vector2,wa: float,wb: float,depth: float,channel: int) -> void:
	var radius:=maxf(wa,wb)*2.0+2
	var start:=Vector2i((a.min(b)-Vector2.ONE*radius).floor())
	var end:=Vector2i((a.max(b)+Vector2.ONE*radius).ceil())
	var delta:=b-a
	for y in range(start.y,end.y+1):
		for x in range(start.x,end.x+1):
			var p:=Vector2(x,y)
			var t:=clampf((p-a).dot(delta)/maxf(delta.length_squared(),0.01),0,1)
			var width:=maxf(0.5,lerpf(wa,wb,t))
			var d:=p.distance_to(a+delta*t)/width
			# Broad concave banks, not a thin black core.
			var value:=(1.0-smoothstep(0.0,1.8,d))*depth
			if value<0.001: continue
			var pixel:=Vector2i(posmod(x,SIZE),posmod(y,SIZE))
			var c:=map.get_pixelv(pixel)
			c[channel]=maxf(c[channel],value)
			map.set_pixelv(pixel,c)

func seam(origin: Vector2,direction: float,length: float,width: float,depth: float,channel: int) -> void:
	var p:=origin
	var count:=maxi(5,int(length/45))
	var heading:=direction
	for i in range(count):
		var t:=float(i)/count
		var next_t:=float(i+1)/count
		heading=lerpf(heading,direction,0.4)+rng.randf_range(-0.12,0.12)
		var next:=p+Vector2.from_angle(heading)*length/count
		var taper_a:=pow(maxf(0.0,4*t*(1-t)),0.55)
		var taper_b:=pow(maxf(0.0,4*next_t*(1-next_t)),0.55)
		carve(p,next,width*taper_a,width*taper_b,depth,channel)
		p=next

func _initialize() -> void:
	rng.seed=891240
	rock.seed=91732
	rock.frequency=0.002
	rock.fractal_octaves=1
	map=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBAH)
	for y in range(SIZE):
		for x in range(SIZE):
			var broad:=periodic(Vector2(x,y))
			map.set_pixel(x,y,Color(0.56+broad*0.045,0,broad*0.5+0.5,0))
	# Related joint family; origins, extent and depth are independent.
	for i in range(9):
		var p:=Vector2(rng.randf()*SIZE,rng.randf()*SIZE)
		var angle:=rng.randf_range(-1.85,-1.25)
		var extent:=rng.randf_range(170,490)
		seam(p,angle,extent,rng.randf_range(14,30),rng.randf_range(0.45,0.95),1)
		if i%3==0:
			seam(p+Vector2.from_angle(angle)*extent*0.45,angle+0.7,extent*0.38,9,0.35,1)
	# Few incomplete cross breaks; no enclosed rectangular primitives.
	for i in range(4):
		seam(Vector2(rng.randf()*SIZE,rng.randf()*SIZE),rng.randf_range(-0.25,0.3),rng.randf_range(130,310),rng.randf_range(8,15),rng.randf_range(0.3,0.7),3)
	var quiet:=0
	for y in range(SIZE):
		for x in range(SIZE):
			var c:=map.get_pixel(x,y)
			c.r-=c.g*0.27+c.a*0.16
			if maxf(c.g,c.a)<0.08: quiet+=1
			map.set_pixel(x,y,c)
	var quiet_fraction:=float(quiet)/(SIZE*SIZE)
	assert(quiet_fraction>0.65,"Structural coverage became too dense")
	var slopes:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGH)
	for y in range(SIZE):
		for x in range(SIZE):
			var dx:=(map.get_pixel(posmod(x+2,SIZE),y).r-map.get_pixel(posmod(x-2,SIZE),y).r)*SIZE/4.0
			var dy:=(map.get_pixel(x,posmod(y+2,SIZE)).r-map.get_pixel(x,posmod(y-2,SIZE)).r)*SIZE/4.0
			slopes.set_pixel(x,y,Color(dx,dy,0,1))
	for entry in [[map,"cliff_geology"],[slopes,"cliff_geology_slopes"]]:
		var img: Image=entry[0]
		img.generate_mipmaps()
		assert(ResourceSaver.save(ImageTexture.create_from_image(img),"res://materials/"+entry[1]+".res")==OK)
	var preview:=map.duplicate()
	preview.convert(Image.FORMAT_RGBA8)
	preview.save_png("res://materials/cliff_geology.png")
	print("PASS sparse geology; quiet coverage=",quiet_fraction)
	quit()
