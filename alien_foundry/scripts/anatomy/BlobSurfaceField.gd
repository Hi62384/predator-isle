extends RefCounted
## Bounded read-only production-field queries for regional surface authoring.
## Prepares influences/tiles only; never samples or extracts a mesh lattice.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Volume = preload("res://alien_foundry/scripts/geometry/OrganicVolume.gd")
var production: RefCounted
var scale_value := 1.0
var scale: float:
	get: return scale_value
var translation := Vector3.ZERO

static func prepare(dna: Dictionary, quality: int) -> RefCounted:
	var snapshot: Dictionary = Graph.repair(dna)
	var adapter := new()
	adapter.scale_value = maxf(float(dna.get("settings", {}).get("size", 1.0)), 0.05)
	Graph.scale_graph(snapshot, adapter.scale_value)
	if dna.get("metadata", {}).has("stage_ground_translation"):
		adapter.translation = Graph.vec(dna.metadata.stage_ground_translation)
		Graph.translate_graph(snapshot, adapter.translation)
	else:
		var previous := Graph.vec(snapshot.nodes[0].position)
		Graph.ground_graph(snapshot)
		adapter.translation = Graph.vec(snapshot.nodes[0].position) - previous
	var field := Volume.new()
	field.source_dna = snapshot
	field.geometry_adjustments = {"thin_features": [], "attachment_collars": [], "lattice_collars": []}
	field._prepare(snapshot.nodes, quality)
	field._conform_surface_folds()
	field._configure_grid(quality)
	field._preserve_thin_features()
	field._ensure_growth_attachments(snapshot.nodes)
	field._build_tiles()
	field.noise.configure(int(dna.get("seed", 1)), adapter.scale_value, float(dna.get("settings", {}).get("surface_detail", 0.5)))
	field._prepare_masks(snapshot.get("modules", []))
	field._expose_surface_cavities(snapshot.nodes)
	field._prepare_module_seats(snapshot.get("modules", []))
	adapter.production = field
	return adapter

func sample_signed_distance(point: Vector3) -> float:
	return production.sample_signed_distance(point * scale_value + translation) / scale_value

func project_to_surface(point: Vector3, direction: Vector3, include_cavities: bool = true) -> Vector3:
	return (production.project_to_surface(point * scale_value + translation, direction, include_cavities) - translation) / scale_value

func project(point: Vector3, direction: Vector3) -> Vector3:
	return project_to_surface(point, direction, false)

func normal_at(point: Vector3, epsilon: float) -> Vector3:
	var e := maxf(epsilon, 0.001)
	return Vector3(sample_signed_distance(point + Vector3.RIGHT * e) - sample_signed_distance(point - Vector3.RIGHT * e),
		sample_signed_distance(point + Vector3.UP * e) - sample_signed_distance(point - Vector3.UP * e),
		sample_signed_distance(point + Vector3.BACK * e) - sample_signed_distance(point - Vector3.BACK * e)).normalized()

func thickness(surface: Vector3, normal: Vector3, reach: float, step: float) -> float:
	var count := clampi(ceili(reach / maxf(step, 0.004)), 8, 128)
	var stride := reach / float(count)
	var inside := false
	for i in range(1, count + 1):
		var distance := float(i) * stride
		if sample_signed_distance(surface - normal * distance) < 0.0: inside = true
		elif inside: return maxf(distance - stride, 0.0)
		else: return 0.0
	return reach if inside else 0.0
