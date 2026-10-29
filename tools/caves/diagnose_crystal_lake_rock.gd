extends "res://tools/caves/render_crystal_lake.gd"
func inspection_name()->String:return "diagnose_crystal_lake_rock"
func selection_label()->String:return super.selection_label()+" DIAGNOSTIC ONLY:Default formation density0,all Crystal colliders ON;original underlying rock/stream/bed,site and route unchanged."
func inspection_configuration()->Resource:
	var config:Resource=super.inspection_configuration();config.formation_density=0;return config
func walk_probe_script()->Script:
	var script:=GDScript.new();script.source_code="extends \"res://tools/biome_extensions/route_probe.gd\"\nvar drop_records:Array=[]\nfunc _physics_process(delta:float)->void:\n\tvar previous:float=max_unsupported_drop;super._physics_process(delta)\n\tif max_unsupported_drop>previous+.001 and drop_records.size()<1024:\n\t\tvar hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*3,position-Vector3.UP*8));var owner_name:String=\"none\"\n\t\tif not hit.is_empty():var collider:CollisionObject3D=hit.collider;owner_name=str(collider.shape_owner_get_owner(collider.shape_find_owner(hit.shape)).name)\n\t\tdrop_records.append({\"waypoint\":waypoint,\"position\":position,\"drop_m\":max_unsupported_drop,\"native_hit\":hit.get(\"position\",Vector3.INF),\"native_shape\":owner_name})\n";check(script.reload()==OK,"Private original ordinary walker only records unsupported-drop location,not a movement change");return script
func walk_extra_details(walker)->Dictionary:return {"drop_records":walker.drop_records}
