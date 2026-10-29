extends Node3D

## Stationary 1.8 m tall reference mannequin; one Godot unit equals one metre.
var _material: StandardMaterial3D

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.32, 0.045)
	_material.roughness = 0.8
	# Feet start at y=0; the head ends at exactly y=1.8.
	_box(Vector3(-0.14, 0.425, 0), Vector3(0.20, 0.85, 0.25))
	_box(Vector3(0.14, 0.425, 0), Vector3(0.20, 0.85, 0.25))
	_box(Vector3(0, 1.15, 0), Vector3(0.46, 0.60, 0.26))
	_box(Vector3(-0.32, 1.13, 0), Vector3(0.16, 0.62, 0.18))
	_box(Vector3(0.32, 1.13, 0), Vector3(0.16, 0.62, 0.18))
	var head := SphereMesh.new()
	head.radius = 0.175
	head.height = 0.35
	_part(head, Vector3(0, 1.625, 0))
	# A metre-wide ground reference and height ruler.
	_box(Vector3(0, 0.015, 0.40), Vector3(1.0, 0.03, 0.03))
	_box(Vector3(0.65, 0.90, 0), Vector3(0.025, 1.8, 0.025))
	for height in [0.0, 0.5, 1.0, 1.5, 1.8]:
		_box(Vector3(0.71, height, 0), Vector3(0.15, 0.025, 0.025))
	var label := Label3D.new()
	label.text = "PLAYER SCALE\n1.80 m tall | 1 m ground ruler"
	label.position = Vector3(0, 2.25, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.005
	label.outline_size = 8
	add_child(label)

func _box(center: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(mesh, center)

func _part(mesh: Mesh, center: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	instance.position = center
	add_child(instance)

func place(camera: Camera3D, terrain: ChunkTerrain) -> void:
	# Editor-style placement follows the canonical surface height, independently
	# of the currently committed near-physics window (and ignores cave interiors).
	var origin := camera.global_position
	var ray := -camera.global_basis.z
	var previous := 0.0
	var found := false
	var point := origin
	for step in range(1, 513):
		var distance := step * 8.0
		point = origin + ray * distance
		if point.y <= terrain.get_height_at(point):
			var low := previous
			var high := distance
			for iteration in range(14):
				var middle := (low + high) * 0.5
				var sample := origin + ray * middle
				if sample.y > terrain.get_height_at(sample):
					low = middle
				else:
					high = middle
			point = origin + ray * high
			found = true
			break
		previous = distance
	if not found:
		var forward := Vector3(ray.x, 0, ray.z).normalized()
		point = origin + forward * 12.0
	point.y = terrain.get_height_at(point)
	global_position = point
	visible = true
