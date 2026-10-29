extends "res://tools/biome_extensions/check_all.gd"
const Palette=preload("res://scripts/caves/material_palette.gd")
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
var captures:Dictionary={}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_insect_palette_"+label+".png";check(image.save_png(path)==OK,"Native compact earth palette image "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/material_palette.gd","res://scripts/caves/streamer.gd","res://scripts/caves/surface_renderer.gd","res://scripts/caves/cave_settings.gd","res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://shaders/default_cave_rock.gdshader","res://shaders/cave_entry_rock.gdshaderinc",Palette.COLORS,Palette.NORMALS,Palette.INSECT_COLORS,Palette.INSECT_NORMALS,"res://scenes/main.tscn","res://tools/caves/check_insect_palette.gd"]:guards[path]=FileAccess.get_sha256(path)
	var full_colors:Texture2DArray=load(Palette.COLORS);var full_normals:Texture2DArray=load(Palette.NORMALS);var compact_colors:Texture2DArray=load(Palette.INSECT_COLORS);var compact_normals:Texture2DArray=load(Palette.INSECT_NORMALS)
	check(full_colors.get_layers()==8 and full_normals.get_layers()==8 and compact_colors.get_layers()==1 and compact_normals.get_layers()==1,"Actual eight-layer reference and one-layer Insect banks")
	check(compact_colors.get_width()==2048 and compact_normals.get_width()==2048 and compact_colors.has_mipmaps() and compact_normals.has_mipmaps(),"Full original2Kresolution and mip chains retained,not downgraded to pass memory")
	for pair:Array in [[full_colors,compact_colors],[full_normals,compact_normals]]:
		var original:Image=pair[0].get_layer_data(7);var compact:Image=pair[1].get_layer_data(0);check(original.get_format()==compact.get_format() and original.get_size()==compact.get_size() and original.get_data()==compact.get_data(),"Complete actual GPU layer readback byte-identical,including color roughness or normal channels")
	var reference_bytes:int=0;var compact_bytes:int=0
	for index in range(Palette.RECORDS.size()):
		var record:Array=Palette.RECORDS[index]
		for path:String in ["res://materials/"+record[3]+".res","res://materials/cave_normal_"+record[0]+".res"]:
			guards[path]=FileAccess.get_sha256(path);var source:Image=load(path);reference_bytes+=source.get_data_size()
			if index==7:compact_bytes+=source.get_data_size()
	check(reference_bytes==89478912 and compact_bytes==11184864,"Actual shared compressed palette payload89.48MB→11.18MB,not private-memory or timing inference")
	var height:Callable=func(_x:float,_z:float)->float:return 150
	var field=Field.new();check(field.compile([{"valid":true,"nodes":[{"point":Vector3(32,20,32),"level":0,"chamber_radius":24.0,"chamber_height":24.0}],"edges":[]}],height),"Complete closed production cave for material comparison");var arrays:Array=Mesher.new().build(field,Vector3i.ZERO,2);var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var original_geometry:PackedByteArray=var_to_bytes(mesh.surface_get_arrays(0));var node:=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;root.add_child(node)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();camera.position=Vector3(32,25,39);camera.look_at(Vector3(32,25,20));var light:=OmniLight3D.new();light.position=Vector3(32,26,35);light.omni_range=32;light.light_energy=2;root.add_child(light)
	var entry:=Shader.new();entry.code="""shader_type spatial;
#include "res://shaders/cave_entry_rock.gdshaderinc"
varying vec3 point_world;varying vec3 normal_world;
void vertex(){point_world=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(3840.0));normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){vec3 base,mapped;float rough;shade_cave_entry(point_world,normalize(normal_world),dFdx(point_world),dFdy(point_world),base,rough,mapped);ALBEDO=base;ROUGHNESS=rough;SPECULAR=.2;NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0)).xyz);AO=.08;AO_LIGHT_AFFECT=0.0;}
"""
	var poses:Array=[Vector3(32,25,39),Vector3(22,25,32),Vector3(40,25,27)];var images:int=0
	for role:int in [0,1]:
		var material:=ShaderMaterial.new();material.shader=load("res://shaders/default_cave_rock.gdshader") if role==0 else entry;mesh.surface_set_material(0,material)
		for pose in range(poses.size()):
			camera.position=poses[pose];camera.look_at(Vector3(32,27,32));light.position=camera.position+Vector3(0,1,0);var reference:Image;var positive:Image
			for phase in range(3):
				var compact:bool=phase==1
				if role==0:Palette.bind(material,6,[],compact)
				else:
					var bank:Dictionary=Palette.paths(6,compact);material.set_shader_parameter("cave_entry_colors",load(bank.colors));material.set_shader_parameter("cave_entry_normals",load(bank.normals));material.set_shader_parameter("cave_entry_geology",6);material.set_shader_parameter("cave_entry_compact_palette",bank.compact)
				var image:Image=await picture("role%d_pose%d_%s"%[role,pose,["full_reference","compact","full_return"][phase]]);images+=1
				if phase==0:reference=image
				elif phase==1:positive=image;check(reference.get_data()==positive.get_data(),"Complete actual same-scene reference/compact pixel equality,role"+str(role)+" pose"+str(pose))
				else:check(reference.get_data()==image.get_data(),"Complete actual same-scene original return equality,role"+str(role)+" pose"+str(pose))
	check(var_to_bytes(mesh.surface_get_arrays(0))==original_geometry,"Actual mesh vertex/normal/color/index arrays unchanged by palette specialization")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable compact palette source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_insect_palette.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"native_images":images,"compressed_reference_bank_bytes":reference_bytes,"compressed_compact_bank_bytes":compact_bytes,"scope":"Actual native GPU exact full-layer readback and18same-scene images,three poses each for production interior and actual shared entry-rock function,full/compact/full returns. Same original2Kclay color+roughness and2KOpenGL normal/mips,unchanged shader calculations/tint/light/geometry. One-layer bank only for Insect style6;false retains complete eight-layer reference. Compressed bank bytes are not process-private/GPU timing savings;fresh live route must separately pass its unchanged2048MiB gate."},"  "));print("CAVE_INSECT_PALETTE ",checks," images=",images," bytes=",reference_bytes,"→",compact_bytes," failures=",failures);node.queue_free();scene.queue_free();light.queue_free();quit(0 if failures.is_empty() else 1)
