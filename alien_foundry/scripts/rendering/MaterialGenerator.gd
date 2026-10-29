class_name MaterialGenerator
extends RefCounted
## Reproducible whole-organism palettes, eight biological response categories.
const ORGANIC_SHADER = preload("res://alien_foundry/assets/shaders/organic_tissue.gdshader")
const BlobTissue = preload("res://alien_foundry/scripts/rendering/BlobTissueMaterial.gd")
const MEMBRANE_SHADER = preload("res://alien_foundry/assets/shaders/membrane.gdshader")
const WIRE_SHADER = preload("res://alien_foundry/assets/shaders/wireframe.gdshader")
const Vascular = preload("res://alien_foundry/scripts/rendering/VascularField.gd")
const Tissue = preload("res://alien_foundry/scripts/rendering/TissueAtlas.gd")
const TYPES: Array[String] = ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]
const PALETTES: Array = [
	[Color(0.59,0.51,0.42),Color(0.31,0.23,0.18),Color(0.75,0.68,0.56)],
	[Color(0.62,0.54,0.45),Color(0.34,0.25,0.21),Color(0.78,0.70,0.58)],
	[Color(0.58,0.50,0.44),Color(0.31,0.22,0.20),Color(0.73,0.65,0.56)],
	[Color(0.62,0.53,0.46),Color(0.35,0.26,0.23),Color(0.77,0.69,0.59)],
	[Color(0.58,0.52,0.43),Color(0.31,0.25,0.19),Color(0.74,0.68,0.56)]
]

