extends "res://tools/biome_extensions/check_all.gd"
const Palette=preload("res://scripts/caves/material_palette.gd")
const PreviousPalette=preload("res://tools/caves/references/magma_pre_water_filter_palette.gd")
const Frozen=preload("res://scripts/caves/frozen_surface.gd")
const PreviousFrozen=preload("res://tools/caves/references/magma_pre_water_filter_frozen_surface.gd")
func run()->void:
	var water:Array=[]
	for index in range(12):water.append({"center":Vector3(index*20,0,index*30),"water_y":float(index),"radius":float(index+3)})
	for count in range(13):
		var pools:Array=water.slice(0,count)
		var old:=ShaderMaterial.new();var current:=ShaderMaterial.new();old.shader=load("res://shaders/default_cave_rock.gdshader");current.shader=old.shader
		PreviousPalette.bind(old,0,pools);Palette.bind(current,0,pools)
		for parameter:String in ["cave_pool_positions","cave_pool_count","cave_rock_colors","cave_rock_normals","geological_style","cave_compact_palette"]:check(old.get_shader_parameter(parameter)==current.get_shader_parameter(parameter),"Exact previous water-only material binding "+str(count)+" "+parameter)
		var frozen:=Frozen.new();var before:=PreviousFrozen.new()
		var code:String=frozen.source(FileAccess.get_file_as_string("res://shaders/default_cave_rock.gdshader"),0,false)
		var shader:=Shader.new();shader.code=code;old.shader=shader;current.shader=shader
		before.bind_context(old,{"pools":pools});frozen.bind_context(current,{"pools":pools})
		for parameter:String in ["cave_frozen_water_sources","cave_frozen_water_source_count"]:check(old.get_shader_parameter(parameter)==current.get_shader_parameter(parameter),"Exact previous Frozen water-only context "+str(count)+" "+parameter)
		var mixed:Array=pools.duplicate(true)
		for index in range(10):mixed.insert(0,{"fluid_kind":"magma","center":Vector3(1000+index,0,1000),"water_y":10.0,"radius":100.0})
		check(Palette.water_sources(mixed)==pools,"Filter molten sources before applying water capacity "+str(count))
		var filtered:=ShaderMaterial.new();filtered.shader=shader;frozen.bind_context(filtered,{"pools":mixed})
		for parameter:String in ["cave_frozen_water_sources","cave_frozen_water_source_count"]:check(filtered.get_shader_parameter(parameter)==current.get_shader_parameter(parameter),"Molten pools never seed Frozen moisture "+str(count)+" "+parameter)
		current.shader=load("res://shaders/default_cave_rock.gdshader");filtered.shader=current.shader;Palette.bind(current,0,pools);Palette.bind(filtered,0,mixed)
		for parameter:String in ["cave_pool_positions","cave_pool_count"]:check(filtered.get_shader_parameter(parameter)==current.get_shader_parameter(parameter),"Molten pools never seed rock water wetness "+str(count)+" "+parameter)
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/material_palette.gd","res://scripts/caves/frozen_surface.gd","res://tools/caves/references/magma_pre_water_filter_palette.gd","res://tools/caves/references/magma_pre_water_filter_frozen_surface.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_fluid_material_binding.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"scope":"Exact old water-only material parameters at every capacity0..12; mixed molten/water preserves water order and excludes all molten pools before capacity. Geometry and collision code untouched; earlier native walks remain historical evidence,not rerun/rebound."},"  "))
	print("FLUID_MATERIAL_BINDING ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
