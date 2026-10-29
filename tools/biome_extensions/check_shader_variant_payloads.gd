extends SceneTree
const Variants=preload("res://scripts/terrain_shader_variants.gd")
var checks:int=0
var cases:Array=[]
func verify(ok:bool)->void:assert(ok);checks+=1
func bank(arrays:Array,channel:int,index:int,stride:int=4)->Vector4:
	if arrays[channel]==null:return Vector4(0,0,0,1)
	var data:PackedFloat32Array=arrays[channel];var p:int=index*stride
	return Vector4(data[p],data[p+1],data[p+2],data[p+3] if stride==4 else 1)
func unpack24(value:float)->Vector3:
	var q:int=roundi(value);return Vector3(q&255,(q>>8)&255,(q>>16)&255)/255.0
func decoded_weights(arrays:Array,index:int)->PackedFloat32Array:
	var vertices:int=arrays[Mesh.ARRAY_VERTEX].size();var stride:int=arrays[Mesh.ARRAY_CUSTOM0].size()/vertices
	var a:Vector4=bank(arrays,Mesh.ARRAY_CUSTOM0,index,stride)
	var b:Vector4=bank(arrays,Mesh.ARRAY_CUSTOM1,index)
	var c:Vector4=bank(arrays,Mesh.ARRAY_CUSTOM2,index)
	var d:Vector4=bank(arrays,Mesh.ARRAY_CUSTOM3,index)
	var color:Color=arrays[Mesh.ARRAY_COLOR][index]
	var tropical:bool=c.x<0
	return PackedFloat32Array([
		unpack24(-a.w-1 if a.w<0 else a.w).z,
		color.g if tropical else unpack24(b.x).z,
		color.b if tropical else unpack24(c.x).z,
		color.a if tropical else unpack24(d.x).z,
		unpack24(a.y).z if a.x<0 else 0,
		unpack24(-c.x-1).z if tropical else 0,
		unpack24(arrays[Mesh.ARRAY_TEX_UV][index].y).x if a.w<0 else 0,
		unpack24(-b.z-1).y if b.z<0 else 0])
func _initialize()->void:call_deferred("run")
func run()->void:
	var configurations:Array[Array]=[[],["alien_infected"],["spore_forest"],["tropical"],["badlands","forest"],["grass","forest","badlands","insect_colony","alien_infected"],["grass","jungle","forest","savanna","swamp","mountain"],["quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"],["grass"]]
	for seed_id:int in [73921,17,92881]:
		for configuration:int in range(configurations.size()):
			for coastal:bool in [false,true]:
				var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
				for owner:String in ["grass"]+Variants.LEGACY+TerrainSettings.EXTENSION_KEYS:b.settings.set(owner+"_coverage",20 if configurations[configuration].has(owner) else 0)
				if configuration==8:b.settings.alien_infected.overlay_strength=.7
				b.settings.rocky_coast_enabled=coastal;b.settings.beaches_enabled=coastal;b.settings.biome_size=.2;b._configure_noise()
				var mask:int=Variants.configured_mask(b.settings);var vertices:int=0
				for cell:Vector2i in [Vector2i(0,0),Vector2i(-20,37),Vector2i(79,-54)]:
					var arrays:Array=b.build(cell,8)
					verify((b.built_extension_mask & ~(mask>>8))==0)
					for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
						var weights:PackedFloat32Array=decoded_weights(arrays,i)
						for owner:int in range(8):
							if (mask & (1<<owner))==0:verify(weights[owner]==0)
						vertices+=1
				cases.append({"seed":seed_id,"configuration":configuration,"coastal":coastal,"mask":mask,"tiles":3,"decoded_vertices":vertices})
	# The validator must detect a manufactured disabled owner in real arrays.
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=TerrainSettings.new();b.settings.badlands_coverage=100;b._configure_noise()
	var negative:Array=b.build(Vector2i.ZERO,8);var data:PackedFloat32Array=negative[Mesh.ARRAY_CUSTOM0]
	if data.size()/negative[Mesh.ARRAY_VERTEX].size()==3:
		var expanded:=PackedFloat32Array()
		for i in range(negative[Mesh.ARRAY_VERTEX].size()):expanded.append_array(PackedFloat32Array([data[i*3],data[i*3+1],data[i*3+2],0]))
		data=expanded
	data[3]=65536;negative[Mesh.ARRAY_CUSTOM0]=data
	verify(decoded_weights(negative,0)[0]>0)
	var report:Dictionary={"passed":true,"failures":[],"assertions":checks,"cases":cases,"negative_control_detected":true,"scope":"Actual packed legacy vertex channels and extension owner masks, including skirts, three seeds, nine configured owner sets including coverage-zero Alien overlays, and coasts on/off. Disabled shader branches must decode exact zero; not a universal traversal or image certificate.","source_sha256":{}}
	for path:String in ["res://scripts/terrain_shader_variants.gd","res://scripts/terrain_mesh_builder.gd","res://shaders/terrain_control_decode.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://tools/biome_extensions/check_shader_variant_payloads.gd"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_shader_variant_payloads.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SHADER_VARIANT_PAYLOADS_PASS ",checks);quit()
