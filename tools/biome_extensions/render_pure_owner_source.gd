extends SceneTree
func _initialize()->void:call_deferred("run")
func readback()->Image:
	RenderingServer.force_draw(true,0.0);RenderingServer.force_sync();return root.get_texture().get_image()
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	# Beach swash reads TIME. Freeze the shader clock for both A/B captures;
	# water remains disabled and all static material/lighting inputs are shared.
	var settings:Resource=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	await preload("res://scripts/terrain_shader_preparation.gd").prepare(self,settings)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");terrain.set_process(false)
	var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);scene.get_node("Interface").hide();scene.get_node("BlobWorkshop").hide();root.add_child(scene)
	if terrain._water!=null:terrain._water.hide()
	var b=load("res://scripts/terrain_mesh_builder.gd").new();b.settings=settings;b.chunk_size=256;b._configure_noise()
	var arrays:Array=b.build(Vector2i.ZERO,128);var mesh:=ArrayMesh.new();var flags:int=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT if arrays[Mesh.ARRAY_CUSTOM0].size()==arrays[Mesh.ARRAY_VERTEX].size()*4 else Mesh.ARRAY_CUSTOM_RGB_FLOAT)<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for i:int in range(1,4):
		if arrays[Mesh.ARRAY_CUSTOM0+i]!=null:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<[Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][i-1]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	var node:=MeshInstance3D.new();node.mesh=mesh;scene.add_child(node)
	var material:ShaderMaterial=terrain._terrain_material.duplicate();mesh.surface_set_material(0,material)
	var source:String=load("res://shaders/terrain_biomes.gdshader").code
	source=source.replace('#include "res://shaders/beach_material.gdshaderinc"',FileAccess.get_file_as_string("res://shaders/beach_material.gdshaderinc").replace("TIME","0.0"))
	var original:=Shader.new();original.code=preload("res://scripts/terrain_shader_variants.gd").source_for(source,191)
	var candidate:=Shader.new();candidate.code=preload("res://tools/biome_extensions/pure_owner_shader_candidate.gd").source_for(source,128,-4)
	# This declared coast fixture must really be fully coast-owned at EVERY
	# original vertex;otherwise a forced branch would be an invalid comparison.
	var controls:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM1]
	for i:int in range(arrays[Mesh.ARRAY_VERTEX].size()):
		assert(controls[i*4+2]<0 and ((int(-controls[i*4+2]-1)>>8)&255)==255,"Actual coast fixture supplies a proven pure base")
	var center:=Vector3(128,b._get_height(128,128),128);camera.position=center+Vector3(0,60,190);camera.look_at(center);camera.near=.5
	for frame:int in range(20):await process_frame
	# All following A/B/return draws have zero simulation/time steps.
	var cases:Array=[];var failed:bool=false
	for debug:int in [0,3,4,8,180,190]:
		material.set_shader_parameter("debug_view",debug);material.shader=original;var before:Image=await readback();material.shader=candidate;var actual:Image=await readback();material.shader=original;var returned:Image=await readback()
		var exact:bool=before.get_data()==actual.get_data() and before.get_data()==returned.get_data();failed=failed or not exact;cases.append({"debug":debug,"exact":exact,"candidate_equal":before.get_data()==actual.get_data(),"original_return_equal":before.get_data()==returned.get_data()});print("PURE_OWNER_SOURCE ",cases[-1])
		if debug==0:
			before.save_png("res://tools/biome_extensions/artifacts/pure_owner_original.png");actual.save_png("res://tools/biome_extensions/artifacts/pure_owner_candidate.png");returned.save_png("res://tools/biome_extensions/artifacts/pure_owner_return.png")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_pure_owner_source.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"cases":cases,"scope":"One actual coast-owned128grid tile; original configured shader/pure-base shader/original exact complete-image comparisons. Original geometry,material uniforms,camera and lighting;water hidden only to exclude animation."},"  "))
	scene.queue_free();await process_frame;quit(1 if failed else 0)
