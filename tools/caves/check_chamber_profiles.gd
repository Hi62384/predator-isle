extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://scripts/caves/network.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/network.gd","res://scripts/caves/chamber_profiles.gd","res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://tools/caves/check_chamber_profiles.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 350
	var water:Callable=func(_x:float,_z:float)->float:return 0
	var total:int=0;var cases:Array=[];var first_pocket:Dictionary={};var first_region:Dictionary={}
	for seed_id:int in [73921,17,92881]:
		var network=Network.new();network.configure(height,water,seed_id);network.activity=1;var region:Dictionary=network.region(Vector2i.ZERO);check(region.valid,"Original flat-region fixture admits a complete graph")
		var pockets:Array=Profiles.make(region,height,seed_id);check(var_to_bytes(pockets)==var_to_bytes(Profiles.make(region,height,seed_id)),"Complete chamber growth descriptors deterministic")
		for pocket:Dictionary in pockets:
			check(pocket.chamber_radius>18 and pocket.chamber_radius<=28,"Genuine broader unequal lobes within per-feature bounds")
			var parent:Dictionary={}
			for node:Dictionary in region.nodes:
				if node.id==pocket.parent:parent=node;break
			check(not parent.is_empty() and pocket.point.y==parent.point.y and Vector2(pocket.point.x-parent.point.x,pocket.point.z-parent.point.z).length()<pocket.chamber_radius+parent.chamber_radius-5,"Overlapping growth joins existing room at exactly its protected floor")
			for edge:Dictionary in region.edges:
				var points:PackedVector3Array=edge.points
				for i in range(points.size()-1):
					var p:=Vector2(pocket.point.x,pocket.point.z);var a:=Vector2(points[i].x,points[i].z);var b:=Vector2(points[i+1].x,points[i+1].z);var closest:Vector2=Geometry2D.get_closest_point_to_segment(p,a,b)
					if closest.distance_to(p)>=pocket.chamber_radius+edge.half_width+2:continue
					var t:float=closest.distance_to(a)/maxf(a.distance_to(b),.000001);var y:float=lerpf(points[i].y,points[i+1].y,t);var difference:float=absf(y-pocket.point.y);check(difference<=.251 or difference>=maxf(pocket.chamber_height,edge.headroom)+2.999,"Independent closest-segment check excludes incompatible near-height floor cuts")
			if first_pocket.is_empty():first_pocket=pocket;first_region=region
		total+=pockets.size();cases.append({"seed":seed_id,"pockets":pockets.size()})
	check(total>=3 and not first_pocket.is_empty(),"Positive connected geological chamber enlargement")
	if not first_pocket.is_empty():
		var expanded:Dictionary=first_region.duplicate(true);expanded.nodes.append(first_pocket);var field=Field.new();check(field.compile([expanded],height),"Actual expanded room volume stays within field bin limits");var point:Vector3=first_pocket.point+Vector3(0,3,0);check(field.sample(point)<0,"Room growth contains real open3Dspace,not metadata-only")
		var key:=Vector3i(floori(point.x/64),floori(point.y/64),floori(point.z/64));var arrays:Array=Mesher.new().build(field,key,2);check(not arrays.is_empty(),"Actual enlarged chamber extracts native/renderable geometry")
	var empty:Dictionary={"valid":false};check(Profiles.make(empty,height,73921).is_empty(),"Rejected region never gains disconnected chambers")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable chamber-profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_chamber_profiles.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"pockets":total,"scope":"Canonical connected unequal room lobes:three original flat graph fixtures,exact deterministic metadata,overlap/same-floor connection,independent near-route floor-cut checks,real implicit open space and extracted mesh. Not yet a production adoption,live walk or reference-art certificate."},"  "));print("CAVE_CHAMBER_PROFILES ",checks," pockets=",total," failures=",failures);quit(0 if failures.is_empty() else 1)
