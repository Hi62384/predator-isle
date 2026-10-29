extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://tools/caves/cave_network_candidate.gd")
const PREVIEWS="res://tools/biome_extensions/artifacts/revisions/experiment_insect_earth_trial_6eec1813dcd5/sources/tools/biome_extensions/artifacts/previews.json.txt"
func run()->void:
	# Existing frozen geographic fixtures are retained even when a region fails
	# admission. No seed/root search is substituted for a failed original cell.
	var preview_path:String="res://tools/biome_extensions/artifacts/previews.json"
	var guards:Dictionary={preview_path:FileAccess.get_sha256(preview_path)};var previews=JSON.parse_string(FileAccess.get_file_as_string(preview_path));var cases:Array=[];var admitted:int=0
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]
	for path:String in ["res://tools/caves/check_network_terrain.gd","res://tools/caves/cave_network_candidate.gd","res://tools/caves/cave_route_solver_candidate.gd","res://tools/biome_extensions/check_all.gd"]:guards[path]=FileAccess.get_sha256(path)
	for family in range(8):
		var b=make_builder(family,73921);var key:String=TerrainSettings.EXTENSION_KEYS[family];var fixture:Dictionary=previews.families[key].primary;var p:=Vector2(fixture.x,fixture.z);var cell:=Vector2i(floori(p.x/1536),floori(p.y/1536));var network=Network.new();network.configure(b._get_height,b.get_water_surface_height,73921);network.activity=1
		var start:int=Time.get_ticks_usec();var data:Dictionary=network.region(cell);var seconds:float=(Time.get_ticks_usec()-start)/1000000.0;var minimum_roof:float=INF;var maximum_depth:float=0;var samples:int=0;var violations:int=0
		if data.valid:
			admitted+=1;var reached:Dictionary={data.entrances[0]:true}
			for repeat_id in range(data.nodes.size()):
				for edge:Dictionary in data.edges:
					if reached.has(edge.from):reached[edge.to]=true
					if reached.has(edge.to):reached[edge.from]=true
			check(reached.size()==data.nodes.size(),"Actual terrain component has an exit for every retained node")
			for edge:Dictionary in data.edges:
				var points:PackedVector3Array=edge.points
				for i in range(points.size()-1):
					var a:Vector3=points[i];var c:Vector3=points[i+1];var direction:=Vector2(c.x-a.x,c.z-a.z);var distance:float=direction.length();var side:=Vector2(-direction.y,direction.x).normalized()
					check(absf(c.y-a.y)<=distance*.2+.0002,"Packed actual floor points retain conservative grade within0.2mm storage allowance")
					for fraction:float in [0.0,.5,1.0]:
						var center:Vector3=a.lerp(c,fraction)
						for lateral:float in [-4.0,-2.0,0.0,2.0,4.0]:
							var q:=Vector2(center.x,center.z)+side*lateral;var surface:float=b._get_height(q.x,q.y);var depth:float=surface-center.y;maximum_depth=maxf(maximum_depth,depth);samples+=1
							if not edge.entrance:minimum_roof=minf(minimum_roof,depth-8)
							if depth>398.001 or (not edge.entrance and depth-8<9.999):violations+=1
			check(violations==0,"Independent inter-station/lateral actual canonical depth and roof constraints")
		else:check(data.nodes.is_empty() and data.edges.is_empty() and data.entrances.is_empty(),"Rejected original cell admits no inaccessible partial component")
		cases.append({"family":key,"seed":73921,"original_fixture":p,"cell":str(cell),"admitted":data.valid,"reason":data.reason,"nodes":data.nodes.size(),"edges":data.edges.size(),"seconds":seconds,"independent_samples":samples,"independent_violations":violations,"minimum_independent_roof_m":minimum_roof if is_finite(minimum_roof) else null,"maximum_independent_depth_m":maximum_depth});print("CAVE_ACTUAL_TERRAIN ",cases.back())
	check(admitted>0,"Real canonical terrain produces at least one nonempty exit-rooted component,not synthetic fields only")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual cave dependency source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_network_terrain.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"admitted_original_cells":admitted,"production_registration":false,"scope":"PRIVATE original frozen geographic cells for all eight actual canonical extension hosts,seed73921,not a substitute positive search. Full explicit exit connectivity and independent segment-midpoint/lateral roof/depth/packed-grade checks;rejected cells retain no partial component.400mdepth/10mroof/8mclearance/.2grade unchanged. This does not establish native mesh/capsule/portal/streaming,legacy-owner coverage,all-world terrain or an installed cave system."},"  "));print("CAVE_NETWORK_TERRAIN ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
