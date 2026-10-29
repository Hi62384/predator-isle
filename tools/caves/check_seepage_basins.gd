extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://scripts/caves/network.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const Field=preload("res://scripts/caves/field.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/network.gd","res://scripts/caves/chamber_profiles.gd","res://scripts/caves/seepage_basins.gd","res://scripts/caves/field.gd","res://tools/caves/check_seepage_basins.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 350
	var water:Callable=func(_x:float,_z:float)->float:return 0
	var total:int=0;var water_triangles:int=0
	for seed_id:int in [73921,17,92881]:
		var n=Network.new();n.configure(height,water,seed_id);n.activity=1;var region:Dictionary=n.region(Vector2i.ZERO);region.geology=0;var basins:Array=Basins.make(region,seed_id,1);check(var_to_bytes(basins)==var_to_bytes(Basins.make(region,seed_id,1)),"Exact independent basin regeneration")
		check(Basins.make(region,seed_id,0).is_empty(),"Independent zero water frequency produces no basins")
		var expanded:Dictionary=region.duplicate(true)
		for basin:Dictionary in basins:expanded.nodes.append(basin.bed);expanded.nodes.append_array(basin.get("bed_lobes",[]))
		var field=Field.new();check(field.compile([expanded],height),"Real water beds participate in same complete cave volume")
		for basin:Dictionary in basins:
			check(basin.water_y<basin.center.y and basin.bed_y<basin.water_y,"Retained level below dry walking shelf and above real bed")
			var arrays:Array=Basins.water_arrays(basin);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];water_triangles+=vertices.size()/3
			for i in range(0,vertices.size(),3):
				check((vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized().dot(Vector3.UP)>.999,"Actual clockwise upward water geometry,not mismatched normals")
			for point:Vector3 in vertices:check(absf(point.y-basin.water_y)<.00001 and field.sample(point)<0,"Every visible calm-water vertex stays inside real carved basin air")
			for edge:Dictionary in region.edges:
				var points:PackedVector3Array=edge.points
				for i in range(points.size()-1):
					var a:=Vector2(points[i].x,points[i].z);var b:=Vector2(points[i+1].x,points[i+1].z);var p:=Vector2(basin.center.x,basin.center.z);var closest:Vector2=Geometry2D.get_closest_point_to_segment(p,a,b);var t:float=closest.distance_to(a)/maxf(a.distance_to(b),.000001);var floor_y:float=lerpf(points[i].y,points[i+1].y,t)
					if floor_y+edge.headroom>basin.bed_y-.5 and floor_y<basin.water_y+1:check(closest.distance_to(p)>=basin.radius+edge.half_width+1.999,"Independent retained dry protected-route clearance")
			total+=1
	check(total>0 and water_triangles>0,"Positive real retained basin/water geometry,not eligibility-only descriptors")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable seepage source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_seepage_basins.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"basins":total,"water_triangles":water_triangles,"scope":"Three deterministic flat graph controls;actual carved side beds and level water mesh,independent dry-route clearance,correct winding,all water vertices inside actual cave air and exact zero mode. Candidate module,not yet connected to live production generation or water rendering acceptance."},"  "));print("CAVE_SEEPAGE_BASINS ",checks," basins=",total," triangles=",water_triangles," failures=",failures);quit(0 if failures.is_empty() else 1)
