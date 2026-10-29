extends "res://tools/caves/check_frozen_features.gd"
const Candidate=preload("res://tools/caves/candidate_magma_lake_chambers.gd")
class DiagnosticHeat extends RefCounted:
	var enabled:bool=true
	func sample(point:Vector3)->Dictionary:return {"heat":1.0 if enabled else 0.0,"id":"explicit_controlled_lake_intrusion","surface_witness":Vector3(point.x,200,point.z)}
func lake_provider():return Candidate
func additional_features(_parent:Node3D,_field,_key:Vector3i,_region:Dictionary)->int:return 0
func preflight(_region:Dictionary,_height:Callable,_controls:Dictionary,_context,_result:Dictionary)->void:pass
func output_name()->String:return "check_cave_magma_lake_candidate"
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_magma_lake_candidate.gd","res://tools/caves/candidate_magma_lake_chambers.gd","res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();var shift:=Vector3(736,0,736)
	for room:Dictionary in region.nodes:room.point+=shift
	for edge:Dictionary in region.edges:
		for i in range(edge.points.size()):edge.points[i]+=shift
	var pool:Dictionary=region.pools[0];pool.center+=shift;pool.bed.point+=shift;pool["fluid_kind"]="magma";pool["thermal_source"]="explicit_controlled_lake_intrusion";region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";var original:PackedByteArray=var_to_bytes(region);var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var context=DiagnosticHeat.new();var controls:Dictionary={"large_lake_chambers":true,"large_lake_chance":1.0}
	var provider=lake_provider();var result:Dictionary=provider.prepare(region,flat,73921,controls,400,10,context);check(var_to_bytes(region)==original and result.pools[0].get("magma_large_lake",false),"Controlled large lake profile admits without mutating original graph");preflight(region,flat,controls,context,result)
	check(result.pools[0].radius==14 and result.pools[0].bank_lobes[0].chamber_radius==36 and var_to_bytes(result.edges)==var_to_bytes(region.edges),"Bounded14m lake/36m bank,original mandatory routes and floors unchanged")
	check(var_to_bytes(provider.prepare(region,flat,73921,{"large_lake_chambers":false},400,10,context))==original,"Independent profile OFF exact original geography")
	context.enabled=false;check(var_to_bytes(provider.prepare(region,flat,73921,controls,400,10,context))==original,"No explicit source means no enlarged molten lake");context.enabled=true
	var field=Field.new();field.include_surface_air=false;check(field.compile([result],flat,[],result.cave_biome_regions) and Candidate.dry_bank(field,result.pools[0]),"All192 actual dry-bank probes admit same source bed/roof/floor geometry")
	var lake:Dictionary=result.pools[0];var first:Vector3i=field.cell(lake.center-Vector3(40,8,40));var last:Vector3i=field.cell(lake.center+Vector3(40,50,40));var body_count:int=0;var lava_vertices:int=0;var formation_count:int=0
	for z in range(first.z,last.z+1):
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key:=Vector3i(x,y,z);var arrays:Array=Mesher.new().build(field,key,2)
				if not arrays.is_empty():
					var parent:=Node3D.new();parent.position=Vector3(key)*64;var body:=StaticBody3D.new();body.name="CaveCollision";var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body);root.add_child(parent);body_count+=1;formation_count+=additional_features(parent,field,key,result)
				var lava:Dictionary=Basins.water_cell([result],field,key,"magma")
				if not lava.arrays.is_empty():lava_vertices+=lava.arrays[Mesh.ARRAY_VERTEX].size()
	check(lava_vertices>0 and body_count>0,"Actual clipped larger molten surface and same native shared rock collision positive")
	var route:Array[Vector3]=[region.nodes[0].point+Vector3(0,.95,0)];var start_angle:float=atan2(region.nodes[0].point.z-lake.center.z,region.nodes[0].point.x-lake.center.x);var outward:Array[Vector3]=[]
	for station in range(65):var angle:float=start_angle+TAU*station/64;outward.append(lake.center+Vector3(cos(angle)*(lake.radius+2),.95,sin(angle)*(lake.radius+2)))
	route.append_array(outward)
	for i in range(outward.size()-2,-1,-1):route.append(outward[i])
	route.append(route[0]);await physics_frame;await physics_frame;await walk(route,"Private controlled large molten lake complete two-way360degree dry perimeter and original parent return")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+output_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"pool":lake,"bodies":body_count,"molten_vertices":lava_vertices,"formations":formation_count,"walks":walks,"scope":"Controlled explicit intrusion/profile chance1. Provider identity is recorded by tool source;normal saved chance8percent unchanged. Existing shared bed/bank/corridor/mesher/collision,192shore probes and full native two-way360degree dry perimeter/parent return. No normal-frequency/art/FPS/all-user completion claim."},"  "));print("MAGMA_LAKE_CANDIDATE ",checks," molten=",lava_vertices," forms=",formation_count," failures=",failures);quit(0 if failures.is_empty() else 1)
