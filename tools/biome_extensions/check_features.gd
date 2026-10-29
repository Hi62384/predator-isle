extends "res://tools/biome_extensions/check_integration.gd"
const Features=preload("res://scripts/terrain_feature_meshes.gd")
func run()->void:
	var cases:Array=[]
	for family_id:int in [1,2,6,7]:
		var b=make_builder(family_id);b.settings.get(TerrainSettings.EXTENSION_KEYS[family_id]).cave_frequency=.5;b.chunk_size=8192;b._configure_noise()
		var found:Dictionary={};var coordinate:=Vector2i.ZERO
		for i in range(64):
			coordinate=Vector2i(i-24,i%7-3);var feature:Dictionary=Features.new().build(b,coordinate)
			if not feature.cavities.is_empty():found=feature;break
		check(not found.is_empty(),"Real dry cavity found "+str(family_id))
		if found.is_empty():continue
		var site:Dictionary=found.cavities[0];var p:Vector2=site.position
		b.chunk_size=256;coordinate=Vector2i(floori(p.x/256),floori(p.y/256));var a:Array=b.build(coordinate,64);var feature:Dictionary=Features.new().build(b,coordinate)
		check(not feature.surfaces[0].is_empty() and not feature.openings.is_empty(),"Portal owns actual cavity mesh")
		var node:=MeshInstance3D.new();node.mesh=mesh_for(a);node.position=Vector3(coordinate.x*256,0,coordinate.y*256);root.add_child(node)
		var cavity:=ArrayMesh.new();cavity.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,feature.surfaces[0]);node.mesh.set_meta("cavity_collision",cavity);node.mesh.set_meta("cavity_portals",feature.openings)
		preload("res://scripts/terrain_collision.gd").stage(node,256,64,true,true);preload("res://scripts/terrain_collision.gd").activate(node,true)
		for i in range(3):await physics_frame
		var space:PhysicsDirectSpaceState3D=node.get_world_3d().direct_space_state
		var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,site.top+10,p.y),Vector3(p.x,site.floor-10,p.y));var hit:Dictionary=space.intersect_ray(q)
		check(not hit.is_empty(),"Portal ray reaches cavity floor")
		if not hit.is_empty():check(absf(hit.position.y-site.floor)<.05,"No invisible terrain over portal")
		var from:=Vector3(p.x+site.half+2,site.floor+10,p.y);var to:=Vector3(p.x+250,site.floor+10,p.y)
		check(space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to)).is_empty(),"Underground doorway/gallery clear")
		var up:=PhysicsRayQueryParameters3D.create(from+Vector3(60,0,0),from+Vector3(60,30,0));up.hit_back_faces=true
		check(not space.intersect_ray(up).is_empty(),"Underground gallery has physical ceiling")
		var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/capsule_probe.gd"));var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var capsule_node:=CollisionShape3D.new();capsule_node.shape=capsule;walker.add_child(capsule_node);root.add_child(walker);walker.position=Vector3(p.x+112,site.floor+1.1,p.y)
		for frame in range(240):
			await physics_frame
		walker.set_physics_process(false)
		check(walker.is_on_floor(),"Capsule remains grounded inside gallery")
		check(walker.position.x>p.x+230 and walker.position.x<p.x+256,"Capsule traverses gallery/end wall family %d, travelled %.2f"%[family_id,walker.position.x-p.x])
		check(absf(walker.position.y-(site.floor+.9))<.15,"Capsule does not tunnel through floor")
		walker.queue_free()
		cases.append({"family":family_id,"site":site,"vertices":feature.surfaces[0][Mesh.ARRAY_VERTEX].size(),"physics_portal_floor":true})
		preload("res://scripts/terrain_collision.gd").release(node);node.queue_free();await process_frame
	var output:Dictionary={"checks":checks,"failures":failures,"cavity_cases":cases,"fixture_cave_frequency":.5,"note":"Native rays plus four-second capsule traversals in four cavity fixtures; not exhaustive world traversal"}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_features.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"));print("FEATURE_CHECKS ",checks," ",failures);quit(0 if failures.is_empty() else 1)
