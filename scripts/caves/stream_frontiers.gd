extends RefCounted
## Temporary, explicit loading boundaries, not permanent graph walls. Clip
## negative air on the SAME tetrahedron face diagonals/lattice/crossing rule
## as Mesher. Restore before eviction and remove only after neighbour upload.
const Mesher=preload("res://scripts/csharp/caves/CaveMesher.cs")
const DIRECTIONS=[Vector3i.LEFT,Vector3i.RIGHT,Vector3i.DOWN,Vector3i.UP,Vector3i.FORWARD,Vector3i.BACK]
const AXES=[Vector3(0,1,0),Vector3(0,1,0),Vector3(1,0,0),Vector3(1,0,0),Vector3(1,0,0),Vector3(1,0,0)]
const OTHER=[Vector3(0,0,1),Vector3(0,0,1),Vector3(0,0,1),Vector3(0,0,1),Vector3(0,1,0),Vector3(0,1,0)]
static func sample(volume,point:Vector3)->float:
	# Never cap the outdoor half-space of a portal column. The six-metre
	# entry seal matches ordinary cells and leaves the real surface mouth open.
	return volume.cave_sample(point) if volume.has_method("cave_sample") else volume.sample(point)
static func clipped(points:Array,values:Array,mesher)->Array:
	var result:Array=[]
	for i in range(3):
		var next:int=(i+1)%3;var a:Vector3=points[i];var b:Vector3=points[next];var va:float=values[i];var vb:float=values[next]
		if va<0:result.append(a)
		if (va<0)!=(vb<0):result.append(mesher.crossing(a,b,va,vb))
	return result
static func build(volume,key:Vector3i,boundary_values:Array=[])->Dictionary:
	var result:Dictionary={};var origin:=Vector3(key)*64;var mesher=Mesher.new()
	if not volume.has_chunk(key):return result
	# Worker-local field only. Reuse its canonical six-metre rock-cover clip
	# instead of evaluating expensive terrain height again at every face point.
	var cover:float=volume.opening_rock_cover;volume.opening_rock_cover=maxf(6,cover)
	for face in range(6):
		var direction:Vector3=Vector3(DIRECTIONS[face]);var start:Vector3=origin+direction.max(Vector3.ZERO)*64;var u:Vector3=AXES[face];var v:Vector3=OTHER[face];var points:=PackedVector3Array();var values:=PackedFloat32Array()
		var reuse:bool=boundary_values.size()==6 and boundary_values[face].size()==1089
		for y in range(33):
			for x in range(33):var point:Vector3=start+u*x*2+v*y*2;points.append(point);values.append(boundary_values[face][x+y*33] if reuse else sample(volume,point))
		var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var inward:Vector3=-direction
		for y in range(32):
			for x in range(32):
				var a:int=x+y*33
				for indices:Array in [[a,a+1,a+34],[a,a+34,a+33]]:
					if values[indices[0]]>=0 and values[indices[1]]>=0 and values[indices[2]]>=0:continue
					var polygon:Array=clipped([points[indices[0]],points[indices[1]],points[indices[2]]],[values[indices[0]],values[indices[1]],values[indices[2]]],mesher)
					for i in range(1,polygon.size()-1):
						var p:Vector3=polygon[0];var q:Vector3=polygon[i];var r:Vector3=polygon[i+1];var normal:Vector3=(r-p).cross(q-p)
						if normal.length_squared()==0:continue
						if normal.dot(inward)<0:var swap:Vector3=q;q=r;r=swap
						for point:Vector3 in [p,q,r]:vertices.append(point-origin);normals.append(inward);colors.append(Color(.38,.35,.3,1))
		if vertices.is_empty():continue
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;result[face]=arrays
	volume.opening_rock_cover=cover;return result
static func attach(parent:MeshInstance3D,payload:Dictionary,material:Material,shadows:bool)->void:
	if payload.is_empty():return
	var container:=Node3D.new();container.name="CaveFrontiers";parent.add_child(container)
	for face:int in payload:
		var arrays:Array=payload[face];var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material);var node:=MeshInstance3D.new();node.mesh=mesh;node.set_meta("face",face);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;var body:=StaticBody3D.new();body.name="FrontierCollision";body.collision_layer=0;body.collision_mask=0;var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);collision.shape=shape;body.add_child(collision);node.add_child(body);container.add_child(node)
static func synchronize(cells:Dictionary,collision_enabled:bool=true)->void:
	for key:Vector3i in cells:
		var parent=cells[key]
		if not is_instance_valid(parent):continue
		var container=parent.get_node_or_null("CaveFrontiers")
		if container==null:continue
		for node:MeshInstance3D in container.get_children():
			var closed:bool=not cells.has(key+DIRECTIONS[int(node.get_meta("face"))]);node.visible=closed;node.get_node("FrontierCollision").collision_layer=1 if closed and collision_enabled else 0
