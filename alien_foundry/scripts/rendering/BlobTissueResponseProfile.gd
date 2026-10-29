extends RefCounted
## Opt-in experiment only. Saved/default v1 remains the exact original shader.
const PROFILE: String = "reference_tissue_v2_response"
const SHADER = preload("res://alien_foundry/assets/shaders/blob_tissue_response.gdshader")
const RESPONSE_UNIFORMS: Array[String] = ["blob_response_pigment", "blob_response_moisture", "blob_response_microdetail"]

static func is_enabled(dna: Dictionary) -> bool:
	return str(dna.get("type", "")) == "Blob" and str(dna.get("metadata", {}).get("blob_material_profile", "")) == PROFILE

static func configure(material: ShaderMaterial) -> void:
	for parameter: String in RESPONSE_UNIFORMS:
		material.set_shader_parameter(parameter, 1.0)
