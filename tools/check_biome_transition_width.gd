extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	var rows:Array=[]
	var saved=load("res://config/world/terrain_settings.tres")
	if saved.height_blend!=3.0:failures.append("Saved world must use the checked gradual height blend")
	for seed_id:int in [73921,17,92881]:
		var original=Builder.new();original.world_seed=seed_id;original.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);original.settings.height_blend=12;original._configure_noise()
		var gradual=Builder.new();gradual.world_seed=seed_id;gradual.settings=saved.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);gradual._configure_noise()
		var selected:Vector2=Vector2.INF
		for z:int in range(-80000,80001,1000):
			var previous:bool=false
			for x:int in range(-32000,32001,128):
				original._biome_weights(x,z);var mountain:bool=original._mountain_weight>.5
				if x>-32000 and mountain!=previous:
					gradual._biome_weights(x,z)
					if gradual._mountain_weight>.01 and gradual._mountain_weight<.99 and original._island_mask(x,z)>.02:selected=Vector2(x,z);break
				previous=mountain
			if selected.is_finite():break
		if not selected.is_finite():failures.append("No actual mountain border for seed "+str(seed_id));continue
		var measurements:Array=[]
		for sampler in [original,gradual]:
			var mixed:int=0;var maximum_delta:float=0;var last_height:float=INF
			for offset:int in range(-3000,3001,8):
				var p:Vector2=selected+Vector2(offset,0);var height:float=sampler._get_height(p.x,p.y)
				sampler._biome_weights(p.x,p.y)
				if not is_finite(height):failures.append("Nonfinite border height")
				if sampler._mountain_weight>.05 and sampler._mountain_weight<.95:mixed+=1
				if is_finite(last_height):maximum_delta=maxf(maximum_delta,absf(height-last_height))
				last_height=height
			measurements.append({"mixed_width_m":mixed*8,"maximum_8m_height_change_m":maximum_delta})
		if measurements[1].mixed_width_m<=measurements[0].mixed_width_m:failures.append("Mountain foothill width did not increase for "+str(seed_id))
		rows.append({"seed":seed_id,"border":str(selected),"original":measurements[0],"gradual":measurements[1]})
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"borders":rows,"settings_sha256":FileAccess.get_sha256("res://config/world/terrain_settings.tres"),"scope":"First shared mixed mountain border per seed in declared scan;saved gradual preset versus previous12 blend,8m transects"}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_biome_transition_width.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BIOME_TRANSITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
