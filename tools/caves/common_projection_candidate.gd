extends RefCounted
const Production=preload("res://scripts/caves/vertex_projection.gd")
## Private numeric experiment:all tiles compose a shared camera-grid-relative
## world point before projection,not independently rounded MODELVIEW origins.
const CODE:String="""
 vec3 cave_shared_origin=floor(INV_VIEW_MATRIX[3].xyz/4096.0)*4096.0;
 vec3 cave_relative_world=(MODEL_MATRIX[3].xyz-cave_shared_origin)+mat3(MODEL_MATRIX)*VERTEX;
 vec3 cave_origin_view=(VIEW_MATRIX*vec4(cave_shared_origin,1.0)).xyz;
 POSITION=PROJECTION_MATRIX*vec4(mat3(VIEW_MATRIX)*cave_relative_world+cave_origin_view,1.0);
"""
static func mask()->ShaderMaterial:
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,fog_disabled;void vertex(){"+CODE+"}void fragment(){ALBEDO=vec3(.65,.02,.02);}";var material:=ShaderMaterial.new();material.shader=shader;return material
static func production_mask(common:bool=true)->ShaderMaterial:
	var shader:=Shader.new();shader.code=Production.source("shader_type spatial;render_mode unshaded,fog_disabled;void vertex(){}void fragment(){ALBEDO=vec3(.65,.02,.02);}");var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("cave_common_projection",common);return material
