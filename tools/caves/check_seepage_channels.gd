extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://scripts/caves/network.gd")
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/network.gd","res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/chamber_profiles.gd","res://scripts/caves/seepage_basins.gd","res://scripts/caves/seepage_surface.gd","res://scripts/caves/water_renderer.gd","res://tools/caves/check_seepage_channels.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 350
	var water:Callable=func(_x:float,_z:float)->float:return 0
	var pools:int=0;var channels:int=0;var vertices:int=0;var flow_vertices:int=0;var first_channel:Dictionary={};var first_field;var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var network=Network.new();network.configure(height,water,seed_id);network.activity=1;var region:Dictionary=network.region(Vector2i.ZERO);region.geology=0;region["pockets"]=Profiles.make(region,height,seed_id);region["pocket_passages"]=Profiles.passages(region,region.pockets);region["pools"]=Basins.make(region,seed_id,1);check(var_to_bytes(region.pools)==var_to_bytes(Basins.make(region,seed_id,1)),"Complete beds,channels and dry admission deterministic")
		var field=Field.new();check(field.compile([region],height),"Complete true3D bed/channel union compiles");var owners:Dictionary={}
		for pool:Dictionary in region.pools:
			pools+=1;var key:Vector3i=field.cell(Vector3(pool.center.x,pool.water_y,pool.center.z));owners[key]=true
			if not pool.has("stream_points"):continue
			channels+=1
			if first_channel.is_empty():first_channel=pool;first_field=field
			for point:Vector3 in pool.stream_points:
				check(Basins.route_clear(point,1.5,point.y,pool.water_y+.1,region),"Every real feeder station excludes main graph routes and enlarged-room necks")
				for edge:Dictionary in region.edges+region.pocket_passages:
					for i in range(edge.points.size()-1):
						var a:Vector3=edge.points[i];var b:Vector3=edge.points[i+1];var closest:Vector2=Geometry2D.get_closest_point_to_segment(Vector2(point.x,point.z),Vector2(a.x,a.z),Vector2(b.x,b.z));var t:float=closest.distance_to(Vector2(a.x,a.z))/maxf(Vector2(a.x-b.x,a.z-b.z).length(),.000001);var floor_y:float=lerpf(a.y,b.y,t)
						if floor_y+edge.headroom>point.y-.5 and floor_y<pool.water_y+1.1:check(closest.distance_to(Vector2(point.x,point.z))>=edge.half_width+3.499,"Independent closest-segment full dry-route clearance")
		var observed:Dictionary={};var region_vertices:int=0
		for key:Vector3i in owners:
			var data:Dictionary=Basins.water_cell([region],field,key);check(data.rejected.is_empty(),"Every retained pool/channel emits a complete valid patch,not hidden rejected metadata");var repeated:Dictionary=Basins.water_cell([region],field,key);check(var_to_bytes(data)==var_to_bytes(repeated),"Complete bounded connected water payload regenerates exactly")
			for id:String in data.ids:check(not observed.has(id),"Whole water patch has one owner across chunk boundaries");observed[id]=true
			if data.arrays.is_empty():continue
			var points:PackedVector3Array=data.arrays[Mesh.ARRAY_VERTEX];vertices+=points.size();region_vertices+=points.size()
			for i in range(0,points.size(),3):check((points[i+2]-points[i]).cross(points[i+1]-points[i]).normalized().dot(Vector3.UP)>.99,"Connected slightly sloping water has actual upward geometry,not just assigned normals")
			for i in range(points.size()):
				var p:Vector3=points[i]+Vector3(key)*64;check(field.sample(p)<-.015 and p.y-data.arrays[Mesh.ARRAY_TEX_UV][i].x>.015,"Every final water vertex has measured air and positive real bed depth")
				if data.arrays[Mesh.ARRAY_COLOR][i].a>.1:flow_vertices+=1;check(data.arrays[Mesh.ARRAY_TEX_UV2][i].x>=0 and data.arrays[Mesh.ARRAY_TEX_UV2][i].x<=TAU,"Channel tangent carried through actual worker water arrays without coastal-water flags")
		check(observed.size()==region.pools.size(),"No admitted pool disappears during full connected surface meshing");cases.append({"seed":seed_id,"pools":region.pools.size(),"water_vertices":region_vertices})
	check(pools>0 and channels>0 and vertices>0 and flow_vertices>0,"Predeclared three-seed soluble controls contain real connected feeder beds and flowing-water data")
	var native_rays:int=0;var native_cells:int=0;var bodies:Array=[]
	if not first_channel.is_empty():
		var low:=Vector3.INF;var high:Vector3=-Vector3.INF
		for p:Vector3 in first_channel.stream_points:low=low.min(p-Vector3(3,2,3));high=high.max(p+Vector3(3,6,3))
		var first:Vector3i=first_field.cell(low);var last:Vector3i=first_field.cell(high)
		for z in range(first.z,last.z+1):
			for y in range(first.y,last.y+1):
				for x in range(first.x,last.x+1):
					var key:=Vector3i(x,y,z);var arrays:Array=Mesher.new().build(first_field,key,2)
					if arrays.is_empty():continue
					var body:=StaticBody3D.new();body.position=Vector3(key)*64;var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);collision.shape=shape;body.add_child(collision);root.add_child(body);bodies.append(body);native_cells+=1
		for frame in range(3):await physics_frame
		for point:Vector3 in first_channel.stream_points:
			var hit:Dictionary=bodies[0].get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,first_channel.water_y+.2,point.z),point-Vector3(0,2,0)));check(not hit.is_empty() and hit.position.y<first_channel.water_y+.15,"Actual optional channel has a native rock bed below gently varying visible water");native_rays+=1
	for body:Node in bodies:body.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable connected seepage source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_seepage_channels.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"pools":pools,"channels":channels,"water_vertices":vertices,"flow_vertices":flow_vertices,"native_cells":native_cells,"native_channel_bed_rays":native_rays,"cases":cases,"scope":"Predeclared3seed flat soluble-geology controls at density1,not actual default-world distribution. Actual enlarged rooms/pool and feeder beds,one clipped connected water patch with measured floor depth,positive gentle-gradient/tangent data,unique ownership/full regeneration and independent dry-route exclusion. Native extracted channel-bed rays on the first canonical positive. No groundwater simulation,flooding,swimming requirement or GPU/frame-performance certificate."},"  "));print("CAVE_SEEPAGE_CHANNELS ",checks," pools=",pools," channels=",channels," vertices=",vertices," flow=",flow_vertices," failures=",failures);quit(0 if failures.is_empty() else 1)
