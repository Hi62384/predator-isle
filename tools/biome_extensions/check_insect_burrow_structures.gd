extends SceneTree
## Reuse the fixed finite-cavity walker without silently omitting mound solids.
## No production source, fixed site, capsule, motion limit or route is changed.
func _initialize()->void:
	var conflict:int=-1
	var omit:bool=OS.get_cmdline_user_args().has("without_structures")
	var legacy:bool=OS.get_cmdline_user_args().has("legacy_placement")
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("conflict="):conflict=int(arg.trim_prefix("conflict="))
	var path:String="res://tools/biome_extensions/check_roundtrip.gd"
	var source:String=FileAccess.get_file_as_string(path)
	assert(source.count("for family_id:int in [1,2,6,7]:")==1)
	source=source.replace("for family_id:int in [1,2,6,7]:","for family_id:int in [6]:")
	if legacy:
		var configure:String='b.settings.get(TerrainSettings.EXTENSION_KEYS[family_id]).cave_frequency=.5;'
		assert(source.count(configure)==1)
		source=source.replace(configure,configure+'b.settings.insect_colony.nest_protect_burrows=false;')
	var marker:String="func run()->void:\n"
	assert(source.count(marker)==1)
	source=source.replace(marker,marker+"\tvar proof_hashes:Dictionary={}\n\tvar total_structure_vertices:int=0\n\tvar inventory=JSON.parse_string(FileAccess.get_file_as_string(\"res://data/surface_regression_20261018.json\"))\n\tfor raw:String in inventory.source_sha256:\n\t\tvar canonical:String=\"res://\"+raw.replace(\"\\\\\",\"/\");proof_hashes[canonical]=FileAccess.get_sha256(canonical)\n\tfor proof_path:String in [\"res://tools/biome_extensions/check_insect_burrow_structures.gd\",\"res://tools/biome_extensions/check_roundtrip.gd\",\"res://tools/biome_extensions/check_integration.gd\",\"res://tools/biome_extensions/check_all.gd\",\"res://tools/biome_extensions/route_probe.gd\"]:proof_hashes[proof_path]=FileAccess.get_sha256(proof_path)\n")
	var prepare:String="node.mesh.set_meta(\"collision_data\",Collision.prepare(a,64,true,[],feature))"
	assert(source.count(prepare)==1)
	source=source.replace(prepare,"var actual_structures:Array=build_structures(b,coordinate)\n\t\t\t\tfor surface in actual_structures:\n\t\t\t\t\tif surface!=null:total_structure_vertices+=surface[Mesh.ARRAY_VERTEX].size()\n\t\t\t\t"+prepare.replace("[],feature","actual_structures,feature"))
	if omit:
		assert(source.count("var actual_structures:Array=build_structures(b,coordinate)")==1)
		source=source.replace("var actual_structures:Array=build_structures(b,coordinate)","var actual_structures:Array=[]")
	if conflict>=0:
		var manifest_path:String="res://tools/biome_extensions/artifacts/revisions/experiment_find_insect_burrow_conflicts_wide_24a12b15e1b3/evidence/tools/biome_extensions/artifacts/find_insect_burrow_conflicts_wide.json"
		var manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path));assert(manifest.passed and conflict<manifest.candidates.size())
		assert(FileAccess.get_sha256(manifest_path).begins_with("24a12b15e1b3"),"Historical discovery coordinates must stay frozen, not match changed production sources")
		var selected:Dictionary=manifest.candidates[conflict];assert(int(selected.seed)==17)
		var id:String=selected.portal_id;var pattern:=RegEx.new();assert(pattern.compile("^6:-?[0-9]+:-?[0-9]+$")==OK and pattern.search(id)!=null)
		var first:int=source.find("\t\tfor i in range(256):\n");var last:int=source.find("\t\tcheck(not found.is_empty()",first);assert(first>=0 and last>first)
		var choose:String="\t\tcheck(seed_id==17,\"Explicit conflict fixture requires its recorded seed17\")\n\t\tvar discovered:Dictionary=Features.new().build(b,Vector2i(%d,%d))\n\t\tfor selected_site:Dictionary in discovered.cavities:\n\t\t\tif selected_site.id==\"%s\":found=discovered;found.cavities=[selected_site];break\n"%[floori(selected.portal_position[0]/8192),floori(selected.portal_position[1]/8192),id]
		choose+='\t\tif not found.is_empty():check(found.cavities[0].position==Vector2(%f,%f),"Frozen discovered portal coordinates unchanged")\n'%[selected.portal_position[0],selected.portal_position[1]]
		source=source.substr(0,first)+choose+source.substr(last)
		var proof_marker:String="\tvar proof_hashes:Dictionary={}\n";assert(source.count(proof_marker)==1)
		source=source.replace(proof_marker,proof_marker+"\tproof_hashes[\""+manifest_path+"\"]=FileAccess.get_sha256(\""+manifest_path+"\")\n")
	var output_marker:String="\tvar suffix:String=\"\" if seed_id==73921 else \"_\"+str(seed_id)"
	assert(source.count(output_marker)==1)
	source=source.replace(output_marker,"\tfor proof_path:String in proof_hashes:check(FileAccess.get_sha256(proof_path)==proof_hashes[proof_path],\"Stable structure-aware burrow source \"+proof_path)\n"+output_marker)
	source=source.replace('"res://tools/biome_extensions/artifacts/check_roundtrip"','"res://tools/biome_extensions/artifacts/check_insect_burrow_structures"')
	if conflict>=0 or omit:
		var suffix_marker:String='else "_"+str(seed_id)'
		assert(source.count(suffix_marker)==1)
		source=source.replace(suffix_marker,suffix_marker+';suffix+="'+("_conflict"+str(conflict) if conflict>=0 else "")+("_without" if omit else "_with")+("_legacy" if legacy else "")+'"')
	source=source.replace('{"checks":checks,"failures":failures,"seed":seed_id,','{"passed":failures.is_empty(),"production_registration":true,"source_sha256":proof_hashes,"supplemental_structure_vertices":total_structure_vertices,"checks":checks,"failures":failures,"seed":seed_id,')
	source=source.replace('"supplemental_structure_vertices":total_structure_vertices,','"supplemental_structure_vertices":total_structure_vertices,"mound_solids_included":'+("false" if omit else "true")+',"explicit_discovered_conflict_index":'+str(conflict)+',')
	source=source.replace('"mound_solids_included":','"legacy_placement":'+("true" if legacy else "false")+',"mound_solids_included":')
	var scope:String="Actual finite Insect cavity surface/interior/surface capsule route. "
	scope+=("Explicit original-coverage CONTROL with mound solids omitted. " if omit else "Complete current mound solids INCLUDED in collision. ")
	scope+=("A separately discovered actual default-rarity portal is selected by its immutable ID/coordinates; this is NOT the original first-site fixture or its repair. " if conflict>=0 else "The original first-admitted site is retained. ")
	scope+="Route, capsule/motion limits and forced fixture cave frequency0.5 unchanged. Supplemental structure vertex count records actual mound presence. Numeric near-geometry physics fixture, not a production streaming walk, default-rarity distribution or infinite cave certificate."
	source=source.replace("Finite cavity physics, no streaming or infinite cave certification",scope)
	var fixture:=GDScript.new();fixture.source_code=source;assert(fixture.reload()==OK)
	set_script(fixture);call_deferred("run")
