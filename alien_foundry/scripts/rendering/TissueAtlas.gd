class_name TissueAtlas
extends RefCounted
## Packed-only structured tissue bake. One job-local field shared by every
## material, rather than repeated 3-D hashes and periodic stripes per fragment.
## tone RGBA = pigmentation / vessel core / soft vascular halo / wetness.
## relief RGBA = biased fine height / short creases / fibre exposure / pore pits.
## structure RGBA = overlapping plate seams / raised lamellae / cartilage grain / mineral inclusions.
const MAX_RESOLUTION: int = 512
var resolution: int = 512
var rng := RandomNumberGenerator.new()
var controls: RefCounted
var vessels := PackedFloat32Array()
var halos := PackedFloat32Array()
var fibres := PackedFloat32Array()
var fibre_regions := PackedFloat32Array()
var creases := PackedFloat32Array()
var pores := PackedFloat32Array()
var plate_seams := PackedFloat32Array()
var plate_ridges := PackedFloat32Array()
var segment_count: int = 0
var seed_value: int = 0

func build(dna: Dictionary, job: RefCounted = null, requested_resolution: int = 512) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	resolution = clampi(requested_resolution, 64, MAX_RESOLUTION)
	controls = job
	seed_value = int(dna.get("seed", 0))
	segment_count = 0
	rng.seed = seed_value ^ 0x3da19625
	var count: int = resolution * resolution
	vessels.resize(count); halos.resize(count); fibres.resize(count)
	fibre_regions.resize(count); creases.resize(count); pores.resize(count)
	plate_seams.resize(count); plate_ridges.resize(count)
	vessels.fill(0.0); halos.fill(0.0); fibres.fill(0.0)
	fibre_regions.fill(0.0); creases.fill(0.0); pores.fill(0.0)
	plate_seams.fill(0.0); plate_ridges.fill(0.0)
	var scale: float = float(resolution) / 512.0
	for tree: int in range(5):
		if _cancelled(): return {"cancelled": true}
		var origin := Vector2(rng.randf_range(0.0,resolution),rng.randf_range(0.0,resolution))
		var angle: float = PI * 0.5 + rng.randf_range(-1.1,1.1)
		if tree % 3 == 0: angle += PI
		_grow_vessel(origin,angle,rng.randf_range(180.0,260.0)*scale,rng.randf_range(4.5,6.5)*scale,0.76,0)
	# Local, discontinuous fibril groups, not globally repeated parallel bands.
	for bundle: int in range(34):
		if _cancelled(): return {"cancelled": true}
		var center := Vector2(rng.randf_range(0.0,resolution),rng.randf_range(0.0,resolution))
		var angle: float = PI * 0.5 + rng.randf_range(-0.16,0.16)
		var direction := Vector2(cos(angle),sin(angle))
		var side := direction.orthogonal()
		var length_value: float = rng.randf_range(90.0,190.0)*scale
		var bow: float = rng.randf_range(-15.0,15.0)*scale
		for strand: int in range(rng.randi_range(7,13)):
			var shift: Vector2 = side * (float(strand)-4.5) * rng.randf_range(2.0,3.8)*scale
			var a: Vector2 = center + shift - direction * length_value * rng.randf_range(0.3,0.6)
			var d: Vector2 = center + shift + direction * length_value * rng.randf_range(0.3,0.6)
			_paint_curve(a,a.lerp(d,.32)+side*bow,d.lerp(a,.32)-side*bow*.45,d,rng.randf_range(.75,1.45)*scale,0.72,1,20)
	# Short curved crease pairs. Their use is concentrated by anatomical joints.
	for fold: int in range(34):
		var center := Vector2(rng.randf_range(0.0,resolution),rng.randf_range(0.0,resolution))
		var angle: float = rng.randf_range(-PI,PI)
		var direction := Vector2(cos(angle),sin(angle))
		var side := direction.orthogonal()
		var length_value: float = rng.randf_range(13.0,43.0)*scale
		var a: Vector2 = center - direction * length_value * .5
		var d: Vector2 = center + direction * length_value * .5
		var bow: float = rng.randf_range(2.5,8.0)*scale
		_paint_curve(a,a.lerp(d,.3)+side*bow,d.lerp(a,.3)+side*bow,d,rng.randf_range(.7,1.5)*scale,.75,2,12)
	# Explicit overlapping lamellae are reserved for hardened tissue. They are
	# not the vascular field and are never applied as contour lines to skin.
	for row: int in range(6):
		if _cancelled(): return {"cancelled": true}
		for column: int in range(5):
			var center := Vector2((column + 0.5 * (row % 2)) * 102.4, row * 85.33) * scale
			center += Vector2(rng.randf_range(-15.0,15.0),rng.randf_range(-12.0,12.0))*scale
			var width: float = rng.randf_range(91.0,124.0)*scale
			var height: float = rng.randf_range(81.0,108.0)*scale
			_paint_plate(center,width,height)
	# Native noise is job-local and only used to bake broad bounded fields.
	# No mutable shared Resource, rendering call, image or Node is touched here.
	var pigment := FastNoiseLite.new()
	pigment.seed = seed_value ^ 0x12fa
	pigment.frequency = 0.008 / scale
	pigment.fractal_octaves = 3
	var wetness := FastNoiseLite.new()
	wetness.seed = seed_value ^ 0x34db
	wetness.frequency = 0.014 / scale
	wetness.fractal_octaves = 2
	var coverage := FastNoiseLite.new()
	coverage.seed = seed_value ^ 0x719e
	coverage.frequency = 0.011 / scale
	coverage.fractal_octaves = 2
	for pore: int in range(950):
		var point := Vector2(rng.randf_range(0.0,resolution),rng.randf_range(0.0,resolution))
		if coverage.get_noise_2d(point.x,point.y) < -0.13: continue
		_paint_segment(point,point+Vector2(.2,.1)*scale,rng.randf_range(.38,1.1)*scale,rng.randf_range(.38,.85)*scale,rng.randf_range(.35,.75),3)
	var tone := PackedByteArray()
	var relief := PackedByteArray()
	var structure := PackedByteArray()
	tone.resize(count*4); relief.resize(count*4); structure.resize(count*4)
	var vessel_pixels: int = 0
	var crease_pixels: int = 0
	for y: int in range(resolution):
		if y % 32 == 0 and _cancelled(): return {"cancelled": true}
		for x: int in range(resolution):
			var index: int = x + y*resolution
			var offset: int = index*4
			# Periodic four-corner blending makes coarse fields seamless too.
			var melanin: float = clampf(.5+_periodic_noise(pigment,x,y)*.9,0.0,1.0)
			var wet: float = clampf(.5+_periodic_noise(wetness,x,y)*.9,0.0,1.0)
			var exposed: float = clampf(.34+_periodic_noise(coverage,x,y)*.60+fibre_regions[index]*.60,0.0,1.0)
			tone[offset]=roundi(melanin*255.0)
			tone[offset+1]=roundi(clampf(vessels[index],0.0,1.0)*255.0)
			tone[offset+2]=roundi(clampf(halos[index],0.0,1.0)*255.0)
			tone[offset+3]=roundi(wet*255.0)
			var height_value: float = .5 + fibres[index]*.22 - pores[index]*.045
			relief[offset]=roundi(clampf(height_value,0.0,1.0)*255.0)
			relief[offset+1]=roundi(clampf(creases[index],0.0,1.0)*255.0)
			relief[offset+2]=roundi(exposed*255.0)
			relief[offset+3]=roundi(clampf(pores[index],0.0,1.0)*255.0)
			structure[offset]=roundi(clampf(plate_seams[index],0.0,1.0)*255.0)
			structure[offset+1]=roundi(clampf(plate_ridges[index],0.0,1.0)*255.0)
			# Quiet internal grain; no hard pigment patches on cartilage.
			structure[offset+2]=roundi(clampf(.5+(melanin-.5)*.26+pores[index]*.14,0.0,1.0)*255.0)
			structure[offset+3]=roundi(clampf(pores[index]*.7+plate_seams[index]*.18,0.0,1.0)*255.0)
			if vessels[index]>.12: vessel_pixels+=1
			if creases[index]>.12: crease_pixels+=1
	return {"width":resolution,"height":resolution,"tone_pixels":tone,"relief_pixels":relief,"structure_pixels":structure,"stats":{"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"segments":segment_count,"vessel_coverage":float(vessel_pixels)/count,"crease_coverage":float(crease_pixels)/count,"bytes":tone.size()+relief.size()+structure.size(),"seed":seed_value}}

func _paint_plate(center: Vector2, width: float, height: float) -> void:
	var a: Vector2 = center + Vector2(-width*.53,-height*.06)
	var d: Vector2 = center + Vector2(width*.53,-height*.06)
	_paint_curve(a,center+Vector2(-width*.48,height*.61),center+Vector2(width*.48,height*.61),d,width*.022,.8,4,24)
	for y: int in range(floori(center.y-height*.54),ceili(center.y+height*.54)+1):
		for x: int in range(floori(center.x-width*.58),ceili(center.x+width*.58)+1):
			var local := Vector2((float(x)+.5-center.x)/(width*.58),(float(y)+.5-center.y)/(height*.54))
			var radius: float = local.length()
			if radius>=1.0: continue
			var index: int=posmod(x,resolution)+posmod(y,resolution)*resolution
			var raised: float=(1.0-smoothstep(.28,1.0,radius))*(.72+local.y*.18)
			plate_ridges[index]=maxf(plate_ridges[index],raised)

func _periodic_noise(noise: FastNoiseLite, x: int, y: int) -> float:
	var fx: float = float(x)/resolution
	var fy: float = float(y)/resolution
	return lerpf(lerpf(noise.get_noise_2d(x,y),noise.get_noise_2d(x-resolution,y),fx),lerpf(noise.get_noise_2d(x,y-resolution),noise.get_noise_2d(x-resolution,y-resolution),fx),fy)

func _cancelled() -> bool:
	return controls != null and controls.is_cancelled()

func _point(a: Vector2,b: Vector2,c: Vector2,d: Vector2,t: float) -> Vector2:
	var u: float = 1.0-t
	return a*u*u*u + b*3.0*u*u*t + c*3.0*u*t*t + d*t*t*t

func _grow_vessel(origin: Vector2,angle: float,length_value: float,width: float,opacity: float,level: int) -> void:
	var direction := Vector2(cos(angle),sin(angle))
	var end_direction := direction.rotated(rng.randf_range(-.65,.65))
	var end: Vector2 = origin + end_direction*length_value
	var first: Vector2 = origin + direction.rotated(rng.randf_range(-.45,.45))*length_value*.38
	var second: Vector2 = end-direction.rotated(rng.randf_range(-.75,.75))*length_value*.34
	_paint_curve(origin,first,second,end,width,opacity,0,24 if level==0 else 16)
	if level>=2: return
	var sites: Array = [.34,.68] if level==0 else [.53]
	for index: int in range(sites.size()):
		var t: float = sites[index]
		var point: Vector2 = _point(origin,first,second,end,t)
		var tangent: Vector2 = (_point(origin,first,second,end,minf(t+.02,1.0))-_point(origin,first,second,end,maxf(t-.02,0.0))).normalized()
		var sign_value: float = -1.0 if index%2==0 else 1.0
		_grow_vessel(point,tangent.angle()+sign_value*rng.randf_range(.48,1.05),length_value*rng.randf_range(.38,.60),width*lerpf(1.0,.22,t)*.66,opacity*.77,level+1)

func _paint_curve(a: Vector2,b: Vector2,c: Vector2,d: Vector2,width: float,opacity: float,kind: int,steps: int) -> void:
	var previous: Vector2 = a
	for step: int in range(1,steps+1):
		var t: float = float(step)/steps
		var next: Vector2 = _point(a,b,c,d,t)
		var radius_a: float = width*lerpf(1.0,.16,float(step-1)/steps)
		var radius_b: float = width*lerpf(1.0,.16,t)
		_paint_segment(previous,next,radius_a,radius_b,opacity,kind)
		previous=next

func _paint_segment(a: Vector2,b: Vector2,radius_a: float,radius_b: float,opacity: float,kind: int) -> void:
	segment_count+=1
	var support: float = maxf(radius_a,radius_b)*(4.2 if kind==0 else (3.5 if kind==1 else 1.5))+.65
	var minimum: Vector2 = a.min(b)-Vector2.ONE*support
	var maximum: Vector2 = a.max(b)+Vector2.ONE*support
	var segment: Vector2 = b-a
	var inverse_length: float = 1.0/maxf(segment.length_squared(),.00001)
	for y: int in range(floori(minimum.y),ceili(maximum.y)+1):
		for x: int in range(floori(minimum.x),ceili(maximum.x)+1):
			var point := Vector2(float(x)+.5,float(y)+.5)
			var t: float = clampf((point-a).dot(segment)*inverse_length,0.0,1.0)
			var distance: float = point.distance_to(a+segment*t)
			var radius: float = lerpf(radius_a,radius_b,t)
			var core: float = (1.0-smoothstep(0.0,radius*1.45+.5,distance))*opacity
			var halo: float = (1.0-smoothstep(0.0,radius*4.2+.65,distance))*opacity
			if halo<=0.0: continue
			var index: int = posmod(x,resolution)+posmod(y,resolution)*resolution
			match kind:
				0:
					vessels[index]=maxf(vessels[index],core)
					halos[index]=maxf(halos[index],halo*.78)
				1:
					fibres[index]=maxf(fibres[index],core)
					fibre_regions[index]=maxf(fibre_regions[index],halo)
				2: creases[index]=maxf(creases[index],core)
				3: pores[index]=maxf(pores[index],core)
				4: plate_seams[index]=maxf(plate_seams[index],core)
