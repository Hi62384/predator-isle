extends "res://tools/caves/check_frozen_features.gd"
const Magma=preload("res://scripts/caves/magma_features.gd")
const Scope=preload("res://tools/caves/inspection_scope.gd")
class DiagnosticHeat extends RefCounted:
	func sample(point:Vector3)->Dictionary:return {"heat":1.0,"id":"explicit_controlled_intrusion","surface_witness":Vector3(point.x,200,point.z)}
var viewport:SubViewport
var captures:Dictionary={}
func capture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=viewport.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_magma_molten_fixture_"+label+".png";check(image.save_png(path)==OK,"Native molten clipped surface capture "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			var path:String=folder+"/"+name
			if (name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc")) and Scope.is_dependency(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/magma_cave_definition.tres","res://tools/caves/check_frozen_features.gd"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");var settings:Dictionary=definition.feature_configuration.duplicate();settings.chamber_growth=false;settings.active_pool_chance=1.0;var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	region=Magma.new().decorate_region_with_context(region,flat,73921,settings,400,10,DiagnosticHeat.new());check(region.pools[0].get("fluid_kind","")=="magma","Explicit controlled intrusion admits actual retained side basin")
	var field=Field.new();field.include_surface_air=false;check(field.compile([region],flat,[],region.cave_biome_regions),"Shared canonical field and bed compile")
	var key:=Vector3i.ZERO;var water:Dictionary=Basins.water_cell([region],field,key);var lava:Dictionary=Basins.water_cell([region],field,key,"magma");var result:Dictionary=Magma.new().build(field,key,73921,[region],settings,water);check(water.arrays.is_empty() and not lava.arrays.is_empty(),"Dedicated clipped molten payload excludes freshwater")
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var node:=MeshInstance3D.new();var rock_arrays:Array=Mesher.new().build(field,key,2);var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,rock_arrays);var rock:=StandardMaterial3D.new();rock.albedo_color=Color(.13,.12,.105);rock.roughness=.9;mesh.surface_set_material(0,rock);node.mesh=mesh;root.add_child(node);var body:=StaticBody3D.new();body.name="CaveCollision";node.add_child(body);var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(rock_arrays[Mesh.ARRAY_VERTEX]);collision.shape=shape;body.add_child(collision)
	for batch:Dictionary in result.batches:batch["biome_id"]="magma"
	check(Renderer.attach(node,result.batches,config.biome_regions,false,true),"Shared native renderer accepts real molten shader and nonwalkable fluid")
	var molten:MeshInstance3D=node.get_node_or_null("CaveBiome_magma_molten_volcanic");check(molten!=null and body.get_node_or_null("BiomeCollision_magma_molten_volcanic")==null,"Positive actual molten mesh;no fake solid lava collision")
	var molten_material:ShaderMaterial=molten.mesh.surface_get_material(0);molten_material.set_shader_parameter("lava_time_override",0.0)
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var camera:=Camera3D.new();camera.position=Vector3(32,22.4,39);camera.far=200;viewport.add_child(camera);camera.look_at(Vector3(32,19.6,50));camera.make_current();var light:=OmniLight3D.new();light.position=Vector3(32,24,40);light.omni_range=50;light.light_energy=3;light.shadow_enabled=true;viewport.add_child(light)
	light.visible=false;await capture("natural_emission");light.visible=true;var before:Image=await capture("test_only_lamp");molten.hide();var off:Image=await capture("molten_off");molten.show();var after:Image=await capture("molten_return");check(before.get_data()!=off.get_data() and before.get_data()==after.get_data(),"Dedicated molten shader visibly renders and returns pixel-exact with shader time frozen only in owned diagnostic")
	await physics_frame;await physics_frame;await walk([Vector3(12,20.95,32),Vector3(52,20.95,32),Vector3(12,20.95,32)],"Controlled molten basin retains original dry protected route")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable molten diagnostic source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_magma_molten_fixture.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"molten_vertices":lava.arrays[Mesh.ARRAY_VERTEX].size(),"walks":walks,"scope":"CONTROLLED explicit intrusion and pool chance1 diagnostic,normal saved chance14percent unchanged. Shared original retained side-basin bed/native clipped molten shader/geometry-off/exactreturn and same-way dry route. Test-only lamp/flat host material/shader time frozen for deterministic pixel comparison. Not a normal naturally admitted molten cave,complete Magma route,FPS or reference-art acceptance."},"  "));print("MAGMA_MOLTEN_NATIVE ",checks," vertices=",lava.arrays[Mesh.ARRAY_VERTEX].size()," failures=",failures);node.queue_free();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
