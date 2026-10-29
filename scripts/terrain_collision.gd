extends RefCounted
const StructureIndex=preload("res://scripts/structure_collision_index.gd")
## Worker-produced numeric collision payload. Keep the original CPU arrays:
## reading them back from ArrayMesh while staging can synchronize with the GPU.
static func heightfield_error_bound(heights:PackedFloat32Array,resolution:int)->float:
	# Godot 4.6 / Jolt 5.4 quantizes each 2x2-cell block to at most 8 bits,
	# even when CalculateBitsPerSampleForError(0) requests exact heights.
	# Account conservatively for the block's 3x3 samples and global 16-bit
	# range endpoints; steep blocks need an exact triangle surface instead.
	var low:float=INF;var high:float=-INF;var block_range:float=0;var row:int=resolution+1
	for h:float in heights:low=minf(low,h);high=maxf(high,h)
	for z in range(0,resolution,2):
		for x in range(0,resolution,2):
			var block_low:float=INF;var block_high:float=-INF
			for dz in range(3):
				for dx in range(3):
					var h:float=heights[mini(z+dz,resolution)*row+mini(x+dx,resolution)]
					block_low=minf(block_low,h);block_high=maxf(block_high,h)
			block_range=maxf(block_range,block_high-block_low)
	return block_range/508.0+2.0*(high-low)/65534.0+.00001
static func surface_faces(arrays:Array,resolution:int)->PackedVector3Array:
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var faces:=PackedVector3Array();faces.resize(resolution*resolution*6)
	for i in range(faces.size()):faces[i]=vertices[indices[i]]
	return faces
static func prepare(arrays:Array,resolution:int,terrain_enabled:bool,structures:Array,features:Dictionary,index_structures:bool=false)->Dictionary:
	var data:Dictionary={"heights":PackedFloat32Array(),"ground_faces":PackedVector3Array(),"structure_faces":PackedVector3Array(),"cavity_faces":PackedVector3Array(),"cavity_bounds":AABB()}
	if terrain_enabled:
		if not features.is_empty() and not features.openings.is_empty():
			data.ground_faces=features.ground_collision if features.has("ground_collision") else clipped_ground(arrays,features.openings,resolution)
		else:
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var heights:=PackedFloat32Array();heights.resize((resolution+1)*(resolution+1))
			for i in range(heights.size()):heights[i]=vertices[i].y
			data.heights=heights
			data["heightfield_error_bound_m"]=heightfield_error_bound(heights,resolution)
			if data.heightfield_error_bound_m>.01:
				# Only already-near collision is prepared here. Preserve the exact
				# visible triangles for steep terrain; flat tiles keep the cheaper
				# heightfield. Never include the visual streaming skirts.
				data.ground_faces=surface_faces(arrays,resolution)
	var faces:=PackedVector3Array()
	for surface in structures:
		if surface!=null and not surface.is_empty():faces.append_array(surface[Mesh.ARRAY_VERTEX])
	data.structure_faces=faces
	if index_structures and not faces.is_empty():data["structure_index"]=StructureIndex.build(faces)
	if not features.is_empty() and not features.surfaces[0].is_empty():
		var cavity:PackedVector3Array=features.surfaces[0][Mesh.ARRAY_VERTEX];data.cavity_faces=cavity
		var bounds:=AABB(cavity[0],Vector3.ZERO)
		for v:Vector3 in cavity:bounds=bounds.expand(v)
		data.cavity_bounds=bounds
	return data
static func portal_distance(p:Vector3,portal:Vector4)->float:
	var q:=Vector2(p.x-portal.x,p.z-portal.y);var angle:float=q.angle()
	return q.length()-portal.z*(1+.1*sin(angle*3+portal.w)+.06*sin(angle*7-portal.w))
static func clipped_ground(arrays:Array,portals:PackedVector4Array,resolution:int)->PackedVector3Array:
	var source:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var faces:=PackedVector3Array()
	# Surface triangles only: vertical streaming skirts are not walking surfaces.
	for i in range(0,mini(indices.size(),resolution*resolution*6),3):
		var polygon:Array[Vector3]=[source[indices[i]],source[indices[i+1]],source[indices[i+2]]]
		for portal:Vector4 in portals:
			var clipped:Array[Vector3]=[]
			for j in range(polygon.size()):
				var p:Vector3=polygon[j];var q:Vector3=polygon[(j+1)%polygon.size()];var outside_p:bool=portal_distance(p,portal)>=0;var outside_q:bool=portal_distance(q,portal)>=0
				if outside_p:clipped.append(p)
				if outside_p!=outside_q:
					var a:Vector3=p if outside_p else q;var b:Vector3=q if outside_p else p
					for iteration in range(14):
						var middle:Vector3=(a+b)*.5
						if portal_distance(middle,portal)>=0:a=middle
						else:b=middle
					clipped.append(a)
			polygon=clipped
		for j in range(1,polygon.size()-1):faces.append_array(PackedVector3Array([polygon[0],polygon[j],polygon[j+1]]))
	return faces
