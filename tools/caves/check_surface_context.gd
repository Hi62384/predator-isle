extends "res://tools/biome_extensions/check_all.gd"
const Context=preload("res://scripts/caves/surface_context.gd")
const SurfaceShader=preload("res://scripts/caves/surface_shader.gd")
const PrivateShader=preload("res://tools/caves/cave_surface_shader_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/surface_context.gd","res://scripts/caves/surface_shader.gd","res://scripts/caves/surface_payload.gd","res://shaders/cave_entry_rock.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://tools/caves/check_surface_context.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var arrays:Array=b.build(Vector2i(58,-18),128);var origin:=Vector3(14848,0,-4608);var context=Context.new();check(context.configure([{"id":"original","origin":origin,"span":256.0,"resolution":128,"arrays":arrays,"extension_normalization":true}],b._get_height),"Actual original fine parent snapshot admitted")
	var maximum_error:float=0
	for z in range(0,129,8):
		for x in range(0,129,8):
			var point:Vector3=arrays[Mesh.ARRAY_VERTEX][z*129+x]+origin;var height:float=context.height_at(point.x,point.z);maximum_error=maxf(maximum_error,absf(height-point.y));check(absf(height-point.y)<.00001,"Exact original parent vertices remain exact in snapshot height field");var first:PackedFloat32Array=context.controls("original",Vector2(point.x,point.z));check(first.size()==68 and first==context.controls("original",Vector2(point.x,point.z)),"Complete decoded material controls and warm snapshot cache deterministic")
	var local:=Vector2(74.123,242.321);var point:Vector2=Vector2(origin.x,origin.z)+local;var chosen:Dictionary=preload("res://scripts/caves/surface_payload.gd").triangle(point-Vector2(origin.x,origin.z),256,128);var expected:float=0
	for corner in range(3):expected+=arrays[Mesh.ARRAY_VERTEX][chosen.indices[corner]].y*chosen.weights[corner]
	check(absf(context.height_at(point.x,point.y)-expected)<.00001,"Off-grid surface follows original B-C parent triangle,not a new diagonal")
	check(is_nan(context.height_at(INF,0)),"Nonfinite snapshot queries fail closed before canonical sampler")
	var chunk_origin:=Vector3(14912,64,-4416);var source:Array=[];source.resize(Mesh.ARRAY_MAX);var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	for q:Vector2 in [Vector2(14922,-4380),Vector2(14924,-4380),Vector2(14922,-4378)]:vertices.append(Vector3(q.x,context.height_at(q.x,q.y),q.y)-chunk_origin);normals.append(Vector3.UP)
	source[Mesh.ARRAY_VERTEX]=vertices;source[Mesh.ARRAY_NORMAL]=normals;var groups:Dictionary=context.surfaces(source,chunk_origin);check(groups.valid and groups.groups.has("original") and groups.groups.original.payload.size()==204,"Real surface triangle carries original parent semantics in its own64m chunk coordinates")
	check(groups.collision_faces.to_byte_array()==vertices.to_byte_array(),"Material transport does not move visible/native triangle positions")
	var original:String=FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader");check(SurfaceShader.code(original)==PrivateShader.code(original),"Disabled parent-space/entry options preserve previous GPU-tested complete shader source exactly");var virtual:String=SurfaceShader.code(original,true,true);check(virtual.contains("forest_local_position=VERTEX+cave_parent_offset") and virtual.contains("forest_origin=cave_parent_origin") and virtual.contains("cave_entry_depth=surface_p16.w") and virtual.contains("shade_cave_entry"),"Actual parent coordinate frame and separate entry-depth semantic installed only when requested")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable context source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_context.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"maximum_original_vertex_height_error_m":maximum_error,"production_runtime_enabled_by_default":false,"scope":"Original actual fine Spore parent snapshot:shared vertices,original triangle diagonal,decoded controls,bounded exactF32 height memo,nonfinite input,unchanged new mesh positions and opt-in virtual parent/depth shader construction. Not full native PBR images,actual committed portal or streamed walk."},"  "));print("CAVE_SURFACE_CONTEXT ",checks," maximum_error=",maximum_error," failures=",failures);quit(0 if failures.is_empty() else 1)
