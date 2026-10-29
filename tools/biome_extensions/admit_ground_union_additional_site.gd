extends SceneTree
const Candidate=preload("res://tools/biome_extensions/conduit_ground_union_candidate.gd")
const DENSE="res://tools/biome_extensions/artifacts/diagnose_ground_union_unchanged_route.json"
func vector(text:String)->Vector3:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func _initialize()->void:
	var dense=JSON.parse_string(FileAccess.get_file_as_string(DENSE));assert(dense.passed and dense.seed==92881 and dense.maximum_independent_triangle_floor_change_m<.02)
	var owner:String=""
	for probe:Dictionary in dense.cases[0].samples:
		if probe.kind=="Structures":owner=probe.owner_key;break
	assert(not owner.is_empty());var parsed:Vector3=vector(owner);var key:=Vector3i(int(parsed.x),int(parsed.y),int(parsed.z));var focus:Vector3=vector(dense.focus)
	var builder=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(92881,true);builder.chunk_size=256*float(1<<key.z);var coordinate:=Vector2i(key.x,key.y);var origin:=Vector3(key.x*builder.chunk_size,0,key.y*builder.chunk_size)
	var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.build(builder,coordinate);var steps:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(256,128,16,4)
	var original:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(builder,coordinate,steps,features.portal_sites);var current:Array=Candidate.script_for().new().build(builder,coordinate,steps,features.portal_sites);assert(original[2]!=null and current[2]!=null)
	var a:PackedVector3Array=original[2][Mesh.ARRAY_VERTEX];var b:PackedVector3Array=current[2][Mesh.ARRAY_VERTEX];assert(a.size()==b.size());var chosen:Dictionary={};var best:float=INF;var changed:int=0;var rejected:Dictionary={"small_change":0,"steep":0,"buried_or_wet":0,"outside_nerve_region":0}
	for index in range(0,a.size(),3):
		var old:Vector3=(a[index]+a[index+1]+a[index+2])/3+origin;var point:Vector3=(b[index]+b[index+1]+b[index+2])/3+origin;var change:float=point.y-old.y
		if absf(change)<.2:rejected.small_change+=1;continue
		changed+=1;var old_normal:Vector3=(a[index+2]-a[index]).cross(a[index+1]-a[index]).normalized();var normal:Vector3=(b[index+2]-b[index]).cross(b[index+1]-b[index]).normalized()
		if normal.y<.85 or old_normal.y<.85:rejected.steep+=1;continue
		var ground:float=builder._get_height(point.x,point.z);var water:float=builder.get_water_surface_height(point.x,point.z)
		if minf(point.y,old.y)<ground+.15 or ground<=water+2:rejected.buried_or_wet+=1;continue
		var region:float=builder._extras[7].region(Vector2(point.x,point.z))
		if region<.75 or region>1.5:rejected.outside_nerve_region+=1;continue
		var distance:float=Vector2(point.x-focus.x,point.z-focus.z).length()
		if distance<best:
			best=distance;chosen={"seed":92881,"point":[point.x,point.y,point.z],"original_point":[old.x,old.y,old.z],"original_normal":str(old_normal),"candidate_normal":str(normal),"height_change_m":change,"canonical_height":ground,"water_height":water,"region":region,"distance_from_original_focus_m":distance,"triangle":index/3,"owner_key":str(key),"owner_origin":str(origin)}
	var failures:Array=[]
	if chosen.is_empty():failures.append("No additional genuine changed dry nerve shoulder on the SAME original collider root under declared geometry admission;original fixed weak-intervention site remains untouched")
	var guards:Dictionary={DENSE:FileAccess.get_sha256(DENSE)}
	for path:String in dense.source_sha256:assert(FileAccess.get_sha256(path)==dense.source_sha256[path]);guards[path]=dense.source_sha256[path]
	for path:String in [Candidate.SOURCE,Candidate.BASE,"res://tools/biome_extensions/conduit_ground_union_candidate.gd","res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://tools/biome_extensions/admit_ground_union_additional_site.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/admit_ground_union_additional_site.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"site":chosen,"changed_triangles_considered":changed,"geometry_rejection_counts":rejected,"scope":"ADDITIONAL proposed positive fixture,not a replacement or repair of the preserved failed original92881 intervention gate. The exact SAME actual collider-owning root from the original metre-grid route is rebuilt with original and private candidate geometry. Select nearest triangle centroid with >=.2m real change,both actual normals y>=.85,both exposed above canonical floor+.15m,dry ground,and original nerve regional range. Admission fixed BEFORE native traversal. No world/seed reroll,physics or artistic pass claimed. The original route still has only6mm sampled change and remains insufficient for the original20mm efficacy gate."},"  "));print("GROUND_UNION_ADDITIONAL_ADMISSION ",chosen," failures=",failures);quit(0 if failures.is_empty() else 1)