## Near-leaf collision follows the same committed cut as visual terrain.
## HeightMapShape avoids copying all near terrain triangles into concave meshes.
static func stage(node:MeshInstance3D,span:float,resolution:int,enabled:bool,structure_enabled:bool=false,structure_point:Vector3=Vector3.INF)->void:
	var profiling:bool=bool(node.get_meta("profile_collision",false));var started:int=Time.get_ticks_usec() if profiling else 0
	var body:StaticBody3D=node.get_node_or_null("NearTerrainCollision")
	if body==null and not enabled and not structure_enabled:return
	if body==null:
		body=StaticBody3D.new();body.name="NearTerrainCollision";node.add_child(body)
		for name:String in ["Heightfield","Structures","Cavities"]:
			var shape:=CollisionShape3D.new();shape.name=name;body.add_child(shape)
	body.collision_layer=0;body.collision_mask=0
	var terrain_shape:CollisionShape3D=body.get_node("Heightfield");var structure_shape:CollisionShape3D=body.get_node("Structures")
	terrain_shape.shape=null;structure_shape.shape=null
	var cavity_shape:CollisionShape3D=body.get_node("Cavities");cavity_shape.shape=null
	if not enabled and not structure_enabled:return
	if node.mesh.has_meta("collision_data"):
		var data:Dictionary=node.mesh.get_meta("collision_data")
		var nodes_end:int=Time.get_ticks_usec() if profiling else 0
		if enabled:
			if not data.ground_faces.is_empty():
				var shape:=ConcavePolygonShape3D.new();shape.set_faces(data.ground_faces);terrain_shape.position=Vector3.ZERO;terrain_shape.scale=Vector3.ONE;terrain_shape.shape=shape
			elif not data.heights.is_empty():
				var heightfield:=HeightMapShape3D.new();heightfield.map_width=resolution+1;heightfield.map_depth=resolution+1;heightfield.map_data=data.heights
				terrain_shape.position=Vector3(span*.5,0,span*.5);terrain_shape.scale=Vector3(span/resolution,1,span/resolution);terrain_shape.shape=heightfield
		var terrain_end:int=Time.get_ticks_usec() if profiling else 0
		if not data.structure_faces.is_empty():
			set_structure_subset(node,structure_shape,data,structure_point)
		var structures_end:int=Time.get_ticks_usec() if profiling else 0
		if not data.cavity_faces.is_empty():
			var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(data.cavity_faces);cavity_shape.shape=shape
		if profiling:node.set_meta("collision_stage_profile",{"nodes_ms":(nodes_end-started)/1000.0,"terrain_shape_ms":(terrain_end-nodes_end)/1000.0,"structure_shape_ms":(structures_end-terrain_end)/1000.0,"cavity_shape_ms":(Time.get_ticks_usec()-structures_end)/1000.0})
		return
	if enabled:
		var arrays:Array=node.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var data:=PackedFloat32Array();var row:int=resolution+1;data.resize(row*row)
		for i in range(data.size()):data[i]=vertices[i].y
		if node.mesh.has_meta("cavity_portals"):
			var shape:=ConcavePolygonShape3D.new();var faces:PackedVector3Array=node.mesh.get_meta("cavity_ground_faces") if node.mesh.has_meta("cavity_ground_faces") else clipped_ground(arrays,node.mesh.get_meta("cavity_portals"),resolution)
			shape.set_faces(faces);terrain_shape.position=Vector3.ZERO;terrain_shape.scale=Vector3.ONE;terrain_shape.shape=shape
		else:
			var heightfield:=HeightMapShape3D.new();heightfield.map_width=row;heightfield.map_depth=row;heightfield.map_data=data
			terrain_shape.position=Vector3(span*.5,0,span*.5);terrain_shape.scale=Vector3(span/resolution,1,span/resolution);terrain_shape.shape=heightfield
	if (enabled or structure_enabled) and node.mesh.has_meta("extension_structures"):
		var structure_mesh:ArrayMesh=node.mesh.get_meta("extension_structures");var faces:=PackedVector3Array()
		for surface in range(structure_mesh.get_surface_count()):faces.append_array(structure_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		if not faces.is_empty():
			var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);structure_shape.shape=shape
	if (enabled or structure_enabled) and node.mesh.has_meta("cavity_collision"):
		var faces:=PackedVector3Array();var mesh:ArrayMesh=node.mesh.get_meta("cavity_collision")
		for surface in range(mesh.get_surface_count()):faces.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		if not faces.is_empty():
			var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);cavity_shape.shape=shape
static func set_structure_subset(node:MeshInstance3D,shape_node:CollisionShape3D,data:Dictionary,point:Vector3)->void:
	var selected:Dictionary=StructureIndex.select(data.structure_faces,data.get("structure_index",{}),point)
	# Construct first, then exchange. The existing active shape stays installed
	# until its complete replacement is ready; never clear it across frames.
	var replacement:ConcavePolygonShape3D
	if not selected.faces.is_empty():
		replacement=ConcavePolygonShape3D.new();replacement.set_faces(selected.faces)
	shape_node.shape=replacement
	node.set_meta("structure_collision_cell",(point/StructureIndex.CELL_METRES).floor())
	node.set_meta("structure_collision_triangles",selected.faces.size()/3)
static func refresh_structure_subset(node:MeshInstance3D,point:Vector3)->void:
	if not node.mesh.has_meta("collision_data"):return
	var body:StaticBody3D=node.get_node_or_null("NearTerrainCollision")
	if body==null:return
	var data:Dictionary=node.mesh.get_meta("collision_data")
	if not data.has("structure_index"):return
	var key:Vector3=(point/StructureIndex.CELL_METRES).floor()
	if node.get_meta("structure_collision_cell",Vector3.INF)==key:return
	set_structure_subset(node,body.get_node("Structures"),data,point)
static func activate(node:MeshInstance3D,enabled:bool)->void:
	var body:StaticBody3D=node.get_node_or_null("NearTerrainCollision")
	if body!=null:body.collision_layer=1 if enabled else 0
static func release(node:MeshInstance3D)->void:
	var body:StaticBody3D=node.get_node_or_null("NearTerrainCollision")
	if body==null:return
	body.collision_layer=0
	for shape:CollisionShape3D in body.get_children():shape.shape=null
