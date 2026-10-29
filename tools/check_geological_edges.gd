extends SceneTree

func _initialize() -> void:
	var script=load("res://scripts/terrain_mesh_builder.gd")
	var b=script.new();b.settings=TerrainSettings.new();b._configure_noise()
	var uncut=script.new();uncut.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);uncut.settings.grass_plateau_erosion=0;uncut._configure_noise()
	var cuts:=0;var fans:=0;var walls:=0;var gentle:=0
	var largest_cut:=0.0
	var cap_min:=INF;var cap_max:=-INF
	for z in range(-40,41):
		for x in range(-40,41):
			var p:=Vector2(x*160.0,z*160.0)
			var h: Vector3=b._grass_sample(p.x,p.y)
			var g: Vector3=b._last_geology
			assert(g.is_finite() and g.x>=0 and g.y>=0 and g.z>=0)
			if g.x>0.10: fans+=1
			if g.z>0.6: walls+=1
			if g.z<0.03 and g.x>0.03: gentle+=1
			if g.y>0.4:
				cuts+=1
				var ref: Vector3=uncut._grass_sample(p.x,p.y)
				largest_cut=maxf(largest_cut,ref.x-h.x)
				assert(uncut._last_geology.y==0)
			if b._last_surface.x>0.99 and g.y<0.01 and g.z<0.01 and h.x>150 and h.x<350:
				cap_min=minf(cap_min,h.x);cap_max=maxf(cap_max,h.x)
	assert(cuts>10 and fans>10 and walls>10 and gentle>5)
	assert(largest_cut>40 and cap_max-cap_min>15)
	print("PASS geological controls: cuts=",cuts," scree=",fans," strong walls=",walls," gentle aprons=",gentle," max cut=",largest_cut," cap range=",cap_min,"..",cap_max)
	quit()
