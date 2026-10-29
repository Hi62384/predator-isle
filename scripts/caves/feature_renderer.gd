extends RefCounted
## Uploaded under the SAME atomic cell and collision body as its cave rock.
const Materials=preload("res://scripts/caves/biome_materials.gd")
static func discard(prepared:Array)->void:
	for item:Dictionary in prepared:
		for node:Node3D in item.nodes:node.free()
		if item.shape!=null:item.shape.free()
static func attach(parent:Node3D,batches:Array,registry:Resource,common:bool,shadows:bool)->bool:
	var prepared:Array=[]
	for batch:Dictionary in batches:
		var definition:Resource=Materials.definition(registry,str(batch.biome_id))
		if definition==null or definition.surface_provider==null:
			discard(prepared)
			return false
		var provider=definition.surface_provider.new()
		if not provider.has_method("feature_material"):
			discard(prepared)
			return false
		var material:ShaderMaterial=provider.feature_material(str(batch.kind),definition.material_configuration,common)
		if material==null or material.shader==null:
			discard(prepared)
			return false
		var arrays:Array=batch.arrays;var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],batch.get("lods",{}));mesh.surface_set_material(0,material)
		var node:=MeshInstance3D.new();node.name="CaveBiome_"+str(batch.biome_id)+"_"+str(batch.kind);node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if shadows and batch.get("shadows",true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;var nodes:Array=[node]
		if batch.has("source_basins"):node.set_meta("source_basins",batch.source_basins.duplicate())
		if batch.has("far_kind"):
			var far_material:ShaderMaterial=provider.feature_material(str(batch.far_kind),definition.material_configuration,common)
			if far_material==null or far_material.shader==null:node.free();discard(prepared);return false
			var distance:float=float(batch.get("near_distance",32));node.visibility_range_end=distance;var proxy:=MeshInstance3D.new();proxy.name=node.name+"_OpaqueFar";proxy.mesh=mesh;proxy.material_override=far_material;proxy.cast_shadow=node.cast_shadow;proxy.visibility_range_begin=distance;nodes.append(proxy)
		var faces:PackedVector3Array=batch.get("collision_faces",arrays[Mesh.ARRAY_VERTEX]);var shape_node:CollisionShape3D
		if not faces.is_empty():
			shape_node=CollisionShape3D.new();shape_node.name="BiomeCollision_"+str(batch.biome_id)+"_"+str(batch.kind);var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);shape_node.shape=shape
		prepared.append({"nodes":nodes,"shape":shape_node})
	for item:Dictionary in prepared:
		for node:Node3D in item.nodes:parent.add_child(node)
		if item.shape!=null:parent.get_node("CaveCollision").add_child(item.shape)
	return true
