extends "res://scripts/terrain_mesh_builder.gd"
## Private trial: honour height-only requests in extension sampler publication.
func _get_height(world_x:float,world_z:float,publish_controls:bool=true)->float:
	if _extras_enabled:_last_extras=PackedVector4Array();_last_extras.resize(8);_last_extras.fill(Vector4.ZERO)
	_last_badlands=Vector3.ZERO
	_last_badlands_palette=Vector4.ZERO
	_last_badlands_remnant=0
	_last_badlands_skirt=0
	_last_tropical=Vector3.ZERO
	_last_coast=Vector4.ZERO
	_last_jungle=0;_last_surface=Vector2.ZERO;_last_geology=Vector3.ZERO;_last_weights=Vector4.ZERO
	if _forest!=null:_last_forest=_forest_neutral
	if _savanna!=null:_last_savanna=_forest_neutral
	if _swamp!=null:_last_swamp=_forest_neutral
	_last_swamp_water=water_level
	if _mountain!=null:_last_mountain=PackedFloat32Array([0,0,0,0])
	_height_query=true
	var island:float=_island_mask(world_x,world_z)
	_height_query=false;_last_island=island
	var shore_distance:float=island*maxf(settings.island_size*.5,8)
	var shore_transition:float=maxf(settings.coast_width*694.445,.1)
	var shape_scale:float=maxf(settings.terrain_shape_scale,.01)
	var coast_state:=PackedFloat64Array()
	if _coast!=null and _coast.may_affect(world_x,world_z,shore_distance):
		_coast.sample(world_x,world_z,0,shore_distance,true);coast_state=_coast.state
		if coast_state[2]==1:
			# Fully replaced coastal vertices need no hidden inland landforms.
			# Keep ownership canonical, but do not calculate invisible material banks.
			_last_weights=_biome_weights(world_x,world_z)
			if publish_controls:_last_coast=_coast_payload(coast_state)
			_last_swamp_water=water_level+coast_state[1]*maxf(settings.height_multiplier,.01)
			return water_level+coast_state[0]*maxf(settings.height_multiplier,.01)
	if island<=0:
		var detail:float=_detail_noise.get_noise_2d(world_x/shape_scale,world_z/shape_scale)
		var floor_height:float=minf(-maxf(settings.ocean_depth,1)+detail*settings.seabed_relief,-1)
		return _apply_coast(world_x,world_z,water_level+floor_height*minf(-shore_distance/shore_transition,1)*maxf(settings.height_multiplier,.01),shore_distance,publish_controls,coast_state)
	_last_weights=_biome_weights(world_x,world_z)
	var jungle_weight:float=_jungle_weight;var mountain_weight:float=_mountain_weight;var tropical_weight:float=_tropical_weight
	var land:float=0
	if _last_weights.x>0:
		var profile:Vector3=_grass_sample(world_x/shape_scale,world_z/shape_scale)
		land=lerpf(maxf(1,profile.x),profile.z,profile.y)*_last_weights.x
	if jungle_weight>0:land+=_jungle_height(world_x,world_z,jungle_weight,publish_controls)*jungle_weight
	if _last_weights.y>0:land+=_forest_height(world_x,world_z,_last_weights.y,publish_controls)*_last_weights.y
	if _last_weights.z>0:land+=_savanna_height(world_x,world_z,_last_weights.z,publish_controls)*_last_weights.z
	if _last_weights.w>0:
		land+=_swamp_height(world_x,world_z,_last_weights.w,publish_controls)*_last_weights.w
		_last_swamp_water=water_level+_swamp.state[1]*_last_weights.w*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
	if mountain_weight>0:
		land+=_mountain_height(world_x,world_z,mountain_weight,publish_controls)*mountain_weight
		_last_swamp_water+=_mountain.state[1]*mountain_weight*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
	if tropical_weight>0:
		land+=_tropical_height(world_x,world_z,tropical_weight,publish_controls)*tropical_weight
		_last_swamp_water+=_tropical.state[1]*tropical_weight*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
	if _badlands_weight>0:
		var bw:float=_badlands_weight
		land+=_badlands.sample(world_x,world_z,publish_controls)*bw
		var s:PackedFloat64Array=_badlands.state
		if publish_controls:
			_last_badlands_palette=_badlands.palette_state
			_last_badlands_remnant=bw*s[10]
			_last_badlands_skirt=bw*_badlands.remnant_delta*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
			_last_swamp_water+=s[1]*bw*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
			_last_badlands=Vector3(bw,s[2],s[3])
			_last_geology=_last_geology.lerp(Vector3(s[4],s[5],s[6]),bw)
			_last_surface=_last_surface.lerp(Vector2(s[7],s[8]),bw)
	if _extras_enabled:
		for i in range(8):
			var amount:float=_extra_weights[i]
			if amount<=0:continue
			land+=_extras[i].sample(world_x,world_z,publish_controls)*amount
			if publish_controls:
				var e:PackedFloat64Array=_extras[i].state
				_last_swamp_water+=e[1]*amount*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
				_last_extras[i]=Vector4(amount,e[2],e[3],e[4])
		if _extras[7]!=null and settings.alien_infected.overlay_strength>0:
			var network:Dictionary=_extras[7].network(Vector2(world_x,world_z));var influence:float=network.influence*settings.alien_infected.overlay_strength*(1-_extra_weights[7])
			land+=influence*settings.alien_infected.nerve_height*exp(-pow(network.trunk_distance/100,2))
			if influence>0 and settings.alien_infected.nerve_fibre_height>0:
				land+=influence*_extras[7].nerve_fibre_relief(Vector2(world_x,world_z))
			if publish_controls:
				for i in range(7):_last_extras[i].x*=1-influence
				var previous:Vector4=_last_extras[7];_last_extras[7]=Vector4(previous.x+(1-previous.x)*influence,.5,clampf(network.age,0,1),network.influence)
	return _apply_coast(world_x,world_z,water_level+land*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01),shore_distance,publish_controls,coast_state)
