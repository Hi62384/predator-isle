extends "res://tools/caves/render_crystal_lake_chamber_native.gd"
## Diagnostic views of the SAME extracted shore; no geometry or collider edits.
func inspection_name()->String:return "crystal_lake_edge_diagnostic"
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var view:Dictionary=inspection_views(data,{})[0];camera.position=view.position;camera.look_at(view.target);light.position=camera.position+Vector3.UP*.5;light.visible=true
	var original:Image=await crystal_picture("shore_original");var water:Array=[]
	for node:Node in nodes:
		for child:Node in node.get_children():
			if child is MeshInstance3D and str(child.name)=="CaveSeepageWater":water.append(child);child.visible=false
	check(not water.is_empty(),"Diagnostic controls actual native retained water")
	await crystal_picture("shore_water_hidden")
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.6,.6,.6);material.roughness=1;var overrides:Dictionary={}
	for node:MeshInstance3D in nodes:
		if node.mesh==null:continue
		overrides[node]=node.material_override;node.material_override=material
	await crystal_picture("shore_plain_rock_water_hidden")
	for node:MeshInstance3D in overrides:node.material_override=overrides[node]
	for node:MeshInstance3D in water:node.visible=true
	var restored:Image=await crystal_picture("shore_return");check(original.get_data()==restored.get_data(),"Shore diagnostic restores exact native original image")
	return {"water_nodes":water.size(),"exact_return":original.get_data()==restored.get_data(),"scope":"Material/water visibility controls only; all native rock geometry and collisions retained."}
