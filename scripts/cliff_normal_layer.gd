@tool
class_name CliffNormalLayer
extends Resource

@export var label: String = "New rock":
	set(value):
		label=value
		resource_name=value
@export var enabled: bool = true
## OpenGL normal map. No albedo texture here.
@export var normal_texture: Texture2D
@export_enum("Macro", "Medium") var band: int = 0
@export_range(0.0,4.0,0.01) var strength: float = 1.0
## Width of one texture repeat in metres. Larger means larger rock features.
@export_range(0.5,500.0,0.5) var texture_size_metres: float = 72.0
@export_range(1.0,1000.0,1.0) var noise_size_metres: float = 95.0
## Lower cutoff = more coverage. Higher cutoff = fewer patches.
@export_range(0.0,1.0,0.01) var noise_cutoff: float = 0.28
@export_range(0.01,0.8,0.01) var noise_edge_softness: float = 0.18
@export_range(0.0,1.0,0.01) var noise_breakup_strength: float = 0.45
@export_range(0.1,8.0,0.05) var noise_breakup_frequency: float = 2.31
@export var noise_seed: int = 0
@export_range(-180.0,180.0,1.0) var rotation_degrees: float = 0.0
@export var texture_offset: Vector2 = Vector2.ZERO
## Enable for DirectX (-Y) maps; leave off for ambientCG NormalGL.
@export var flip_normal_y: bool = false
