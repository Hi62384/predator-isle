@tool
class_name DesertSettings
extends Resource

## Desert uses absolute world metres. All changes apply on terrain restart.
## The separate resource keeps Grass and the saved biome-coverage preset unchanged.
## Export names and defaults are preserved for compatibility with existing presets.
@export_group("Regions")
## Typical regional site spacing in metres; adjacent regions can merge.
@export_range(3000, 24000, 250) var region_size: float = 8000.0
## Regional probability control. Effective range is 0.05–0.65, preserving mixed geography.
@export_range(0, 1, 0.01) var sandy_frequency: float = 0.30
## Rocky share of the area remaining after sandy sites. Effective range is 0.02–0.5.
@export_range(0, 1, 0.01) var rocky_frequency: float = 0.20
## Rock-scale local relief and badlands ridge strength. Does not add sand grain geometry.
@export_range(0, 1, 0.01) var ruggedness: float = 0.65
@export_group("Mesh Budget")
## Maximum distant edge spacing, subject to a bounded 64x64 parent mesh.
## Larger parent tiles retain broad silhouettes instead of 512/1024 m facets.
## 0 restores the original parent resolutions. Grass/mixed tiles are untouched.
@export_range(0, 512, 32) var far_mesh_metres: float = 512.0
@export_group("Dunes")
## Probability of retaining eligible kilometre-scale dune fields, independent of relief.
## 1 preserves the existing world; 0 leaves sand sheets without dune geometry.
## Retained field interiors keep their usual dune height/spacing; edges blend smoothly.
@export_range(0, 1, 0.01) var dune_occurrence: float = 1.0
## Existing blend control: 0 disables dunes; otherwise scales dune relief, not site spacing.
@export_range(0, 1, 0.01) var dune_frequency: float = 0.82
## Dune relief blend. Zero disables dunes; this does not change the number of dune sites.
## Editor alias; saved presets continue storing the legacy dune_frequency property.
@export_range(0, 1, 0.01) var dune_relief_strength: float:
	get: return dune_frequency
	set(value): dune_frequency = value
## Requested relief in metres. Width and slip-face constraints can lower individual crests.
@export_range(0, 180, 1) var dune_max_height: float = 85.0
## Minimum secondary and maximum primary wavelengths in metres; both have a 200 m floor.
@export var dune_width_range: Vector2 = Vector2(360.0, 850.0)
## Crest-spacing multiplier. The geometry enforces a minimum of 0.65.
@export_range(0.5, 3, 0.05) var dune_spacing: float = 1.25
## Fraction of a ridge spent on its gentle windward side. Larger values shorten the lee face.
@export_range(0.55, 0.82, 0.01) var dune_asymmetry: float = 0.76
## Blends a rounded lee profile toward a straighter slip face; relief remains width-capped.
@export_range(0, 1, 0.01) var slip_face_sharpness: float = 0.78
## Base wind angle: 0 points along +X; +90 points along +Z.
@export_range(-180, 180, 1) var wind_direction_degrees: float = 24.0
## Gradual, kilometre-scale bending shared by dunes and directional sand textures.
@export_range(0, 1, 0.01) var wind_variation: float = 0.65
@export_group("Sandstone")
## Probability of retaining a complete canyon/wadi catchment, independent of incision.
## Trunks, tributaries and their alluvial fans are selected together, never cut mid-stream.
## 1 preserves all existing networks; 0 leaves unincised regional rock landforms.
@export_range(0, 1, 0.01) var canyon_occurrence: float = 1.0
## Geographical bedrock coverage used by Desert material selection.
@export_range(0, 1, 0.01) var rock_exposure: float = 0.8
## Regional sandstone relief and basin-rim amplitude in metres.
@export_range(100, 900, 10) var highland_height: float = 430.0
## Mean vertical spacing of sandstone shelves and their matching material beds.
## A shared world-space bedding frame keeps exposed layers coherent across cliffs.
@export_range(12, 48, 1) var sedimentary_bed_height: float = 24.0
## Independent block-scale bedrock recesses and mapped fracture relief.
@export_range(0, 1, 0.05) var fracture_strength: float = 0.6
## Tens-of-metres bedrock relief, using the existing 95 m geological field.
## This is rock form, not vertex-scale sand noise; channels remain protected.
@export_range(0, 60, 1) var rock_relief_metres: float = 24.0
## Use two fixed-world 32 m forward probes for Desert lighting normals rather
## than four central probes. Geometry stays exact; pure Grass is untouched.
## Disable to restore central normals/curvature for comparison or art tuning.
@export var fast_normal_sampling: bool = true
## Sand deposition behind obstacles in the cached upwind bedrock envelope.
@export_range(0, 1, 0.05) var wind_shelter_strength: float = 0.65
## Canyon plateau-to-valley relief in metres; the sampler caps this contribution at 380 m.
@export_range(0, 400, 5) var canyon_depth: float = 240.0
## Canyon and valley incision strength; the deterministic drainage topology stays fixed.
@export_range(0, 1, 0.01) var canyon_frequency: float = 0.65
## Incision strength along the fixed drainage network, not canyon occurrence.
## Editor alias; saved presets continue storing the legacy canyon_frequency property.
@export_range(0, 1, 0.01) var canyon_incision_strength: float:
	get: return canyon_frequency
	set(value): canyon_frequency = value
