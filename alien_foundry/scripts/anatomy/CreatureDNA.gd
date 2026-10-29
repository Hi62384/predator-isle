extends RefCounted
## Versioned, JSON-only procedural genome. No scene resources or uncontrolled RNG.
const VERSION := 1
const RENDER_GENERATION := 2
const TYPES := ["Blob", "Crawler", "Humanoid", "Abomination", "Beast", "Slitherer", "Combination"]
const DEFAULT_SETTINGS := {
	"size": 1.0, "irregularity": 0.45, "growth_density": 0.4,
	"appendage_density": 0.45, "surface_detail": 0.55,
	"uncanny_features": 0.45, "quality": 1
}
const MATERIALS := ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]

static func normalize_settings(input: Dictionary) -> Dictionary:
	var out := DEFAULT_SETTINGS.duplicate(true)
	for key in input:
		out[key] = input[key]
	var aliases := {"anatomical_irregularity":"irregularity", "organic_growth_density":"growth_density", "uncanny":"uncanny_features"}
	for key in aliases:
		if input.has(key): out[aliases[key]] = input[key]
	out["size"] = clampf(float(out["size"]), 0.35, 2.5)
	for key in ["irregularity", "growth_density", "appendage_density", "surface_detail", "uncanny_features"]:
		out[key] = clampf(float(out[key]), 0.0, 1.0)
	out["quality"] = clampi(int(out["quality"]), 0, 2)
	out["fusion_intensity"] = clampf(float(out.get("fusion_intensity", 0.65)), 0.0, 1.0)
	return out

static func budget(quality: int) -> Dictionary:
	var level := clampi(quality, 0, 2)
	return {"nodes": [120, 180, 240][level], "bones": [96, 144, 192][level], "modules": [12, 20, 28][level], "growths": [12, 22, 32][level],
		"triangle_scope":"total", "max_triangles":[150000,300000,500000][level],
		"max_body_triangles":[45000,100000,180000][level], "max_detail_triangles":[35000,65000,120000][level]}

static func create(creature_type: String, seed_value: int, settings: Dictionary) -> Dictionary:
	var normalized := normalize_settings(settings)
	return {"version": VERSION, "render_generation": RENDER_GENERATION, "seed": seed_value, "type": creature_type,
		"settings": normalized, "nodes": [], "connections": [], "modules": [], "ancestry": [],
		"materials": {"palette_seed": seed_value, "categories": MATERIALS.duplicate()},
		"budget": budget(int(normalized["quality"])), "validation": {}, "metadata": {"generator": "layered_anatomy_v2", "axis": "Y-up / -Z-forward", "units": "metres"}}

static func is_dna(value: Variant) -> bool:
	return value is Dictionary and value.has("nodes") and value.has("seed") and value.has("type")
