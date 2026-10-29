extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/conduit_edge_tissue_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/flat_conduit_builder.gd","res://tools/biome_extensions/conduit_edge_tissue_candidate.gd","res://tools/biome_extensions/check_conduit_edge_tissue.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for width:float in [8,12,20,28,40]:
		for phase:float in [.4,2.1,5.3]:
			var b=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.alien_infected_coverage=100;b._configure_noise()
			var original=Structures.new();var candidate=Candidate.new();var disabled=Candidate.new();disabled.edge_tissue_enabled=false
			for g in [original,candidate,disabled]:g.origin=Vector3(-47104,0,-46080);g._support_steps=Structures.support_grids();g.conduit(b,Vector2(-47392,-46434),Vector2(-45201,-45911),width,phase,Color(.34,.28,.26))
			check(original.vertices==candidate.vertices and original.normals==candidate.normals and original.uvs==candidate.uvs,"Exact original geometry/normals/tissue controls")
			check(original.vertices==disabled.vertices and original.colors==disabled.colors and original.normals==disabled.normals and original.uvs==disabled.uvs,"Exact complete disabled arrays")
			var changed:int=0;var preserved_footings:int=0;var crest_unchanged:int=0
			for i in range(original.vertices.size()):
				var a:Color=original.colors[i];var c:Color=candidate.colors[i]
				check(Vector3(a.r,a.g,a.b)==Vector3(c.r,c.g,c.b),"Authored RGB unchanged")
				if a.a!=c.a:
					check(a.a==1 and (is_equal_approx(c.a,.25) or is_equal_approx(c.a,.45) or is_equal_approx(c.a,.65)),"Only original core vertices gain one of three transition tags");changed+=1
				elif a.a<.9:preserved_footings+=1
				elif original.vertices[i].y>width*.2:crest_unchanged+=1
			check(changed>100 and preserved_footings>100,"Actual core transition and unchanged apron/footing tags exercised")
			cases.append({"width":width,"phase":phase,"changed_alpha_vertices":changed,"unchanged_apron_footing_vertices":preserved_footings,"unchanged_high_crest_vertices":crest_unchanged,"vertices":candidate.vertices.size()})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private edge-tissue source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_conduit_edge_tissue.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"cases":cases,"private_candidate_only":true,"scope":"Five widths/three phases at signed world origin, existing core alpha tags only; exact geometry/normals/semantic UV/RGB and complete disabled arrays, unchanged apron/footing markers. Test-only flat canonical field; no production registration, native appearance/normal/physics/performance or arbitrary-terrain acceptance."},"  "))
	print("CONDUIT_EDGE_TISSUE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
