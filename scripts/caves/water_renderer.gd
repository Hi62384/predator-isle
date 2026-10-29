extends RefCounted
## Cave-only view of the existing freshwater shader. No global water resource
## or flood stage is edited. Rock beds remain the sole walking collision.
const VertexProjection=preload("res://scripts/caves/vertex_projection.gd")
static var _materials:Dictionary={}
static func material(common_projection:bool=true)->ShaderMaterial:
	if _materials.has(common_projection):return _materials[common_projection]
	var source:String=FileAccess.get_file_as_string("res://shaders/swamp_water.gdshader")
	var shader:=Shader.new();shader.code=source.replace(" SPECULAR=.4;"," SPECULAR=.4;\n AO=.08;AO_LIGHT_AFFECT=0.0;")
	shader.code=shader.code.replace(" NORMAL_MAP=vec3(.5+r.x,.5+r.y,1);"," r+=vec2(cos(UV2.x),sin(UV2.x))*sin(UV.y*.8-TIME*.8)*swamp_ripple*COLOR.a;\n NORMAL_MAP=vec3(.5+r.x,.5+r.y,1);")
	if common_projection:shader.code=VertexProjection.source(shader.code)
	var result:=ShaderMaterial.new();result.shader=shader;result.set_shader_parameter("swamp_water_opacity",.72);result.set_shader_parameter("swamp_ripple",.004);result.set_shader_parameter("swamp_flood_stage",0.0);_materials[common_projection]=result;return result
static func attach(parent:Node3D,data:Dictionary,common_projection:bool=true)->MeshInstance3D:
	var arrays:Array=data.get("arrays",[])
	if arrays.is_empty():return null
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material(common_projection));var node:=MeshInstance3D.new();node.name="CaveSeepageWater";node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.set_meta("pool_ids",data.get("ids",[]));parent.add_child(node);return node
