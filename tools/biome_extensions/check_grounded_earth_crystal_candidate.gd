extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/grounded_earth_crystal_candidate.gd")
func attributes(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func run()->void:
	var guards:Dictionary={};var cases:Array=[];var original_exposed_feet:int=0;var changed_roots:int=0
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/grounded_earth_crystal_candidate.gd","res://tools/biome_extensions/check_grounded_earth_crystal_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var script:=Candidate.script_for()
	for family_id:int in [5,6]:
		for seed_id:int in [73921,17,92881]:
			var b=make_builder(family_id,seed_id);var field=b._extras[family_id];var span:float=(1700 if family_id==5 else 2100)*field.settings.feature_scale;var chosen:Dictionary={}
			for index in range(4096):
				var cell:=Vector2i(index%64-32,index/64-32);var d:Dictionary=field.descriptor(cell,span);var p:Vector2=d.position
				if d.chance>field.settings.structure_density or b._island_mask(p.x,p.y)<.2:continue
				var h:float=b._get_height(p.x,p.y)
				if h<=maxf(b.water_level,b.get_water_surface_height(p.x,p.y))+4:continue
				chosen=d;chosen["ground_height"]=h;break
			check(not chosen.is_empty(),"Actual dry procedural root found")
			if chosen.is_empty():continue
			var p:Vector2=chosen.position;var anchor:=Vector3(p.x,chosen.ground_height-8,p.y);var original=Structures.new();var candidate=script.new();var support:PackedFloat64Array=Structures.support_grids()
			for g in [original,candidate]:
				g._support_steps=support;g.origin=Vector3(floorf(p.x/256)*256,0,floorf(p.y/256)*256)
				if family_id==5:g.prism(b,anchor,field.settings.crystal_height*.1,field.settings.crystal_height,0,chosen.angle,Vector2(.1,-.08),false,Color(.59,.61,.58))
				else:g.mound(b,anchor,field.settings.nest_height*.6,field.settings.nest_height,0,chosen.angle,Color(.46,.26,.13))
			check(original.vertices.size()==candidate.vertices.size(),"Same topology;no added triangles")
			var moved:int=0;var max_burial:float=0;var negative_count:int=0;var old_above_chords:int=0;var old_max_gap:float=0
			for i in range(original.vertices.size()):
				var a:Vector3=original.vertices[i];var c:Vector3=candidate.vertices[i]
				check(Vector2(a.x,a.z)==Vector2(c.x,c.z) and c.y<=a.y,"Only downward foundation extension,no shifted footprint")
				check(original.colors[i]==candidate.colors[i],"Same semantic material colors")
				check(candidate.normals[i].is_finite() and absf(candidate.normals[i].length()-1)<.001,"Finite unit surface normal")
				if a==c:continue
				moved+=1;max_burial=maxf(max_burial,a.y-c.y)
				var point:Vector2=Vector2(c.x+candidate.origin.x,c.z+candidate.origin.z)
				var expected:float=candidate.footing_height(b,point)
				check(c.y<=expected+.02,"Actual foot beneath every supported terrain chord plus32m margin")
				if a.y>expected+31.98:negative_count+=1
				if a.y>expected+32+.02:old_above_chords+=1;old_max_gap=maxf(old_max_gap,a.y-expected-32)
			check(moved>0,"Actual intervention on selected root")
			if moved>0:changed_roots+=1
			original_exposed_feet+=negative_count
			cases.append({"family":family_id,"seed":seed_id,"root":str(p),"vertices":candidate.vertices.size(),"moved_foundation_vertices":moved,"maximum_added_burial_m":max_burial,"old_feet_without_full_margin":negative_count,"old_feet_above_a_supported_chord":old_above_chords,"old_max_gap_above_supported_chord_m":old_max_gap})
	check(changed_roots==6,"Both geological families at all three seeds")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable candidate source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_grounded_earth_crystal_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":guards,"production_registration":false,"scope":"PRIVATE complete primitive arrays at six actual dry procedural Crystal/Insect roots across three seeds. Only original bottom-ring vertices move down to existing supported-LOD footing solver;topology,footprint,colors and upper positions retained. Normals rebuilt by original emitter. Every changed foot checked against all configured grid chords and32m visual burial. Does not prove continuous edge enclosure,actual coarse-view efficacy,worker collision,settings opt-out or artistic acceptance;these are subsequent gates."},"  "))
	print("EARTH_CRYSTAL_ROOT_CANDIDATE ",checks," changed_roots=",changed_roots," failures=",failures);quit(0 if failures.is_empty() else 1)
