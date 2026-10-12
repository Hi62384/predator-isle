extends SceneTree
## Offline path rasterizer. No periodic functions create visible fractures.
const SIZE:=2048
var rng:=RandomNumberGenerator.new()
var mask: Image
var paths: Array=[]

func stroke(a: Vector2,b: Vector2,width_a: float,width_b: float,depth: float,channel: int) -> void:
	var margin:=maxf(width_a,width_b)*2.8+2.0
	var start: Vector2i=Vector2i((a.min(b)-Vector2.ONE*margin).floor())
	var end: Vector2i=Vector2i((a.max(b)+Vector2.ONE*margin).ceil())
	var delta:=b-a
	for y in range(start.y,end.y+1):
		for x in range(start.x,end.x+1):
			var p:=Vector2(x,y)
			var t:=clampf((p-a).dot(delta)/maxf(delta.length_squared(),0.001),0,1)
			var distance:=p.distance_to(a+delta*t)
			var width:=maxf(0.3,lerpf(width_a,width_b,t))
			var value: float=(1.0-smoothstep(width*0.18,width*2.6,distance))*depth
			if value<0.003: continue
			var pixel:=Vector2i(posmod(x,SIZE),posmod(y,SIZE))
			var color:=mask.get_pixelv(pixel)
			color[channel]=maxf(color[channel],value)
			mask.set_pixelv(pixel,color)

func path(origin: Vector2,angle: float,length: float,width: float,depth: float,level: int,channel: int=0) -> PackedVector2Array:
	var vertices:=PackedVector2Array([origin])
	var segments:=maxi(4,int(length/35.0))
	var p:=origin
	var direction:=angle
	for i in range(segments):
		var t:=float(i)/segments
		direction=lerpf(direction,angle,0.25)+rng.randf_range(-0.22,0.22)
		var next:=p+Vector2.from_angle(direction)*length/segments
		var wa:=width*pow(1.0-t,0.65)*rng.randf_range(0.65,1.25)
		var wb:=width*pow(1.0-float(i+1)/segments,0.65)
		# Some fractures vanish behind ledges before reappearing.
		if rng.randf()>0.06: stroke(p,next,wa,wb,depth,channel)
		if level<2 and i>0 and i<segments-2 and rng.randf()<0.16:
			path(p,direction+rng.randf_range(0.45,1.15)*(-1 if rng.randf()<0.5 else 1),length*rng.randf_range(0.18,0.40),width*0.42,depth*0.64,level+1,channel)
		p=next;vertices.append(p)
	paths.append(vertices)
	return vertices

func _initialize() -> void:
	for variant in range(3):
		rng.seed=87131+variant*9173
		mask=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
		mask.fill(Color(0,0,0,0))
		paths.clear()
		for cluster in range(5):
			var center:=Vector2(rng.randf()*SIZE,rng.randf()*SIZE)
			var major: Array=[]
			for j in range(rng.randi_range(2,5)):
				var origin:=center+Vector2(rng.randfn(0,150),rng.randfn(0,160))
				var angle:=rng.randf_range(0.65,2.45)
				major.append(path(origin,angle,rng.randf_range(240,850),rng.randf_range(8.0,18.0),rng.randf_range(0.55,0.95),0))
			# Cross joints explicitly connect existing networks into rock blocks.
			for j in range(major.size()-1):
				var a: Vector2=major[j][rng.randi_range(1,major[j].size()-1)]
				var b: Vector2=major[j+1][rng.randi_range(1,major[j+1].size()-1)]
				stroke(a,a.lerp(b,0.5)+Vector2(0,rng.randf_range(-50,50)),2.3,1.6,0.4,0)
				stroke(a.lerp(b,0.5)+Vector2(0,12),b,1.6,0.5,0.3,0)
			for j in range(3):
				path(center+Vector2(rng.randfn(0,100),rng.randfn(0,140)),rng.randf_range(1.25,1.85),rng.randf_range(90,450),rng.randf_range(6,17),rng.randf_range(0.15,0.5),2,1)
			path(center,rng.randf_range(-0.35,0.35),rng.randf_range(120,370),rng.randf_range(2,5),0.5,2,2)
		mask.save_png("res://materials/fracture_network_%d.png" % variant)
		mask.generate_mipmaps()
		assert(mask.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		assert(ResourceSaver.save(ImageTexture.create_from_image(mask),"res://materials/fracture_network_%d.res" % variant)==OK)
		print("FRACTURE variant ",variant," finite paths=",paths.size())
	quit()
