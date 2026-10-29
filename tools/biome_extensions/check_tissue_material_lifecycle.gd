extends SceneTree
class ControllerFixture:
	extends "res://scripts/chunk_terrain.gd"
	func _ready()->void:pass
	func _process(_delta:float)->void:pass
var checks:int=0
func verify(ok:bool,label:String)->void:checks+=1;assert(ok,label)
func mesh_with(material:ShaderMaterial)->ArrayMesh:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD]);var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material);return mesh
func _initialize()->void:call_deferred("run")
func run()->void:
	var controller=ControllerFixture.new();root.add_child(controller);var shader:=Shader.new();shader.code="shader_type spatial;uniform int debug_view=0;uniform int cliff_normal_debug=0;void fragment(){ALBEDO=vec3(1);}"
	var ground:=ShaderMaterial.new();ground.shader=shader;controller._terrain_material=ground;controller._lod_materials[0]=ground
	var shared:=ShaderMaterial.new();shared.shader=shader;controller._extension_materials.append(shared)
	var clones:Array=[];var nodes:Array=[]
	for index in range(3):
		var material:ShaderMaterial=shared.duplicate();clones.append(material);var mesh:ArrayMesh=mesh_with(ground);mesh.set_meta("extension_structures",mesh_with(material))
		if index==2:controller._mesh_cache[Vector4i(0,0,0,16)]=mesh
		else:
			var node:=MeshInstance3D.new();node.mesh=mesh;nodes.append(node)
			if index==0:controller._active_chunks[Vector3i.ZERO]=node
			else:controller._staged[Vector3i.ONE]=node
	verify(controller._structure_material_variants().size()==4,"Shared,active,staged and cached structure materials enumerated once")
	for mode:int in [3,4,8,149,0]:
		controller.set_debug_view(mode)
		for material:ShaderMaterial in clones+[shared]:verify(material.get_shader_parameter("debug_view")== (260 if mode==149 else mode),"Debug changes reach every structure clone including cached/staged")
	var b=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(73921,true);var path:PackedVector2Array=b._extras[7].network_edges(Vector2i(-2,3));var origin:Vector2=(path[0]/256).floor()*256
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);var vertices:=PackedVector3Array()
	for point:Vector2 in [path[0],path[1],path[2]]:vertices.append(Vector3(point.x-origin.x,0,point.y-origin.y))
	arrays[Mesh.ARRAY_VERTEX]=vertices;var map:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").structure_atlas(b,arrays,origin)
	verify(not map.is_empty(),"Whole finite path has a real material domain")
	verify(map.columns<=129 and map.rows<=129 and map.data.size()<=129*129*16,"Independent full-structure map remains bounded")
	var outside:bool=false
	for vertex:Vector3 in vertices:
		outside=outside or vertex.x<0 or vertex.x>256 or vertex.z<0 or vertex.z>256
		verify(vertex.x>=map.offset.x and vertex.z>=map.offset.y and vertex.x<=map.offset.x+map.span.x and vertex.z<=map.offset.y+map.span.y,"Every owned vertex lies inside its full padded domain")
	verify(outside,"Negative:the old terrain-tile domain does not cover this actual finite path")
	b.settings.alien_infected.nerve_flow_texturing=false;verify(preload("res://scripts/alien_tissue_coordinates.gd").structure_atlas(b,arrays,origin).is_empty(),"Independent disable allocates no shell map")
	var guards:Dictionary={}
	for source:String in ["res://tools/biome_extensions/check_tissue_material_lifecycle.gd","res://scripts/chunk_terrain.gd","res://scripts/alien_tissue_coordinates.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd"]:guards[source]=FileAccess.get_sha256(source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tissue_material_lifecycle.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"checks":checks,"source_sha256":guards,"scope":"Material lifecycle unit:active,staged,cached and shared structure clones receive all declared debug changes. Independent actual finite-path domain example extends beyond its root's256m tile;all path vertices fit a bounded padded material rectangle,while old tile-domain assumption is explicitly rejected. No native scenic certificate."},"  "))
	for node:Node in nodes:node.free()
	controller.free();print("TISSUE_MATERIAL_LIFECYCLE ",checks);quit()
