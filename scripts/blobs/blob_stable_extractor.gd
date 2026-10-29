extends "res://alien_foundry/scripts/geometry/MeshExtractor.gd"
## Condition crossings before triangulation. A 3.5% voxel endpoint margin
## prevents float-sized corner slivers while retaining one vertex per shared
## lattice edge. This bounds geometric approximation rather than deleting faces.
func _edge(first:int,second:int)->int:
	var low:=mini(first,second);var high:=maxi(first,second)
	var key:int=low*sample_count+high
	if edge_vertices.has(key):return edge_vertices[key]
	var a:float=field[low];var b:float=field[high]
	var t:=clampf(a/(a-b),.035,.965)
	var point:=_point(low).lerp(_point(high),t)
	var normal:=_gradient(low).lerp(_gradient(high),t).normalized()
	if normal.length_squared()<.01:normal=Vector3.UP
	var id:=vertices.size();vertices.append(point);normals.append(normal);edge_vertices[key]=id
	return id

func _reconcile_normals()->void:
	# Final manifold orientation and area-weighted normals are computed once by
	# BlobMeshIntegrity after extraction; skip the legacy iterative normal fix.
	pass
