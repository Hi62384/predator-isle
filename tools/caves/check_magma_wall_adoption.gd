extends "res://tools/caves/check_frozen_features.gd"
const Production=preload("res://scripts/caves/magma_features.gd")
const Candidate=preload("res://tools/caves/candidate_magma_wall_features.gd")
const Geometry=preload("res://scripts/caves/magma_geometry.gd")
const CandidateGeometry=preload("res://tools/caves/candidate_magma_wall_geometry.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/candidate_magma_wall_features.gd","res://tools/caves/candidate_magma_wall_geometry.gd","res://config/caves/biomes/magma_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var shapes=Geometry.new();var candidate_shapes=CandidateGeometry.new();var prototypes:int=0
	for kind in range(3):
		for variant in range(4 if kind==0 else 1):
			var points:PackedVector3Array=shapes.prototype(kind,variant);check(var_to_bytes(points)==var_to_bytes(candidate_shapes.prototype(kind,variant)),"Production primitive exactly equals independently validated private variant")
			for point:Vector3 in points:check(point.is_finite() and point.y>=0 and point.y<=1.000001,"Weathered fractured column remains finite and inside normalized height bound")
			for index in range(0,points.size(),3):check((points[index+2]-points[index]).cross(points[index+1]-points[index]).length_squared()>.000000001,"Every adopted opaque facet has positive area")
			prototypes+=1
	check(prototypes==6 and shapes.templates.size()==6,"Exactly six reused numeric templates,not unique high-poly meshes per form")
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var field=Field.new();field.include_surface_air=false;check(field.compile([region],flat,[],region.cave_biome_regions),"Original same shared cave fixture compiles")
	var settings:Dictionary=load("res://config/caves/biomes/magma_cave_definition.tres").feature_configuration;var cases:Array=[];var forms:int=0
	for seed_id:int in [17,73921,92881,1000,1001,19]:
		for key:Vector3i in [Vector3i.ZERO,Vector3i(-1,0,0),Vector3i(1,0,0)]:
			var adopted:Dictionary=Production.new().build(field,key,seed_id,[region],settings,{});var private_result:Dictionary=Candidate.new().build(field,key,seed_id,[region],settings,{});check(adopted.valid and var_to_bytes(adopted)==var_to_bytes(private_result),"Whole placement/geometry/normals/UV/colors/LOD/collision/rejection payload exactly private validated candidate")
			check(adopted.placements.size()<=64 and adopted.prototype_count<=6,"Whole cell form/template budgets retained");forms+=adopted.placements.size();cases.append({"seed":seed_id,"key":str(key),"forms":adopted.placements.size()})
			for placement:Dictionary in adopted.placements:
				for foot:Vector3 in placement.attachments:check(field.sample(foot)>=.15,"Every entire weathered foot buried in measured rock")
	check(forms>0,"Positive actual adopted volcanic wall formations across fixed ensemble")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable adoption source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_wall_adoption.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"prototypes":prototypes,"forms":forms,"cases":cases,"scope":"Six actual bounded weathered prototypes and18whole fixed-seed/cell payloads exact against independent private measured-wall candidate already native-rendered/walked. All physical foot/height/facet/vertex budgets retained;no cave-field/biome/source/route change. Not reference-art/FPS/full-live adoption completion."},"  "));print("MAGMA_WALL_ADOPTION ",checks," forms=",forms," failures=",failures);quit(0 if failures.is_empty() else 1)
