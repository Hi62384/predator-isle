extends RefCounted
## Explicitly Blob-only surface direction. The common generator/atlas remains
## the baseline; this adapter preserves semantic/bind controls and textures.
const SHADER = preload("res://alien_foundry/assets/shaders/blob_tissue.gdshader")
const ResponseProfile = preload("res://alien_foundry/scripts/rendering/BlobTissueResponseProfile.gd")
const PROFILE: String = "reference_tissue_v1"
const INHERITED_UNIFORMS: Array[String] = [
	"primary_color", "secondary_color", "pale_color",
	"tissue_index", "edge_tissue_index", "module_half_extent", "module_center",
	"module_transition_axis", "module_transition_range", "module_transition_toward_low",
	"module_contact_occlusion", "creature_wetness", "roughness_bias", "texture_scale",
	"detail_strength", "seed_offset", "tissue_transform", "use_bind_coordinates",
	"use_curve_uv", "use_authored_fibre_uv", "use_macro_occlusion", "use_surface_context",
	"use_vascular_field", "vascular_field", "use_tissue_atlas", "tissue_tone",
	"tissue_relief", "use_structural_atlas", "tissue_structure"
]

static func is_enabled(dna: Dictionary) -> bool:
	# A baseline fixture can opt out without changing the ordinary families or
	# the saved DNA. Unknown future profiles are not silently reinterpreted.
	return str(dna.get("type", "")) == "Blob" and str(dna.get("metadata", {}).get("blob_material_profile", PROFILE)) in [PROFILE, ResponseProfile.PROFILE]

static func is_blob_shader(shader: Shader) -> bool:
	return shader == SHADER or shader == ResponseProfile.SHADER

static func apply_to(material: ShaderMaterial, dna: Dictionary) -> bool:
	if not is_enabled(dna) or material == null or material.shader == null:
		return false
	# Thin authored membranes retain their established two-sided shader.
	if material.shader.resource_path.ends_with("/membrane.gdshader"):
		return false
	var target_shader: Shader = ResponseProfile.SHADER if ResponseProfile.is_enabled(dna) else SHADER
	if material.shader == target_shader:
		return true
	var inherited: Dictionary = {}
	for parameter: String in INHERITED_UNIFORMS:
		var value: Variant = material.get_shader_parameter(parameter)
		if value != null:
			inherited[parameter] = value
	material.shader = target_shader
	for parameter: String in inherited:
		material.set_shader_parameter(parameter, inherited[parameter])
	# Keep the selected organism-wide palette from MaterialGenerator. Replacing
	# the shader must not silently discard a saved/material-only palette choice.
	material.set_shader_parameter("colony_olive_color", Color(0.45, 0.455, 0.325))
	material.set_shader_parameter("colony_strain_color", Color(0.48, 0.345, 0.355))
	material.set_shader_parameter("colony_vascular_color", Color(0.30, 0.23, 0.265))
	material.set_shader_parameter("blob_pigment_strength", 0.42)
	material.set_shader_parameter("blob_vascular_strength", 0.58)
	material.set_shader_parameter("blob_moisture_strength", 0.78)
	material.set_shader_parameter("blob_fibre_strength", 0.66)
	if target_shader == ResponseProfile.SHADER:
		ResponseProfile.configure(material)
	if not material.resource_name.begins_with("Blob tissue | "):
		material.resource_name = "Blob tissue | " + str(material.resource_name)
	return true