## Shallow erosion along the existing dry drainage network.
@export_range(0, 1, 0.01) var erosion_intensity: float = 0.65
@export_group("Basins")
## Probability of retaining eligible dry-lake patches, independent of floor flattening.
## 1 preserves existing lakebeds; 0 removes dry lakebeds/salt without disabling oases.
## This is spatial selection within suitable basins, not a global relief multiplier.
@export_range(0, 1, 0.01) var dry_lake_occurrence: float = 1.0
## Dry-basin control wavelength in metres, independent of biome coverage.
@export_range(600, 5000, 100) var basin_size: float = 2400.0
## Strength of the flat dry-lakebed floor inside eligible basin regions.
@export_range(0, 1, 0.01) var dry_lake_frequency: float = 0.7
## Flattening strength inside eligible dry basin floors, not dry-lake occurrence.
## Editor alias; saved presets continue storing the legacy dry_lake_frequency property.
@export_range(0, 1, 0.01) var dry_lake_floor_strength: float:
	get: return dry_lake_frequency
	set(value): dry_lake_frequency = value
## Pale mineral material coverage inside dry lakebeds; does not create water.
@export_range(0, 1, 0.01) var salt_coverage: float = 0.55
## Deposited-fan relief and restrained material variation.
@export_range(0, 1, 0.01) var sediment_variation: float = 0.55
## Rare regional oasis-site probability; water additionally requires an eligible low basin.
@export_range(0, 0.06, 0.002) var oasis_frequency: float = 0.018
@export_group("Materials")
## Desert-only reflectance calibration for the shared bright outdoor lighting.
## Does not change the existing Grass material or the scene lights.
@export_range(0.2, 1.0, 0.01) var albedo_gain: float = 0.55
## Broad sand palette variation; keeps the underlying surface families separate.
@export_range(0, 1, 0.01) var sand_color_variation: float = 0.45
## Near-surface ripple normal strength, not extra terrain vertices.
@export_range(0, 1.5, 0.05) var ripple_strength: float = 0.32
## Fine ripple wavelength in metres; footprint filtering removes sub-pixel detail.
@export_range(0.08, 0.8, 0.01) var ripple_wavelength: float = 0.24
## Gravel contribution in eligible rocky, sheltered and dry-wash ground.
@export_range(0, 1, 0.01) var gravel_coverage: float = 0.6
## Restrained sandstone weathering coloration.
@export_range(0, 1, 0.01) var weathering: float = 0.65
## Broad sandstone bedding and medium/macro normal strength.
@export_range(0, 1.5, 0.05) var macro_detail_intensity: float = 0.65
## Broad continuous rock-face relief after source normal-map grain has mip-faded.
## Shading only; 0 disables it. Never changes Grass or canonical terrain heights.
@export_range(0, 2, 0.05) var broad_rock_relief: float = 0.65
## PBR surface-gradient strength; analytic ripples have their own strength control.
@export_range(0.2, 3, 0.05) var micro_normal_strength: float = 0.65

func _validate_property(property: Dictionary) -> void:
	# Hide misleading legacy labels without changing on-disk property names.
	# The three readable aliases are editor-only and must never be serialized.
	var property_name: String = str(property["name"])
	if property_name in ["dune_frequency", "canyon_frequency", "dry_lake_frequency"]:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR
	elif property_name in ["dune_relief_strength", "canyon_incision_strength", "dry_lake_floor_strength"]:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE

func bedding_parameters(world_seed: int) -> Vector4:
	# Reduce integer seeds before float conversion. Returning one float32 vector
	# gives CPU geometry and the shader the same tilt, scale and bounded phase.
	var angle: float = float(world_seed % 6151) * 0.011
	var phase: float = float(world_seed % 8191) * 0.017
	return Vector4(cos(angle) * 0.009, sin(angle) * 0.009,
		clampf(sedimentary_bed_height, 12.0, 48.0), phase)

func shader_uniforms() -> Dictionary:
	return {
		"desert_albedo_gain": albedo_gain,
		"desert_color_variation": sand_color_variation,
		"desert_ripple_strength": ripple_strength,
		"desert_ripple_wavelength": ripple_wavelength,
		"desert_gravel_coverage": gravel_coverage,
		"desert_weathering": weathering,
		"desert_macro_strength": macro_detail_intensity,
		"desert_rock_form_strength": broad_rock_relief,
		"desert_normal_strength": micro_normal_strength,
		"desert_salt_coverage": salt_coverage,
		"desert_sediment_variation": sediment_variation,
		"desert_fracture_strength": fracture_strength,
	}
