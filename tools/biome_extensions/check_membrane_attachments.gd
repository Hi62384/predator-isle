extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/membrane_junction_candidate.gd")
func inside(vertices:PackedVector3Array,p:Vector3)->bool:
	# Independent two-sided triangle ray parity in local numeric coordinates.
	var direction:=Vector3(.73,.41,.17).normalized();var hits:Array[float]=[]
	for i in range(0,vertices.size(),3):
		var a:Vector3=vertices[i];var ab:Vector3=vertices[i+1]-a;var ac:Vector3=vertices[i+2]-a;var cross_value:Vector3=direction.cross(ac);var determinant:float=ab.dot(cross_value)
		if absf(determinant)<.00000001:continue
		var offset:Vector3=p-a;var u:float=offset.dot(cross_value)/determinant
		if u<-.000001 or u>1.000001:continue
		var q:Vector3=offset.cross(ab);var v:float=direction.dot(q)/determinant
		if v<-.000001 or u+v>1.000001:continue
		var distance:float=ac.dot(q)/determinant
		if distance<=.00001:continue
		var duplicate:bool=false
		for previous:float in hits:
			if absf(previous-distance)<.001:duplicate=true;break
		if not duplicate:hits.append(distance)
	return hits.size()%2==1
func nearest(points:Dictionary,p:Vector3)->Vector3:
	var best:=Vector3.INF;var distance:float=INF
	for q:Vector3 in points:
		var d:float=p.distance_squared_to(q)
		if d<distance:distance=d;best=q
	return best
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd","res://scripts/alien_junction_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/junction_flutes_candidate.gd","res://tools/biome_extensions/membrane_geometry_candidate.gd","res://tools/biome_extensions/membrane_junction_candidate.gd","res://tools/biome_extensions/check_membrane_attachments.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));check(admission.passed,"Actual default-root identities")
	var cases:Array=[];var bad_anchors:Array=[]
	for item:Dictionary in admission.cases:
		var default_point:=Vector2(item.position[0],item.position[1]);var cell:=Vector2i(floori(default_point.x/4096),floori(default_point.y/4096))
		for scale_value:float in [.2,1,2]:
			var b=make_builder(7,int(item.seed));b.settings.alien_infected.feature_scale=scale_value;b._configure_noise();var field=b._extras[7];var p:Vector2=field.hive_node(cell);var edges:PackedVector2Array=field.network_edges(cell);var d:Dictionary=field.descriptor(cell,4096*scale_value)
			var axis:Vector2=(edges[1]-p).normalized();var side:=Vector2(-axis.y,axis.x);var directions:Array[Vector2]=[axis,(edges[5]-p).normalized()]
			var width:float=b.settings.alien_infected.hive_junction_width*scale_value;var height:float=b.settings.alien_infected.hive_junction_height*(.65+d.age*.7)*b.settings.alien_infected.relief*maxf(b.settings.height_multiplier,.01)
			var g=Structures.new();g.origin=Vector3(p.x,0,p.y);g._support_steps=Structures.support_grids();Candidate.new().emit(g,b,p,directions,width,height,d.angle)
			check(g.vertices.size()==14304,"Actual combined 4768-triangle candidate")
			var primary:PackedVector3Array=g.vertices.slice(0,3000);var strut:PackedVector3Array=g.vertices.slice(6000,9168);var web:Dictionary={}
			for point:Vector3 in g.vertices.slice(9168):web[point]=true
			var maximum_top_error:float=0;var top_count:int=0
			for column in range(1,32):
				# Recover the centre from the ACTUAL original strut ring vertices,
				# not the candidate membrane's analytical curve implementation.
				var center:=Vector3.ZERO
				for side_index in range(16):center+=strut[column*96+side_index*6]/16
				for sign_value:float in [-1,1]:
					var expected:Vector3=center+Vector3(side.x,0,side.y)*width*.028*sign_value;var actual:Vector3=nearest(web,expected);var error:float=actual.distance_to(expected);maximum_top_error=maxf(maximum_top_error,error)
					check(error<.03,"Actual membrane upper edge follows the actual strut ring within float world-position precision")
					var connected:bool=inside(strut,actual);check(connected,"Upper membrane attachment lies inside the closed root strut")
					if not connected:bad_anchors.append({"seed":item.seed,"scale":scale_value,"column":column,"edge":sign_value,"local_point":actual,"kind":"strut"})
					top_count+=1
			var ground:float=b._get_height(p.x,p.y);var a2:Vector2=axis*width*.6*sin(.65*PI*.65)+side*width*.07*sin(.65*PI+d.angle)*.65;var left_count:int=0
			for point:Vector3 in web:
				if absf((Vector2(point.x,point.z)-a2).dot(axis))>.04:continue
				left_count+=1;var connected:bool=inside(primary,point);check(connected,"Complete left membrane edge lies inside actual closed fluted blade")
				if not connected:bad_anchors.append({"seed":item.seed,"scale":scale_value,"local_point":point,"kind":"blade"})
			check(left_count==26,"Every left-edge cross-section point is covered")
			# Independent negative control well outside the small tube cross-section.
			check(not inside(strut,Vector3(0,ground+height*4,0)),"Ray-parity outside negative control")
			cases.append({"seed":item.seed,"scale":scale_value,"actual_unscaled_height_m":height,"width_m":width,"top_attachment_points":top_count,"blade_attachment_points":left_count,"maximum_ring_position_error_m":maximum_top_error,"proposed_default_membrane_chance":field.random(cell.x,cell.y,248)})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable independent attachment source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_membrane_attachments.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"bad_anchors":bad_anchors,"cases":cases,"source_sha256":hashes,"private_reference_only":true,"mutates_production":false,"scope":"Independent triangle ray-parity containment of both complete upper membrane edges in actual original root-strut geometry and every left-edge point in actual closed fluted blade geometry. Three real root identities and three feature scales use actual production unscaled height/width controls. Closed volume topology/footing tests are separate; not native Jolt collision/walk or production staging acceptance."},"  "))
	print("MEMBRANE_ATTACHMENTS ",checks," failures=",failures," bad_anchors=",bad_anchors.size());quit(0 if failures.is_empty() else 1)
