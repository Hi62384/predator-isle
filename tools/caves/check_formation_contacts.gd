extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const Forms=preload("res://scripts/caves/formations.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/formations.gd","res://tools/caves/check_formation_contacts.gd"]:guards[path]=FileAccess.get_sha256(path)
	var surface:Callable=func(_x:float,_z:float)->float:return 150
	var field=Field.new();check(field.compile([{"valid":true,"nodes":[{"point":Vector3(32,20,32),"level":0,"chamber_radius":28.0,"chamber_height":20.0}],"edges":[]}],surface),"Bounded complete closed chamber fixture")
	var arrays:Array=Mesher.new().build(field,Vector3i.ZERO,2);var base:=StaticBody3D.new();base.collision_layer=1;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;base.add_child(child);root.add_child(base)
	for frame in range(3):await physics_frame
	var seeds:Array[int]=[1,2,3,4,5,6,7,8,9,10,11,12,73921,17,92881];var forms:int=0;var columns:int=0;var feet:int=0;var floating:int=0;var kinds:Dictionary={};var minimum_embedding:float=INF;var column_cases:Array=[];var first_column:Dictionary={}
	for seed_id:int in seeds:
		var builder=Forms.new();var data:Dictionary=builder.build(field,Vector3i.ZERO,seed_id,0,1);var first:int=0
		check(var_to_bytes(data)==var_to_bytes(builder.build(field,Vector3i.ZERO,seed_id,0,1)),"Complete attached growth remains deterministic")
		for form:Dictionary in data.placements:
			forms+=1;kinds[form.kind]=true
			if form.kind=="column":columns+=1;first+=1;check(form.attachments.size()==2,"Joined column has independently attached floor and ceiling feet");first_column=form
			for attachment_index in range(form.attachments.size()):
				var direction:float=-1 if form.kind=="column" and attachment_index==1 else form.up
				for point:Vector3 in form.attachments[attachment_index]:
					feet+=1;check(field.sample(point)>0,"Every irregular attachment-ring vertex is buried in actual implicit rock,not a floating disk")
					var hit:Dictionary=base.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3(0,direction*2,0),point-Vector3(0,direction*2,0),1));check(not hit.is_empty(),"Every complete-foot contact tested against original native extracted chamber")
					if not hit.is_empty():
						var embedding:float=(hit.position.y-point.y)*direction;minimum_embedding=minf(minimum_embedding,embedding)
						if embedding<.05:floating+=1
		column_cases.append({"seed":seed_id,"forms":data.placements.size(),"columns":first})
		if first>0:
			var body:=StaticBody3D.new();body.collision_layer=2;var collision:=CollisionShape3D.new();var physical:=ConcavePolygonShape3D.new();physical.backface_collision=true;physical.set_faces(data.arrays[Mesh.ARRAY_VERTEX]);collision.shape=physical;body.add_child(collision);root.add_child(body)
			for frame in range(2):await physics_frame
			var center:Vector3=first_column.root+Vector3(0,first_column.height*.5,0);var hit:Dictionary=body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3(first_column.radius*2,0,0),center,2));check(not hit.is_empty(),"Actual joined column midspan has native collision,not only a descriptor or disconnected pair")
			body.queue_free();await process_frame
	check(forms>30 and columns>0 and kinds.has("stalactite") and kinds.has("stalagmite") and kinds.has("flowstone"),"Predeclared fixed ensemble includes actual stalagmites,stalactites,broad flowstone AND rare joined columns")
	var breakdown:Dictionary=Forms.new().build(field,Vector3i.ZERO,73921,3,1);check(not breakdown.placements.is_empty(),"Actual breakdown geology has integrated angular rock deposits")
	for form:Dictionary in breakdown.placements:check(form.kind=="breakdown" and form.up==1 and form.attachments.size()==1,"Breakdown rocks grow from real supported floor,not arbitrary ceiling scatter")
	check(floating==0 and minimum_embedding>=.05,"Complete measured feet stay inside actual native rock with50mm minimum contact margin")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable full-foot source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_formation_contacts.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"forms":forms,"columns":columns,"attachment_vertices":feet,"floating_native_contacts":floating,"minimum_native_embedding_m":minimum_embedding,"cases":column_cases,"scope":"Predeclared15seed closed-chamber control ensemble with genuine production field/mesher/formations. Every complete irregular mineral foot measured against both implicit solid and native extracted rock;floor-to-ceiling columns have two independently attached feet and positive native midspan collision. No site reroll,all-world art or live-streaming certificate."},"  "));print("CAVE_FORMATION_CONTACTS ",checks," forms=",forms," columns=",columns," feet=",feet," floating=",floating," minimum_embedding=",minimum_embedding," failures=",failures);base.queue_free();quit(0 if failures.is_empty() else 1)
