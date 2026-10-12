@tool
class_name CliffNormalSettings
extends Resource

@export var enabled: bool = true
## Add/remove/reorder resources here. At most 16 entries are supported.
@export var layers: Array[CliffNormalLayer] = []
@export_group("Global Strength")
@export_range(0.0,4.0,0.01) var macro_strength: float = 1.2
@export_range(0.0,4.0,0.01) var medium_strength: float = 0.75
@export_range(0.0,3.0,0.01) var base_normal_strength: float = 1.0
@export_group("Overlap and Distance")
@export_range(0,2,1) var max_macro_layers: int = 2
@export_range(0,2,1) var max_medium_layers: int = 2
@export_range(0.005,0.3,0.005) var selection_blend_width: float = 0.065
@export var macro_fade_start: float = 1800.0
@export var macro_fade_end: float = 4500.0
@export var medium_fade_start: float = 200.0
@export var medium_fade_end: float = 850.0
@export_group("Debug")
@export_enum("Combined", "Base only / overlays off", "Macro only", "Medium only", "Coverage", "Texture IDs", "World normals") var debug_mode: int = 0
## -1 uses natural masks. Otherwise force this zero-based list entry at full coverage.
@export_range(-1,15,1) var isolate_layer: int = -1

func uniforms() -> Dictionary:
	var params:=PackedVector4Array()
	var masks:=PackedVector4Array()
	var transforms:=PackedVector4Array()
	var extras:=PackedVector4Array()
	for i in range(16):
		var layer: CliffNormalLayer=layers[i] if i<layers.size() else null
		if layer==null:
			params.append(Vector4(0,72,0,0));masks.append(Vector4(95,0.28,0.18,0.45));transforms.append(Vector4.ZERO);extras.append(Vector4(2.31,0,0,0))
		else:
			params.append(Vector4(layer.strength,maxf(layer.texture_size_metres,0.5),layer.band,1.0 if layer.enabled and layer.normal_texture!=null else 0.0))
			masks.append(Vector4(maxf(layer.noise_size_metres,1),layer.noise_cutoff,maxf(layer.noise_edge_softness,0.001),layer.noise_breakup_strength))
			transforms.append(Vector4(deg_to_rad(layer.rotation_degrees),layer.texture_offset.x,layer.texture_offset.y,1.0 if layer.flip_normal_y else 0.0))
			extras.append(Vector4(maxf(layer.noise_breakup_frequency,0.1),layer.noise_seed,0,0))
	return {"enable_ambient_cliff_normals":enabled,"cliff_layer_count":mini(layers.size(),16),"cliff_layer_params":params,"cliff_layer_masks":masks,"cliff_layer_transforms":transforms,"cliff_layer_extras":extras,"macro_detail_strength":macro_strength,"medium_detail_strength":medium_strength,"cliff_micro_strength":base_normal_strength,"max_active_macro_layers":max_macro_layers,"max_active_medium_layers":max_medium_layers,"selection_blend_width":selection_blend_width,"distance_fade_start":maxf(macro_fade_start,0),"distance_fade_end":maxf(macro_fade_end,macro_fade_start+1),"medium_fade_start":maxf(medium_fade_start,0),"medium_fade_end":maxf(medium_fade_end,medium_fade_start+1),"cliff_normal_debug":debug_mode,"cliff_force_layer":isolate_layer if isolate_layer<layers.size() else -1}

func texture_signature() -> Array:
	var result: Array=[]
	for layer in layers.slice(0,16): result.append(layer.normal_texture if layer else null)
	return result

func build_texture_array() -> Texture2DArray:
	var images: Array[Image]=[]
	for layer in layers.slice(0,16):
		var data: Image=layer.normal_texture.get_image() if layer and layer.normal_texture else null
		if data==null:
			data=Image.create(2048,2048,false,Image.FORMAT_RG8)
			data.fill(Color(0.5,0.5,1))
		else: data=data.duplicate()
		if data.get_format()!=Image.FORMAT_RGTC_RG or data.get_size()!=Vector2i(2048,2048) or not data.has_mipmaps():
			if data.is_compressed():
				if data.decompress()!=OK: return null
			data.clear_mipmaps()
			data.resize(2048,2048,Image.INTERPOLATE_LANCZOS)
			data.convert(Image.FORMAT_RG8)
			data.generate_mipmaps()
			if data.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)!=OK: return null
		images.append(data)
	if images.is_empty():
		var neutral:=Image.create(2048,2048,false,Image.FORMAT_RG8)
		neutral.fill(Color(0.5,0.5,1));neutral.generate_mipmaps()
		neutral.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)
		images.append(neutral)
	var result:=Texture2DArray.new()
	if result.create_from_images(images)!=OK: return null
	return result
