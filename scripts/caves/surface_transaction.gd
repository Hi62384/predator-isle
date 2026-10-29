extends RefCounted
## Main-thread surface commit. Preparation allocates replacement resources but
## never edits a visible material or active collider. Only a validated complete
## transaction may exchange parent masks, ground shapes and cave patch bodies.
const Cut=preload("res://scripts/caves/surface_cut.gd")
var Collision=preload("res://scripts/csharp/terrain/TerrainCollision.cs").new()
var records:Array=[]
var patches:Array=[]
var columns:Dictionary={}
var prepared:bool=false
var committed:bool=false
var mask_texture:ImageTexture
var previous
var collision_enabled:bool=true
var common_vertex_projection:bool=true
func baseline(node:MeshInstance3D)->Dictionary:
	for record:Dictionary in records:
		if record.node==node and is_instance_valid(node) and node.mesh==record.mesh:return record
	return {}
func prepare(nodes:Array,replacements:Array,requested_columns:Dictionary,center:Vector2,prior=null,prepared_ground:Dictionary={})->bool:
	if prepared or committed or requested_columns.is_empty():return false
	records.clear();patches.clear();columns.clear();mask_texture=null;previous=null
	var mask:Dictionary=Cut.mask(requested_columns,center)
	if mask.is_empty() or mask.columns.size()!=requested_columns.size():return false
	mask_texture=ImageTexture.create_from_image(Image.create_from_data(mask.side,mask.side,false,Image.FORMAT_R8,mask.r8_bytes));previous=prior;columns=requested_columns.duplicate()
	for raw in replacements:
		if not (raw is MeshInstance3D) or not is_instance_valid(raw) or raw.mesh==null or not raw.is_inside_tree():return false
		var body:StaticBody3D=raw.get_node_or_null("CaveCollision")
		if body==null or body.collision_layer!=0 or raw.visible:return false
		patches.append(raw)
	if patches.is_empty():return false
	for raw in nodes:
		if not (raw is MeshInstance3D) or not is_instance_valid(raw) or raw.mesh==null or raw.mesh.get_surface_count()==0:return false
		var node:MeshInstance3D=raw
		if not node.global_basis.is_equal_approx(Basis.IDENTITY):return false
		var inherited:Dictionary=prior.baseline(node) if prior!=null else {};var original_override:Material=node.get_surface_override_material(0) if inherited.is_empty() else inherited.original_override;var material:Material=original_override if original_override!=null else node.mesh.surface_get_material(0)
		if not (material is ShaderMaterial):return false
		var shader:Shader=Cut.shader(material.shader,common_vertex_projection)
		if shader==null:return false
		var replacement:ShaderMaterial=material.duplicate() as ShaderMaterial;replacement.shader=shader;replacement.set_shader_parameter("cave_cut_enabled",true);replacement.set_shader_parameter("cave_cut_mask",mask_texture);replacement.set_shader_parameter("cave_cut_tile_offset",Vector2(node.global_position.x,node.global_position.z)/64-Vector2(mask.origin_cell))
		var shape_node:CollisionShape3D=node.get_node_or_null("NearTerrainCollision/Heightfield");var original_shape:Shape3D=null;var ground_shape:Shape3D=null
		if shape_node!=null:
			original_shape=shape_node.shape if inherited.is_empty() else inherited.original_shape;ground_shape=original_shape
			var resolution:int=node.get_meta("resolution",0);var tile:Vector3i=node.get_meta("tile",Vector3i.ZERO)
			if original_shape!=null and tile.z<=1:
				var clipped:Dictionary=prepared_ground.get(str(tile),{})
				if clipped.is_empty():
					var data:Dictionary=node.mesh.get_meta("collision_data",{});var source:PackedVector3Array=data.get("ground_faces",PackedVector3Array())
					if source.is_empty():
						var arrays:Array=node.mesh.get_meta("terrain_cpu_arrays",[]) if node.mesh.has_meta("terrain_cpu_arrays") else node.mesh.surface_get_arrays(0)
						if resolution<1 or arrays.is_empty():return false
						source=Collision.surface_faces(arrays,resolution)
					clipped=Cut.ground(source,node.global_position,columns)
				if not clipped.valid:return false
				if clipped.removed_source_triangles>0 or clipped.split_source_triangles>0:
					var exact:=ConcavePolygonShape3D.new();exact.set_faces(clipped.faces);ground_shape=exact
		records.append({"node":node,"mesh":node.mesh,"transform":node.global_transform,"original_override":original_override,"material":replacement,"shape_node":shape_node,"original_shape":original_shape,"ground_shape":ground_shape,"original_shape_transform":shape_node.transform if inherited.is_empty() and shape_node!=null else inherited.get("original_shape_transform",Transform3D.IDENTITY)})
	prepared=true;return true
func ready_to_commit()->bool:
	if not prepared or committed:return false
	for record:Dictionary in records:
		if not is_instance_valid(record.node) or record.node.mesh!=record.mesh or record.node.global_transform!=record.transform:return false
	for node:MeshInstance3D in patches:
		if not is_instance_valid(node) or node.mesh==null:return false
	return true
func restore_node(record:Dictionary)->void:
	var node:MeshInstance3D=record.node
	if not is_instance_valid(node) or node.mesh!=record.mesh:return
	node.set_surface_override_material(0,record.original_override)
	if is_instance_valid(record.shape_node):record.shape_node.shape=record.original_shape;record.shape_node.transform=record.original_shape_transform
func apply_node(node:MeshInstance3D)->void:
	var record:Dictionary=baseline(node)
	if record.is_empty():return
	node.set_surface_override_material(0,record.material)
	if is_instance_valid(record.shape_node):
		record.shape_node.shape=record.ground_shape
		if record.ground_shape!=record.original_shape:record.shape_node.transform=Transform3D.IDENTITY
func commit()->bool:
	if not ready_to_commit():return false
	# All readiness checks precede every mutation. Both restoration of the old
	# cut and installation of its complete replacement happen in this one call.
	if previous!=null:
		for record:Dictionary in previous.records:previous.restore_node(record)
	for record:Dictionary in records:apply_node(record.node)
	for node:MeshInstance3D in patches:node.visible=true;node.get_node("CaveCollision").collision_layer=1 if collision_enabled else 0
	if previous!=null:
		for node:MeshInstance3D in previous.patches:
			if is_instance_valid(node) and not patches.has(node):node.visible=false;node.get_node("CaveCollision").collision_layer=0
		previous.committed=false
	previous=null
	committed=true;return true
func reset()->void:
	if committed:
		for record:Dictionary in records:restore_node(record)
	for node:MeshInstance3D in patches:
		if is_instance_valid(node):node.visible=false;node.get_node("CaveCollision").collision_layer=0
	committed=false
func release_node(node:MeshInstance3D)->void:
	var record:Dictionary=baseline(node)
	if not record.is_empty():restore_node(record)
func materials()->Array:
	var result:Array=[]
	if committed:
		for record:Dictionary in records:result.append(record.material)
	return result
