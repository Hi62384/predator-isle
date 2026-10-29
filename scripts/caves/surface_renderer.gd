extends RefCounted
## Main-thread bridge for numeric surface snapshots and hidden replacement
## nodes. Original parent meshes/materials are never edited here.
const SurfaceShader=preload("res://scripts/caves/surface_shader.gd")
const WaterRenderer=preload("res://scripts/caves/water_renderer.gd")
const Palette=preload("res://scripts/caves/material_palette.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const BiomeMaterials=preload("res://scripts/caves/biome_materials.gd")
const FeatureRenderer=preload("res://scripts/caves/feature_renderer.gd")
static var _shaders:Dictionary={}
static var _shader_ring:Array[String]=[]
static func matches(snapshot:Dictionary,nodes:Array,columns:Dictionary)->bool:
	var seen:Dictionary={}
	for node:MeshInstance3D in nodes:
		if not touches(node,columns):continue
		var id:String=str(node.get_meta("tile",Vector3i.ZERO))
		if not snapshot.sources.has(id):return false
		var source:Dictionary=snapshot.sources[id]
		if source.node!=node or source.mesh!=node.mesh or source.origin!=node.global_position or not node.global_basis.is_equal_approx(Basis.IDENTITY):return false
		seen[id]=true
	return seen.size()==snapshot.sources.size()
static func touches(node:MeshInstance3D,columns:Dictionary)->bool:
	if node.mesh==null:return false
	var aabb:AABB=node.get_aabb();var bounds:=Rect2(Vector2(node.global_position.x+aabb.position.x,node.global_position.z+aabb.position.z),Vector2(aabb.size.x,aabb.size.z))
	for key:Vector2i in columns:
		if bounds.intersects(Rect2(Vector2(key)*64,Vector2.ONE*64)):return true
	return false
static func capture(nodes:Array,columns:Dictionary)->Dictionary:
	var records:Array=[];var sources:Dictionary={}
	for node:MeshInstance3D in nodes:
		if not touches(node,columns):continue
		if not node.global_basis.is_equal_approx(Basis.IDENTITY):return {"valid":false,"reason":"Unsupported rotated/scaled terrain parent"}
		var resolution:int=node.get_meta("resolution",0);var key:Vector3i=node.get_meta("tile",Vector3i.ZERO);var span:float=node.mesh.get_aabb().size.x
		# The first live portal admission uses complete fine leaves. It must not
		# punch through a coarse parent chord hundreds of metres above a valley.
		if key.z!=0 or resolution<1 or span/resolution>2.00001:return {"valid":false,"reason":"Portal awaits complete fine terrain parents"}
		var arrays:Array=node.mesh.get_meta("terrain_cpu_arrays",[]) if node.mesh.has_meta("terrain_cpu_arrays") else node.mesh.surface_get_arrays(0);var material:Material=node.mesh.surface_get_material(0)
		if arrays.is_empty() or not (material is ShaderMaterial):return {"valid":false,"reason":"Missing original surface payload/material"}
		var id:String=str(key);var original_ground:PackedVector3Array=node.mesh.get_meta("collision_data",{}).get("ground_faces",PackedVector3Array())
		records.append({"id":id,"origin":node.global_position,"span":span,"resolution":resolution,"arrays":arrays,"extension_normalization":bool(material.get_shader_parameter("extension_payload_enabled")),"ground_faces":original_ground});sources[id]={"node":node,"mesh":node.mesh,"material":material,"origin":node.global_position,"span":span}
	if records.is_empty():return {"valid":false,"reason":"No parent coverage for portal"}
	# Every proposed column must be covered,not just the center of an entrance.
	for key:Vector2i in columns:
		for fraction:Vector2 in [Vector2(.001,.001),Vector2(.999,.001),Vector2(.001,.999),Vector2(.999,.999)]:
			var point:Vector2=(Vector2(key)+fraction)*64;var covered:bool=false
			for record:Dictionary in records:
				if Rect2(Vector2(record.origin.x,record.origin.z),Vector2.ONE*record.span).has_point(point):covered=true;break
			if not covered:return {"valid":false,"reason":"Incomplete fine parent coverage"}
	return {"valid":true,"records":records,"sources":sources}
static func shader(original:Shader,hive_entry:bool=false,common_projection:bool=true)->Shader:
	var digest:String=original.code.sha256_text()+("/hive/"+SurfaceShader.Extensions.code.sha256_text() if hive_entry else "")+("/shared_projection" if common_projection else "")
	if _shaders.has(digest):return _shaders[digest]
	var code:String=SurfaceShader.code(original.code,true,true,hive_entry,common_projection)
	if code.is_empty():return null
	var result:=Shader.new();result.code=code;var names:Dictionary={}
	for uniform:Dictionary in result.get_shader_uniform_list():names[uniform.name]=true
	if not names.has("cave_surface_payload") or not names.has("cave_hive_entry_material" if hive_entry else "cave_entry_colors") or not names.has("cave_parent_origin"):return null
	if _shader_ring.size()>=8:_shaders.erase(_shader_ring.pop_front())
	_shader_ring.append(digest);_shaders[digest]=result;return result
static func release_uploaded_data(data:Dictionary)->void:
	# Native mesh,texture and shape resources own the uploaded buffers. The
	# pending atomic transaction needs only the cell key after materialization.
	for field:String in ["groups","collision_faces","water","frontiers","features","biome_ids"]:data.erase(field)
static func node(data:Dictionary,sources:Dictionary,interior:ShaderMaterial,style:int,shadows:bool=true,specialize_insect:bool=true)->Dictionary:
	if not data.get("valid",false):return {"valid":false,"reason":data.get("reason","Invalid surface result")}
	var mesh:=ArrayMesh.new();var origin:Vector3=Vector3(data.key)*64;var common_projection:bool=bool(interior.get_meta("cave_common_projection",true))
	for id:String in data.groups:
		var group:Dictionary=data.groups[id];var material:ShaderMaterial=interior
		if id!="__interior__":
			if not sources.has(id):return {"valid":false,"reason":"Original parent material unavailable"}
			var parent:Dictionary=sources[id];material=parent.material.duplicate() as ShaderMaterial;var alternate:Shader=shader(material.shader,style==7,common_projection)
			if alternate==null:return {"valid":false,"reason":"Surface material compilation rejected"}
			var biome_ids:Array=interior.get_meta("biome_ids",[]);var registry:Resource=interior.get_meta("biome_registry",null)
			if not biome_ids.is_empty():alternate=BiomeMaterials.shader(alternate,biome_ids,registry,true)
			if alternate==null:return {"valid":false,"reason":"Cave biome surface adapter rejected"}
			material.shader=alternate;material.set_shader_parameter("cave_parent_offset",origin-parent.origin);material.set_shader_parameter("cave_parent_origin",parent.origin)
			if not biome_ids.is_empty():BiomeMaterials.bind(material,biome_ids,registry,interior.get_meta("biome_context",{}))
			if style==7:
				material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"));material.set_shader_parameter("cave_hive_entry_material",true);material.set_shader_parameter("alien_tissue_variation_enabled",interior.get_shader_parameter("alien_tissue_variation_enabled"))
			else:
				var bank:Dictionary=Palette.paths(style,specialize_insect);material.set_shader_parameter("cave_entry_geology",style);material.set_shader_parameter("cave_entry_colors",load(bank.colors));material.set_shader_parameter("cave_entry_normals",load(bank.normals));material.set_shader_parameter("cave_entry_compact_palette",bank.compact)
			var atlas:Dictionary=group.atlas;material.set_shader_parameter("cave_surface_payload",ImageTexture.create_from_image(Image.create_from_data(atlas.width,atlas.height,false,Image.FORMAT_RGBAF,atlas.bytes)))
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,group.arrays);mesh.surface_set_material(mesh.get_surface_count()-1,material)
	if mesh.get_surface_count()==0 and data.get("frontiers",{}).is_empty() and data.get("features",[]).is_empty():return {"valid":true,"node":null}
	var result:=MeshInstance3D.new();result.mesh=mesh;result.position=origin;result.visible=false;result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;result.set_meta("cave_cell",data.key);var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=0;body.collision_mask=0
	if not data.collision_faces.is_empty():
		var shape_node:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(data.collision_faces);shape_node.shape=shape;body.add_child(shape_node)
	result.add_child(body)
	if not FeatureRenderer.attach(result,data.get("features",[]),interior.get_meta("biome_registry",null),common_projection,shadows):result.free();return {"valid":false,"reason":"Cave biome feature material rejected"}
	WaterRenderer.attach(result,data.get("water",{}),common_projection);Frontiers.attach(result,data.get("frontiers",{}),interior,shadows);return {"valid":true,"node":result}
