extends "res://tools/biome_extensions/check_all.gd"
const Guard=preload("res://tools/caves/insect_entry_guard_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/insect_entry_guard_candidate.gd","res://tools/caves/check_insect_entry_guard.gd","res://scripts/biome_extension_structures.gd","res://scripts/insect_colony_sampler.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_settings.gd"]:guards[path]=FileAccess.get_sha256(path)
	var sites:Array=[]
	for name:String in ["check_insect_domes","check_insect_vents"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";guards[path]=FileAccess.get_sha256(path);var data=JSON.parse_string(FileAccess.get_file_as_string(path));check(data.passed,"Existing original structure manifest "+name);sites.append_array(data.get("sites",data.get("cases",[])))
	var tested:int=0;var vertices:int=0
	for site:Dictionary in sites:
		var b=make_builder(6,int(site.seed));var guard=Guard.new();guard.configure(b);var p:=Vector2(site.position[0],site.position[1]);var data:Dictionary=guard.roots_near(p,4);check(data.valid,"Bounded positive query at original actual mound root");var root_data:Dictionary={}
		for item:Dictionary in data.roots:
			if item.id==site.id:root_data=item;break
		check(not root_data.is_empty(),"Original actual live root is represented,not replaced by a different seed/site")
		if root_data.is_empty():continue
		check(not guard.clear_mounds(Vector3(p.x,site.ground,p.y),4),"Mound-center cave mouth is rejected,not cut through visible solid")
		var geometry=Structures.new();var width:float=root_data.scale*(.84 if root_data.broad_dome else .4);var height:float=maxf(root_data.scale*.42,minf(root_data.scale,18)) if root_data.broad_dome else root_data.scale;var anchor:=Vector3(p.x,site.ground-8,p.y);geometry.mound(b,anchor,width,height,root_data.archetype,root_data.phase,Color(.44,.27,.14),0,root_data.broad_dome)
		if root_data.archetype in [0,4,5]:
			for i in range(5):
				var a:float=root_data.phase+i*1.31;geometry.mound(b,anchor+Vector3(cos(a),0,sin(a))*root_data.scale*.23,root_data.scale*.19,root_data.scale*(.4+b._extras[6].random(int(site.cell[0]),int(site.cell[1]),110+i)*.5),0,a,Color(.44,.27,.14))
		for vertex:Vector3 in geometry.vertices:check(Vector2(vertex.x,vertex.z).distance_to(p)<=root_data.radius+.1,"Complete original primary AND satellite-complex footprint inside conservative cave admission guard");vertices+=1
		var cold=Guard.new();cold.configure(b);check(var_to_bytes(data)==var_to_bytes(cold.roots_near(p,4)),"Complete cold guard descriptors deterministic");tested+=1
	var absent=Guard.new();absent.configure(make_builder(3,73921));check(absent.clear_access({"points":PackedVector3Array([Vector3.ZERO]),"half_width":4.0}),"Unrelated original pure-Spore cave graph performs no colony query")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private Insect admission source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_insect_entry_guard.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"original_sites":tested,"full_complex_vertices":vertices,"production_registration":false,"scope":"Private numeric admission candidate at original recorded dome/vent roots,complete original primary/satellite mesh extents inside conservative footprints,center-mouth rejection,cold descriptor identity and unrelated-world bypass. Existing finite cavities reserved separately. NOT actual cave registration,field carving,render/native path or final Insect completion. Conservative guards may also reserve a root omitted by older finite-burrow exclusion."},"  "));print("CAVE_INSECT_ENTRY_GUARD ",checks," sites=",tested," vertices=",vertices," failures=",failures);quit(0 if failures.is_empty() else 1)
