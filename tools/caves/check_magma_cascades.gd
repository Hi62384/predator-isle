extends "res://tools/caves/check_frozen_features.gd"
const Cascades=preload("res://scripts/caves/magma_cascades.gd")
const Magma=preload("res://scripts/caves/magma_features.gd")
class Source extends RefCounted:
	var enabled:bool=true
	var id:String="explicit_controlled_cascade_intrusion"
	func sample(_point:Vector3)->Dictionary:return {"heat":1.0 if enabled else 0.0,"id":id}
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd","res://config/caves/biomes/magma_cave_definition.tres","res://shaders/cave_magma_molten.gdshader"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";region.pools[0]["fluid_kind"]="magma";region.pools[0]["thermal_source"]="explicit_controlled_cascade_intrusion";region.pools[0]["source_heat"]=1.0
	var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var source=Source.new();var settings:Dictionary={"molten_cascades":true,"molten_cascade_chance":1.0};var cases:Array=[];var first:Dictionary={}
	for seed_id in range(16):
		var result:Dictionary=Cascades.prepare(region,flat,seed_id,settings,400,10,source);var positive:bool=result.pools[0].has("molten_cascade");cases.append({"seed":seed_id,"admitted":positive})
		check(var_to_bytes(result)==var_to_bytes(Cascades.prepare(region,flat,seed_id,settings,400,10,source)),"Whole molten-film descriptor exactly deterministic")
		if positive and first.is_empty():first=result
	check(not first.is_empty(),"Positive whole measured-wall molten cascade on a real clipped retained pool")
	if first.is_empty():
		FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_cascades.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases},"  "));print("CASCADE_NEGATIVE ",cases);quit(1);return
	var stripped:Dictionary=first.duplicate(true);stripped.pools[0].erase("molten_cascade");check(var_to_bytes(stripped)==var_to_bytes(region),"No added excavation,route,bed,water level or unrelated geometry")
	var disabled:Dictionary=settings.duplicate();disabled.molten_cascades=false;check(var_to_bytes(Cascades.prepare(region,flat,17,disabled,400,10,source))==var_to_bytes(region),"Independent cascade OFF exact original region")
	source.enabled=false;check(var_to_bytes(Cascades.prepare(region,flat,17,settings,400,10,source))==var_to_bytes(region),"No heat witness means no molten film");source.enabled=true;source.id="wrong_source";check(var_to_bytes(Cascades.prepare(region,flat,17,settings,400,10,source))==var_to_bytes(region),"Wrong source identity rejects entire cascade");source.id="explicit_controlled_cascade_intrusion"
	var field=Field.new();var plain=Field.new();field.include_surface_air=false;plain.include_surface_air=false;check(field.compile([first],flat,[],first.cave_biome_regions) and plain.compile([region],flat,[],region.cave_biome_regions),"Original exact same cave volume compiles")
	var cascade:Dictionary=first.pools[0].molten_cascade;check(cascade.vertices.size()==288 and cascade.rise>=5 and cascade.rise<=8 and cascade.width<1,"Bounded96triangle finite molten sheet")
	var attached:int=0;var falling:int=0
	for point:Vector3 in cascade.vertices:
		check(field.sample(point)<-.03,"Every molten vertex lies in actual carved air")
		if point.y>cascade.supported_lip_height+.01:attached+=1;check(Cascades.backing_distance(field,point,field.normal(point))<=.3,"Upper wall film has measured solid contact within30cm")
		else:falling+=1
	check(attached>0 and falling>0 and cascade.free_fall_height>0 and cascade.free_fall_height<=3,"Distinct supported wall film and bounded short exposed fall into actual retained pool")
	check(not is_finite(Cascades.backing_distance(field,region.nodes[0].point+Vector3.UP*6,Vector3.RIGHT)),"Truly unsupported film in open chamber rejects every near backing sample")
	for key:Vector3i in [Vector3i.ZERO,Vector3i(1,0,0)]:check(var_to_bytes(Mesher.new().build(field,key,2))==var_to_bytes(Mesher.new().build(plain,key,2)),"Whole ordinary cave mesh/collision geometry remains byte-exact")
	var base:Dictionary=Basins.water_cell([first],field,Vector3i.ZERO,"magma");var molten:Dictionary=Cascades.append_to(base,[first],Vector3i.ZERO);check(molten.molten_cascades==1 and molten.arrays[Mesh.ARRAY_VERTEX].size()==base.arrays[Mesh.ARRAY_VERTEX].size()+288 and molten.ids==base.ids,"Actual dedicated molten batch appends complete sheet to original pool without new light/source identity")
	var world:=Node3D.new();root.add_child(world);var body:=StaticBody3D.new();body.name="CaveCollision";var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(Mesher.new().build(field,Vector3i.ZERO,2)[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child);world.add_child(body)
	var config=Config.new();var batches:Array=[{"biome_id":"magma","kind":"molten_volcanic","arrays":molten.arrays,"collision_faces":PackedVector3Array(),"source_basins":molten.ids,"shadows":false}];check(Renderer.attach(world,batches,config.biome_regions,false,true),"Actual native dedicated molten material upload with no walkable lava collider")
	await physics_frame;await physics_frame;await walk([Vector3(12,20.95,32),Vector3(52,20.95,32),Vector3(12,20.95,32)],"Original protected route with source-backed wall cascade")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable cascade source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_cascades.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"cascade":cascade,"walks":walks,"scope":"Controlled source/chance1 mechanism:supported upper wall film and separate bounded short exposed fall ending within exact clipped retained pool,full same-source heat/edge checks,no excavation,exact old rock meshes,OFF/cold/wrong-source rejection,native dedicated lava upload/no lava collider and ordinary protected return. Normal rare source-world occurrence and native artistic review remain separate."},"  "));print("MAGMA_CASCADES ",checks," rise=",cascade.rise," failures=",failures);world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
