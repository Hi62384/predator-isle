extends "res://tools/biome_extensions/check_all.gd"
const References=preload("res://tools/biome_extensions/crystal_root_references.gd")
func arrays(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func run()->void:
	var guards:Dictionary={};var cases:Array=[];var whole:Array=[];var source_changes:int=0
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/crystal_root_references.gd","res://tools/biome_extensions/check_crystal_root_registration.gd",References.ROOT+"scripts/biome_extension_structures.gd.txt",References.ROOT+"tools/biome_extensions/artifacts/earth_crystal_trial_source.txt.txt"]:guards[path]=FileAccess.get_sha256(path)
	var before:=References.script_for(false);var accepted:=References.script_for(true)
	var admission_path:String=References.ROOT+"tools/biome_extensions/artifacts/check_grounded_earth_crystal_candidate.json.txt";var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));assert(admission.passed);guards[admission_path]=FileAccess.get_sha256(admission_path)
	var saved:Resource=load("res://config/biomes/crystal_wastes_settings.tres");check(saved.crystal_grounded_roots,"Saved/default Crystal control enabled")
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(5,seed_id);var field=b._extras[5];var descriptor:Dictionary=field.descriptor(Vector2i(-4,-3),1700);var p:Vector2=descriptor.position;var anchor:=Vector3(p.x,b._get_height(p.x,p.y)-8,p.y)
		for habit:int in range(6):
			for broken:bool in [false,true]:
				for enabled:bool in [false,true]:
					var actual=Structures.new();actual.crystal_grounded_roots=enabled;var reference=(accepted if enabled else before).new()
					for g in [actual,reference]:
						g.origin=Vector3(floorf(p.x/256)*256,0,floorf(p.y/256)*256);g._support_steps=Structures.support_grids()
						g.prism(b,anchor,24+habit*3,120+habit*50,habit,descriptor.angle,Vector2(.1,-.08),broken,Color(.59,.61,.58))
					check(arrays(actual)==arrays(reference),"Complete actual primitive matches frozen old/accepted positions,normals,UVs,colors")
					cases.append({"seed":seed_id,"habit":habit,"broken":broken,"enabled":enabled,"vertices":actual.vertices.size()})
		# Real full build uses saved configuration,not a primitive-only flag.
		for site:Dictionary in admission.cases:
			if int(site.family)==5 and int(site.seed)==seed_id:
				var pieces:PackedStringArray=site.root.trim_prefix("(").trim_suffix(")").split(",");var approximate:=Vector2(float(pieces[0]),float(pieces[1]));var cell:=Vector2i(floori(approximate.x/1700),floori(approximate.y/1700));p=field.descriptor(cell,1700).position;break
		b.chunk_size=2048;var coordinate:=Vector2i(floori(p.x/2048),floori(p.y/2048));var prior:Array=[]
		for enabled:bool in [false,true,false]:
			b.settings.crystal_wastes.crystal_grounded_roots=enabled
			var actual:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate);var reference:Array=(accepted if enabled else before).new().build(b,coordinate)
			check(actual==reference,"Complete root-owned real build matches frozen geometry reference")
			if prior.is_empty():prior=actual
			elif enabled:
				check(actual!=prior,"Enabled saved configuration changes actual complete root arrays");source_changes+=int(actual!=prior)
			else:check(actual==prior,"Saved false mode restores entire original root arrays")
			whole.append({"seed":seed_id,"enabled":enabled,"root":str(coordinate)})
	# Mound prototype deliberately NOT adopted:no original selected-terrain
	# efficacy at its frozen sites. Existing Insect/Alien primitives stay exact.
	for family_id:int in [6,7]:
		var b=make_builder(family_id,17);b.chunk_size=2048
		for enabled:bool in [false,true]:
			b.settings.crystal_wastes.crystal_grounded_roots=enabled;var actual:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,Vector2i(-10,-10));var reference:Array=before.new().build(b,Vector2i(-10,-10))
			check(actual==reference,"Unrelated complete structure families unchanged")
	check(source_changes==3,"Actual saved-control intervention in every selected seed")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable registered source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_crystal_root_registration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"whole_builds":whole,"scope":"REGISTERED default-on independent crystal_grounded_roots.72 complete six-habit/broken/intact/off/on primitive reference pairs,three actual saved-config full-build off/on/off triplets,and unrelated Insect/Alien complete-build controls. Frozen original and accepted complete methods,not regenerated counterfactuals. Only Crystal foundation extension adopted;private mound extension not adopted because actual selected contacts did not demonstrate original gaps in those frozen cases. Direct primitive callers retain legacy mode unless explicitly enabled. No all-world visual/performance/cave claim."},"  "))
	print("CRYSTAL_ROOT_REGISTRATION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