static func configuration(dna: Dictionary) -> Dictionary:
	var seed_value: int = int(dna.get("seed", 0))
	var supplied: Dictionary = dna.get("materials", {})
	var palette_index: int = posmod(int(supplied.get("palette", seed_value)), PALETTES.size())
	var palette: Array = PALETTES[palette_index]
	# Isolated complete-creature candidate. Ordinary generated/saved creatures
	# keep their established palette and moisture response until art review.
	var colony_profile: bool = str(dna.get("metadata", {}).get("material_direction", "")) == "porous_sac_colony_v1"
	if colony_profile:
		palette = [Color(0.57,0.48,0.32),Color(0.30,0.255,0.18),Color(0.73,0.66,0.53)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x51A7C9
	var wetness: float = clampf(float(supplied.get("wetness", rng.randf_range(0.72, 1.18))), 0.35, 1.4)
	var roughness_bias: float = clampf(float(supplied.get("roughness_bias", rng.randf_range(-0.035, 0.045))), -0.12, 0.16)
	return {"wetness": wetness, "roughness_bias": roughness_bias, "palette": palette_index, "primary": palette[0], "secondary": palette[1], "pale": palette[2], "texture_scale": 1.0 / maxf(float(dna.get("settings", {}).get("size", 1.0)), 0.1), "detail": float(dna.get("settings", {}).get("surface_detail", 0.65)), "offset": float(posmod(seed_value, 104729)) * 0.0137, "porous_sac_profile": colony_profile}

static func create(dna: Dictionary, category: String = "mixed", tissue_transform: Transform3D = Transform3D.IDENTITY, edge_context: Dictionary = {}, tissue_textures: Variant = null) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var config: Dictionary = configuration(dna)
	material.shader = MEMBRANE_SHADER if category == "membrane" else ORGANIC_SHADER
	material.resource_name = "Hive " + category.capitalize()
	material.set_shader_parameter("primary_color", config.primary)
	material.set_shader_parameter("secondary_color", config.secondary)
	material.set_shader_parameter("pale_color", config.pale)
	material.set_shader_parameter("texture_scale", config.texture_scale)
	material.set_shader_parameter("seed_offset", config.offset)
	material.set_shader_parameter("detail_strength", 0.3 + float(config.detail) * 0.85)
	material.set_shader_parameter("tissue_transform", tissue_transform)
	material.set_shader_parameter("creature_wetness", config.wetness)
	material.set_shader_parameter("roughness_bias", config.roughness_bias)
	material.set_shader_parameter("porous_sac_profile", config.porous_sac_profile)
	if config.porous_sac_profile:
		material.set_shader_parameter("colony_olive_color", Color(0.43,0.425,0.29))
		material.set_shader_parameter("colony_strain_color", Color(0.47,0.32,0.345))
		material.set_shader_parameter("colony_vascular_color", Color(0.31,0.225,0.27))
	if tissue_textures is Dictionary:
		apply_tissue_textures(material, tissue_textures)
	elif tissue_textures is Texture2D:
		apply_vascular_texture(material, tissue_textures)
	if category != "membrane":
		material.set_shader_parameter("tissue_index", float(TYPES.find(category)))
		if not edge_context.is_empty():
			material.set_shader_parameter("edge_tissue_index", float(TYPES.find(str(edge_context.get("category", "flesh")))))
			material.set_shader_parameter("module_half_extent", edge_context.get("extent", Vector2(0.5, 0.7)))
			material.set_shader_parameter("module_center", edge_context.get("center", Vector2.ZERO))
			material.set_shader_parameter("module_transition_axis", int(edge_context.get("axis", -1)))
			var transition: Array = edge_context.get("range", [-0.3,-0.1])
			if transition.size() == 2:
				material.set_shader_parameter("module_transition_range", Vector2(float(transition[0]),float(transition[1])))
			material.set_shader_parameter("module_transition_toward_low", bool(edge_context.get("toward_low", true)))
			material.set_shader_parameter("module_contact_occlusion", clampf(float(edge_context.get("contact_occlusion", 1.0)),0.28,1.0))
	# Explicit family gate: ordinary families and membrane stay unchanged.
	if category != "membrane" and BlobTissue.is_enabled(dna):
		BlobTissue.apply_to(material, dna)
	return material

## Worker-only packed bytes. Images and GPU resources are uploaded on main.
static func prepare_tissue(dna: Dictionary, controls: RefCounted = null, resolution: int = 512) -> Dictionary:
	return Tissue.new().build(dna, controls, resolution)

static func create_tissue_textures(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ["tone", "relief", "structure"]:
		var pixels: PackedByteArray = data.get(field + "_pixels", PackedByteArray())
		if pixels.is_empty():
			if field == "structure": continue # Older packed snapshots remain valid.
			return {}
		var image := Image.create_from_data(int(data.width),int(data.height),false,Image.FORMAT_RGBA8,pixels)
		image.generate_mipmaps()
		result[field] = ImageTexture.create_from_image(image)
	return result

static func apply_tissue_textures(material: ShaderMaterial, textures: Dictionary) -> void:
	var valid: bool = textures.has("tone") and textures.has("relief")
	material.set_shader_parameter("use_tissue_atlas", valid)
	material.set_shader_parameter("use_vascular_field", valid)
	if valid:
		material.set_shader_parameter("tissue_tone", textures.tone)
		material.set_shader_parameter("tissue_relief", textures.relief)
		if textures.has("structure") and (material.shader == ORGANIC_SHADER or BlobTissue.is_blob_shader(material.shader)):
			material.set_shader_parameter("tissue_structure", textures.structure)
			material.set_shader_parameter("use_structural_atlas", true)

## Packed-only on the worker; Image/ImageTexture construction stays main-thread.
static func prepare_vascular(dna: Dictionary, controls: RefCounted = null, resolution: int = 512) -> Dictionary:
	return Vascular.new().build(dna, controls, resolution)

static func create_vascular_texture(data: Dictionary) -> Texture2D:
	if data.get("pixels", PackedByteArray()).is_empty():
		return null
	var image := Image.create_from_data(int(data.width), int(data.height), false, Image.FORMAT_RGBA8, data.pixels)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func apply_vascular_texture(material: ShaderMaterial, texture_value: Texture2D) -> void:
	if material.shader != ORGANIC_SHADER and not BlobTissue.is_blob_shader(material.shader):
		return
	material.set_shader_parameter("use_vascular_field", texture_value != null)
	if texture_value != null:
		material.set_shader_parameter("vascular_field", texture_value)

static func clay() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "Neutral inspection clay"
	material.albedo_color = Color(0.57,0.59,0.56)
	material.roughness = 0.88
	material.metallic_specular = 0.22
	return material

static func wireframe() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WIRE_SHADER
	return material
