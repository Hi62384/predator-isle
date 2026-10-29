extends "res://tools/caves/render_crystal_lake_chamber_native.gd"
const Candidate=preload("res://tools/caves/crystal_shore_crossing_candidate.gd")
const SurfaceBiomes=preload("res://scripts/caves/surface_biomes.gd")
const OriginalMesher=preload("res://scripts/caves/portal_mesher.gd")
func inspection_name()->String:return "crystal_shore_crossing_candidate"
func additional_guards()->Dictionary:
	var result:Dictionary=super.additional_guards();var path:String="res://tools/caves/crystal_shore_crossing_candidate.gd";result[path]=FileAccess.get_sha256(path);return result
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var b=owner(inspection_host(),inspection_seed());var config:Resource=inspection_configuration();config.biome_regions=FrozenFixture.registry(config.biome_regions,inspection_definition());var work=Workload.new();check(work.configure(b.settings,config,inspection_seed(),0),"Private shore study uses same original production generator")
	work.discover(inspection_site())
	var originals:Dictionary={};var diagnostics:Array=[];var view:Dictionary=inspection_views(data,{})[0];camera.position=view.position;camera.look_at(view.target);light.position=camera.position+Vector3.UP*.5;light.visible=true
	var original:Image=await crystal_picture("original_linear_shore")
	for node:MeshInstance3D in nodes:
		if node.mesh==null:continue
		var key:=Vector3i(roundi(node.position.x/64),roundi(node.position.y/64),roundi(node.position.z/64))
		if absf(node.position.x+32-data.pool.center.x)>data.pool.radius+36 or absf(node.position.z+32-data.pool.center.z)>data.pool.radius+36:continue
		var candidate=Candidate.new();candidate.shore_center=data.pool.center;candidate.shore_radius=data.pool.radius;var arrays:Array=candidate.build(work.field,key,2)
		if arrays.is_empty():continue
		var control=Candidate.new();var original_arrays:Array=control.build(work.field,key,2);check(var_to_bytes(original_arrays)==var_to_bytes(OriginalMesher.new().build(work.field,key,2)),"Independent zero-refinement mesh equals complete original raw rock arrays")
		check(candidate.attempted_triangles==control.attempted_triangles and arrays[Mesh.ARRAY_VERTEX].size()/3+candidate.collapsed_triangles==original_arrays[Mesh.ARRAY_VERTEX].size()/3+control.collapsed_triangles,"Same sign-case triangle attempts;count difference entirely explained by zero-area welded collapses")
		var topology:Dictionary=Candidate.topology(arrays,node.position);check(topology.collapsed==0 and topology.interior_open_edges==0 and topology.nonmanifold_edges==0,"Refined native mesh has no zero-area faces,internal open edges or nonmanifold edges")
		var complete:Dictionary=SurfaceBiomes.bind(work.decorated(arrays,key),work.field,key);var complete_original:Dictionary=SurfaceBiomes.bind(work.decorated(original_arrays,key),work.field,key);var original_cell:Dictionary={}
		for cell:Dictionary in data.cells:
			if cell.key==key:original_cell=cell;break
		check(complete.valid and not original_cell.is_empty() and var_to_bytes(complete_original.arrays)==var_to_bytes(original_cell.arrays),"Zero refinement retains full original formations and biome material payload before native upload")
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,complete.arrays);mesh.surface_set_material(0,node.mesh.surface_get_material(0));originals[node]=node.mesh;node.mesh=mesh;diagnostics.append({"key":str(key),"refined_edges":candidate.refined_edges,"original_vertices":original_arrays[Mesh.ARRAY_VERTEX].size(),"refined_vertices":arrays[Mesh.ARRAY_VERTEX].size(),"original_collapsed":control.collapsed_triangles,"refined_collapsed":candidate.collapsed_triangles,"interior_open_edges":topology.interior_open_edges,"nonmanifold_edges":topology.nonmanifold_edges,"original_max_scalar_residual":candidate.original_residual,"refined_max_scalar_residual":candidate.refined_residual})
	await crystal_picture("private_bisected_shore_geometry_only")
	for node:MeshInstance3D in originals:node.mesh=originals[node]
	var restored:Image=await crystal_picture("original_shore_return");check(original.get_data()==restored.get_data(),"Private shore study returns exact original geometry image before physics")
	return {"cells":diagnostics,"exact_return":original.get_data()==restored.get_data(),"scope":"PRIVATE geometry-only crossing placement study. Same2m lattice/sign topology;12bisections near selected lake. Candidate colliders NOT installed;subsequent walks use restored original geometry/colliders. No adoption or candidate physical pass."}
