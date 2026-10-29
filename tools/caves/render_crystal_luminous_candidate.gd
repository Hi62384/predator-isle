extends "res://tools/caves/render_crystal_world.gd"
const Luminous=preload("res://tools/caves/crystal_luminous_candidate.gd")
func inspection_name()->String:return "crystal_luminous_candidate"
func selected_room_id()->String:return "6:-2:3:3:lobe:0"
func selection_label()->String:return "Original fixed73921 CrystalWastes(6,-2) quartz pocket used by complete private luminous payload check;no substituted site"
func inspection_control_scope()->String:return "PRIVATE luminous mechanism only:region/form selection forced1 with hard10percent cell cap;normal region.005/form.12 not edited. Original normal18percent Crystal/density/geometry retained."
func additional_guards()->Dictionary:return {"res://tools/caves/crystal_luminous_candidate.gd":FileAccess.get_sha256("res://tools/caves/crystal_luminous_candidate.gd")}
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var settings:Dictionary={"luminous_minerals":true,"luminous_region_chance":1.0,"luminous_form_chance":1.0};var prepared:Array=[];var target:Dictionary={};var tagged:int=0;var total:int=0
	for cell:Dictionary in data.cells:
		var forms:Array=[]
		for form:Dictionary in data.placements:
			if form.owner==cell.key:forms.append(form)
		var payload:Dictionary={"placements":forms,"batches":cell.get("features",[])};var candidate:Dictionary=Luminous.apply(payload,data.bundle.regions,73921,settings)
		for form:Dictionary in candidate.placements:
			if form.kind=="crystal":total+=1
			if form.get("fictional_emission",false):
				tagged+=1
				if str(form.id).begins_with(str(data.room.id)+"/") and (target.is_empty() or str(form.id)<str(target.id)):target=form
		var node:MeshInstance3D=null
		for instance:MeshInstance3D in nodes:
			if instance.position==Vector3(cell.key)*64:node=instance;break
		if node==null:continue
		for batch:Dictionary in candidate.batches:
			if str(batch.get("biome_id",""))!="crystal" or str(batch.kind)!="mineral_opaque":continue
			var child:MeshInstance3D=node.get_node_or_null("CaveBiome_crystal_mineral_opaque")
			if child==null:continue
			var original:Material=child.mesh.surface_get_material(0);var material:ShaderMaterial=original.duplicate();var shader:Shader=material.shader.duplicate();shader.code=shader.code.replace("uniform bool cave_crystal_bed=false;","uniform bool cave_crystal_bed=false;\nuniform float cave_crystal_luminous_strength=0.0;");shader.code=shader.code.replace(" // SELECTIVE_NEAR_TRANSMISSION"," if(UV.y<0.0){vec3 fictional_tint=kind%3==0?vec3(.14,.65,.8):(kind%3==1?vec3(.42,.22,.8):vec3(.16,.36,.8));EMISSION=fictional_tint*cave_crystal_luminous_strength;}\n // SELECTIVE_NEAR_TRANSMISSION");material.shader=shader;material.set_shader_parameter("cave_crystal_luminous_strength",0.0);var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,batch.arrays,[],batch.get("lods",{}));mesh.surface_set_material(0,material);prepared.append({"node":child,"original":child.mesh,"candidate":mesh,"material":material})
	check(not prepared.is_empty() and not target.is_empty() and tagged>0 and tagged<=floori(total*.1),"Actual original selected pocket contains positive private tagged prisms and majority ordinary minerals")
	if target.is_empty():return {"tagged":tagged,"total":total,"failed":"No owned target;original selection retained"}
	camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(target.bounds.get_center());light.visible=false;var original:Image=await crystal_picture("original_natural")
	for item:Dictionary in prepared:item.node.mesh=item.candidate
	var off:Image=await crystal_picture("fictional_emission_zero");check(original.get_data()==off.get_data(),"UV sign flag with emission zero returns exact original natural scene")
	for item:Dictionary in prepared:item.material.set_shader_parameter("cave_crystal_luminous_strength",.025)
	var on:Image=await crystal_picture("faint_fictional_emission_on");check(on.get_data()!=off.get_data(),"Selected fictional minerals visibly emit in native low light without added lights")
	for item:Dictionary in prepared:item.material.set_shader_parameter("cave_crystal_luminous_strength",0.0)
	var zero_return:Image=await crystal_picture("fictional_emission_zero_return");check(off.get_data()==zero_return.get_data(),"Independent strength control restores exact zero-emission native image")
	for item:Dictionary in prepared:item.node.mesh=item.original
	var restored:Image=await crystal_picture("original_natural_return");check(original.get_data()==restored.get_data(),"Complete original native meshes/materials restored before ordinary physics")
	return {"tagged":tagged,"ordinary_crystals":total,"strength":.025,"target":str(target.id),"visible":on.get_data()!=off.get_data(),"exact_return":original.get_data()==restored.get_data(),"scope":"PRIVATE forced selection mechanism on actual normal-world mineral meshes;lossless sign bit,existing opaque batches,zero extra Light3D nodes/particles,exact original/zero/on/zero/original. Native original collisions unchanged and subsequent original same-way walk. No normal rare occurrence or production adoption claim."}
