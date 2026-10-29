extends "res://tools/biome_extensions/check_integration.gd"
const Sealed=preload("res://tools/biome_extensions/reference_sealed_insect_mound.gd")
const Vents=preload("res://scripts/insect_vent_geometry.gd")
const Collision=preload("res://scripts/terrain_collision.gd")
func channels(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func ray_parameter(faces:PackedVector3Array,from:Vector3,to:Vector3)->float:
	var direction:Vector3=to-from;var nearest:float=INF
	for i in range(0,faces.size(),3):
		var a:Vector3=faces[i];var ab:Vector3=faces[i+1]-a;var ac:Vector3=faces[i+2]-a;var cross_value:Vector3=direction.cross(ac);var determinant:float=ab.dot(cross_value)
		if determinant>=-.00000001:continue # actual clockwise front faces
		var offset:Vector3=from-a;var u:float=offset.dot(cross_value)/determinant
		if u<0 or u>1:continue
		var q:Vector3=offset.cross(ab);var v:float=direction.dot(q)/determinant
		if v<0 or u+v>1:continue
		var t:float=ac.dot(q)/determinant
		if t>=0 and t<=1:nearest=minf(nearest,t)
	return nearest
func top_height(faces:PackedVector3Array,p:Vector2)->float:
	var highest:float=-INF
	for i in range(0,faces.size(),3):
		var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
		var v:=Vector2(b.x-a.x,b.z-a.z);var w:=Vector2(c.x-a.x,c.z-a.z);var q:=p-Vector2(a.x,a.z);var d:float=v.cross(w)
		if absf(d)<.0000001:continue
		var u:float=q.cross(w)/d;var t:float=v.cross(q)/d
		if u>=-.00001 and t>=-.00001 and u+t<=1.00001:highest=maxf(highest,a.y+u*(b.y-a.y)+t*(c.y-a.y))
	return highest
func locate(b)->Dictionary:
	var field=b._extras[6];var span:float=2100*field.settings.feature_scale
	for z in range(-30,31):
		for x in range(-30,31):
			var cell:=Vector2i(x,z);var d:Dictionary=field.descriptor(cell,span);var p:Vector2=d.position
			if d.chance>field.settings.structure_density or field.random(x,z,178)>=field.settings.nest_vent_frequency:continue
			var type:int=clampi(roundi(field.region(p)),0,5)
			if not type in [0,3,5] or b._island_mask(p.x,p.y)<.03:continue
			var h:float=b._get_height(p.x,p.y)
			if h<b.get_water_surface_height(p.x,p.y)+2:continue
			var scale:float=field.settings.nest_height*(.45+d.age)
			var broad_dome:bool=type==3 and field.settings.nest_broad_domes
			if broad_dome or field.settings.nest_protect_burrows:
				var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
				var blocked:bool=false
				for site:Dictionary in guard.portal_sites(Rect2(p-Vector2.ONE*1024,Vector2.ONE*2048)):
					if p.distance_to(site.position)<scale*(.84*1.6 if broad_dome else .8)+maxf(320,site.half*1.2):blocked=true;break
				if blocked:continue
			var height:float=maxf(scale*.42,minf(scale,18)) if broad_dome else scale
			var width:float=scale*(.84 if broad_dome else .4)
			if height<40:continue
			var anchor:=Vector3(p.x,h-8,p.y);var depth:float=Vents.admitted_depth(b,anchor,width,height,d.angle,minf(height*.18,24))
			if depth<=0:continue
			return {"id":d.id,"seed":b.world_seed,"position":[p.x,p.y],"cell":[x,z],"ground":h,"height":height,"width":width,"phase":d.angle,"archetype":type,"broad_dome":broad_dome,"vent_depth":depth,"random":field.random(x,z,178)}
	return {}
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_insect_vents.gd","res://tools/biome_extensions/reference_sealed_insect_mound.gd","res://scripts/insect_vent_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://scripts/insect_colony_sampler.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var flat=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();flat._configure_noise()
	var geometry_cases:int=0;var native_cases:int=0
	check(Vents.admitted_depth(flat,Vector3(0,-100,0),48,120,.17,24)==0,"Reject a shaft whose floor intersects canonical ground/water")
	check(Vents.admitted_depth(flat,Vector3(0,-8,0),48,120,.17,0)==0,"Zero request bypasses all shaft geometry")
	for archetype:int in [0,3,5]:
		for height:float in [40,120,350]:
			for phase:float in [.17,2.3,5.7]:
				var old=Sealed.new();var zero=Structures.new();var actual=Structures.new();var width:float=height*.4;var depth:float=minf(height*.18,24);var anchor:=Vector3(0,-8,0)
				old.mound(flat,anchor,width,height,archetype,phase,Color(.44,.27,.14));zero.mound(flat,anchor,width,height,archetype,phase,Color(.44,.27,.14),0)
				check(channels(old)==channels(zero),"Zero depth preserves every original mound array")
				actual.mound(flat,anchor,width,height,archetype,phase,Color(.44,.27,.14),depth)
				check(actual.vertices.size()==old.vertices.size()+504,"Exactly one 42-sided thick lining replaces the original cap")
				var edges:Dictionary={}
				for i in range(0,actual.vertices.size(),3):
					var a:Vector3=actual.vertices[i];var b:Vector3=actual.vertices[i+1];var c:Vector3=actual.vertices[i+2]
					check((c-a).cross(b-a).length_squared()>.00000001,"Nondegenerate actual mound triangle")
					for pair:Array in [[a,b],[b,c],[c,a]]:
						var key:Array=pair if pair[0]<pair[1] else [pair[1],pair[0]]
						edges[key]=int(edges.get(key,0))+1
				for edge:Array in edges:
					check(edges[edge]==2 or (edges[edge]==1 and edge[0].y<=-8 and edge[1].y<=-8),"Only the original buried base may have boundary edges")
				for normal:Vector3 in actual.normals:check(normal.is_finite() and normal.length_squared()>.9,"Finite unit vent and mound normals")
				var center:=Vector3(width*.16*sin(2+phase),height-8,width*.12)
				check(absf(top_height(actual.vertices,Vector2(center.x,center.z))-(center.y-depth))<.0001,"True depth: no cap or rim triangle covers the aperture")
				check(top_height(old.vertices,Vector2(center.x,center.z))-top_height(actual.vertices,Vector2(center.x,center.z))>depth*.99,"Original sealed cap is a required negative control")
				geometry_cases+=1
				if phase!=.17 or height!=120:continue
				var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=actual.vertices;arrays[Mesh.ARRAY_NORMAL]=actual.normals;arrays[Mesh.ARRAY_COLOR]=actual.colors;arrays[Mesh.ARRAY_TEX_UV]=actual.uvs
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.set_meta("collision_data",Collision.prepare([],0,false,[arrays],{}))
				var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node);Collision.stage(node,256,16,false,true);Collision.activate(node,true)
				for frame in range(3):await physics_frame
				for offset:Vector2 in [Vector2.ZERO,Vector2(.2,.1),Vector2(-.15,.15)]:
					var p:=Vector2(center.x,center.z)+offset;var expected:float=top_height(actual.vertices,p)
					var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,center.y+5,p.y),Vector3(p.x,center.y-depth-2,p.y))
					var hit:Dictionary=node.get_world_3d().direct_space_state.intersect_ray(query)
					check(not hit.is_empty() and absf(hit.position.y-expected)<.01,"Native near collision enters the real aperture and reaches its visible floor")
					native_cases+=1
				for angle:float in [.21,1.79,3.47,5.13]:
					var from:Vector3=center-Vector3.UP*depth*.5
					var to:Vector3=from+Vector3(cos(angle),0,sin(angle))*width*.2
					var t:float=ray_parameter(actual.vertices,from,to)
					var query:=PhysicsRayQueryParameters3D.create(from,to);var hit:Dictionary=node.get_world_3d().direct_space_state.intersect_ray(query)
					check(is_finite(t) and not hit.is_empty(),"Actual inward wall is front-facing from inside the recess")
					if is_finite(t) and not hit.is_empty():check(hit.position.distance_to(from.lerp(to,t))<.01,"Native lining ray equals independent front-face triangles")
					native_cases+=1
				Collision.release(node);node.queue_free();await process_frame
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(6,seed_id);var site:Dictionary=locate(b);check(not site.is_empty(),"Actual default-rarity dry mature vent mound")
		if site.is_empty():continue
		var p:=Vector2(site.position[0],site.position[1]);b.chunk_size=256;var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256))
		var actual:Array=Structures.new().build(b,coordinate);var sealed:Array=Sealed.new().build(b,coordinate)
		check(actual[1]!=null and sealed[1]!=null and actual[1][Mesh.ARRAY_VERTEX].size()==sealed[1][Mesh.ARRAY_VERTEX].size()+504,"Exactly one real admitted primary vent")
		b.settings.insect_colony.nest_vent_frequency=0
		check(Structures.new().build(b,coordinate)==sealed,"Zero frequency restores every complete sealed structure array under the selected dome profile")
		b.settings.insect_colony.nest_vent_frequency=.25
		var local_center:=Vector3(p.x,site.ground-8,p.y)+Vector3(site.width*.16*sin(2+site.phase),site.height,site.width*.12)-Vector3(coordinate.x*256,0,coordinate.y*256)
		check(absf(top_height(actual[1][Mesh.ARRAY_VERTEX],Vector2(local_center.x,local_center.z))-(local_center.y-site.vent_depth))<.01,"Real complete complex, including satellites, does not plug the shaft")
		b.chunk_size=512;var parent_cell:=Vector2i(floori(p.x/512),floori(p.y/512));var parent:Array=Structures.new().build(b,parent_cell)
		var expected:Array[String]=world_vertices(parent,Vector3(parent_cell.x*512,0,parent_cell.y*512));var children:Array[String]=[]
		b.chunk_size=256
		for z in range(2):
			for x in range(2):
				var child:Vector2i=parent_cell*2+Vector2i(x,z);children.append_array(world_vertices(Structures.new().build(b,child),Vector3(child.x*256,0,child.y*256)))
		expected.sort();children.sort();check(expected==children,"Same single complete mound owner across parent/four child leaves")
		cases.append(site)
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable vent source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_vents.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"geometry_cases":geometry_cases,"native_floor_and_lining_rays":native_cases,"cases":cases,"source_sha256":hashes,"production_registration":true,"scope":"Twenty-seven actual mound variants: original zero arrays, only buried base boundaries, no degenerate faces, finite normals, independently measured open depth and original-cap negatives; twenty-one actual Jolt floor/lining rays. Three real default-rarity full complexes verify frequency zero, stable single-leaf ownership and satellites do not cover the vent. Blind above-ground recesses, not traversable colony entrances, infinite caves, arbitrary-setting or visual acceptance."},"  "))
	print("INSECT_VENTS ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
