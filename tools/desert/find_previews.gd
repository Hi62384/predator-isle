extends SceneTree
const Builder = preload("res://scripts/terrain_mesh_builder.gd")
const NAMES = ["sand_sea","barchan_dunes","longitudinal_dunes","rocky_plain","sandstone_highlands","major_canyon","badlands","dry_river_valley","alluvial_fan","salt_flat","dry_lakebed","oasis_basin"]
func _initialize() -> void:
	var builder = Builder.new()
	builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.grass_coverage=0;builder.settings.desert_coverage=100;builder.settings.snow_coverage=0;builder.settings.stone_coverage=0;builder.settings.temperature_enabled=false
	builder.world_seed=73921
	builder._configure_noise()
	var best := {}
	for name in NAMES: best[name]={"score":-1.0}
	# Fixed discovery domain and traversal, independent of camera/chunk order.
	for z in range(-256,257):
		for x in range(-256,257):
			var p := Vector2(x*256.0,z*256.0)
			var h: float=builder._get_height(p.x,p.y)
			if builder._last_island<0.02:continue
			var s=builder._desert
			var highland_slope: float=0.0
			var plain_relief: float=0.0
			if s.last_weights[4]>0.5 and h>60.0:
				var left: float=builder._get_height(p.x-32.0,p.y)
				var right: float=builder._get_height(p.x+32.0,p.y)
				var back: float=builder._get_height(p.x,p.y-32.0)
				var front: float=builder._get_height(p.x,p.y+32.0)
				highland_slope=Vector2(left-right,back-front).length()/64.0
				builder._get_height(p.x,p.y)
			elif s.last_weights[1]>0.8 and absf(h-14.0)<3.0:
				# A plain landmark must be calm over its surroundings, not just
				# happen to pass through elevation 14 at the foot of an outcrop.
				for offset: Vector2 in [Vector2(400,0),Vector2(-400,0),Vector2(0,400),Vector2(0,-400)]:
					plain_relief=maxf(plain_relief,absf(builder._get_height(p.x+offset.x,p.y+offset.y)-h))
				builder._get_height(p.x,p.y)
			var w: PackedFloat32Array=s.last_weights
			if w.size()<7:continue
			var c: Vector4=s.control_surface
			var wind: Vector4=s.control_wind
			var dune: float=s.control_region.w
			# Coverage alone selects empty interdune corridors. Require an actual
			# local isolated crest for the barchan landmark, and relief for ergs.
			var barchan_relief: float=0.0
			if s.last_family==2 and w[0]>0.5:
				barchan_relief=s._isolated_dunes(s.wind_coordinates(p.x,p.y),s._dune_width,2)/maxf(s.settings.dune_max_height,1.0)
			var scores: Array[float]=[
				w[0]*dune*(0.25+s.last_crest*0.75),
				w[0]*dune*barchan_relief if s.last_family==2 else 0.0,
				w[0]*dune*(0.25+s.last_crest*0.75) if s.last_family==1 else 0.0,
				w[1]/(1.0+absf(h-14.0)*0.2+plain_relief*0.03),
				w[4]*h/400.0*smoothstep(0.15,0.9,highland_slope),
				w[2]*c.y*(0.5+c.x),
				w[5]*(0.2+c.x),
				c.y*(1.0-w[0])*(1.0-w[2])*(1.0-w[6])*(1.0-wind.w) if h>2.0 else 0.0,
				s.last_fan,
				c.z*wind.z,
				c.z*(1.0-wind.z)*(1.0-w[6])*(1.0-wind.w) if h>2.0 else 0.0,
				wind.w if h<0.0 else 0.0]
			for i in range(NAMES.size()):
				# Weak tie-breaking favors smaller travel distance, deterministically.
				var score: float=scores[i]-p.length()*0.00000001
				if score>best[NAMES[i]].score:
					best[NAMES[i]]={"score":score,"x":p.x,"z":p.y,"height":h,"region":s.REGION_NAMES[s.last_region],"family":s.last_family,"region_weights":Array(w),"surface":str(c),"wind_salt_wet":str(wind)}
	var mixed = Builder.new()
	mixed.settings=builder.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	mixed.settings.grass_coverage=50;mixed.settings.desert_coverage=50
	mixed.settings.grass_region_size=24000;mixed.settings.desert_region_size=24000;mixed.settings.biome_size=1.0
	mixed._configure_noise()
	var transition := {"score":-1.0}
	for z in range(-256,257):
		for x in range(-256,257):
			var p := Vector2(x*128.0,z*128.0)
			var w: Vector4=mixed._biome_weights(p.x,p.y)
			if w.x<0.15 or w.y<0.15:continue
			var h: float=mixed._get_height(p.x,p.y)
			if h<3.0:continue
			var score: float=1.0-absf(w.x-w.y)-p.length()*0.0000001
			if score>transition.score:transition={"score":score,"x":p.x,"z":p.y,"height":h,"biome_weights":str(w),"mixed_preview_override":true}
	best["desert_grass_transition"]=transition
	var found: bool=true
	for name in best:
		if best[name].score<=0.01:
			push_error("Feature not found: "+name)
			found=false
	var result := {"seed":73921,"source":"Actual canonical procedural sampler; coordinates discovered, never sculpted or forced.","settings":"Saved terrain preset with pure-Desert coverage override; transition uses 50/50, equal 24km regions, biome_size1, temperature disabled.","features":best,"all_found":found}
	FileAccess.open("res://tools/desert/preview_locations.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	FileAccess.open("res://data/desert_previews.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit(0 if found else 1)
