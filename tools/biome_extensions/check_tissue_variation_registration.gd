extends SceneTree
const CANDIDATE=preload("res://tools/biome_extensions/tissue_variation_candidate.gd")
const ORIGINAL="res://tools/biome_extensions/artifacts/revisions/experiment_tissue_flow_adoption_1e396f3b7915/sources/shaders/alien_tissue_flow.gdshaderinc.txt"
const FROZEN="res://tools/biome_extensions/artifacts/revisions/experiment_tissue_flow_adoption_1e396f3b7915/sources/tools/biome_extensions/artifacts/check_alien_tissue_transport.json.txt"
var checks:int=0
func verify(ok:bool,label:String)->void:checks+=1;assert(ok,label)
static func verify_formula()->void:
	var current:String=FileAccess.get_file_as_string(CANDIDATE.BASE);var expected:String=CANDIDATE.source_for(FileAccess.get_file_as_string(ORIGINAL))
	# Comments/default uniform are integration policy; compare the COMPLETE
	# executable helper functions and the complete pre-existing map arithmetic.
	var begin:int=current.find("vec3 alien_flow_mirrored(");var other:int=expected.find("vec3 alien_flow_mirrored(")
	var whitespace:=RegEx.new();assert(whitespace.compile("\\s+")==OK)
	assert(begin>0 and other>0 and whitespace.sub(current.substr(begin),"",true)==whitespace.sub(expected.substr(other),"",true),"Exact accepted private sampler/Jacobian/grouping formula,ignoring line-ending/blank-line formatting only")
	assert(current.contains("uniform bool alien_tissue_variation_enabled=false;"),"Generic shader users stay independently opt-in")
func _initialize()->void:
	verify_formula();var fixture=JSON.parse_string(FileAccess.get_file_as_string(FROZEN));assert(fixture.passed);var records:Array=[]
	var config=preload("res://scripts/biome_extension_settings.gd").new();verify(config.nerve_material_variation and config.nerve_flow_texturing,"World default enables both independently")
	config.nerve_material_variation=false;verify(config.nerve_flow_texturing,"Variation off does not disable path coordinates")
	config.nerve_flow_texturing=false;config.nerve_material_variation=true;verify(not config.nerve_flow_texturing,"Variation on does not implicitly allocate path maps")
	var resource_path:String="res://tools/biome_extensions/artifacts/tissue_variation_saved_settings.tres";assert(ResourceSaver.save(config,resource_path)==OK)
	var reloaded:Resource=ResourceLoader.load(resource_path,"",ResourceLoader.CACHE_MODE_IGNORE);verify(reloaded.nerve_material_variation and not reloaded.nerve_flow_texturing,"Independent controls survive resource save/load")
	# The original transport report stores pure/overlay positive cases only.
	# Add the three genuinely unrelated-owner controls explicitly;do not infer
	# nine cases from that six-case report or claim an unexecuted profile.
	var items:Array=fixture.cases.duplicate(true)
	for seed_id:int in [73921,17,92881]:
		for item:Dictionary in fixture.cases:
			if int(item.seed)==seed_id and int(item.profile)==0:
				items.append({"seed":seed_id,"profile":2,"cell":item.cell});break
	for item:Dictionary in items:
		var seed_id:int=int(item.seed);var profile:int=int(item.profile);var parts:PackedStringArray=String(item.cell).trim_prefix("(").trim_suffix(")").split(",");var cell:=Vector2i(int(parts[0]),int(parts[1]))
		var off=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(seed_id,true,profile);var on=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(seed_id,true,profile)
		off.settings.alien_infected.nerve_material_variation=false;on.settings.alien_infected.nerve_material_variation=true
		var a:Array=off.build(cell,16);var a_data:PackedByteArray=off.built_extension_data;var a_flow:PackedByteArray=off.built_alien_tissue_flow;var b:Array=on.build(cell,16)
		verify(var_to_bytes(a)==var_to_bytes(b),"Material variation never changes complete terrain payload")
		verify(a_data==on.built_extension_data and a_flow==on.built_alien_tissue_flow,"Material variation never allocates/changes packed controls or path maps")
		verify(var_to_bytes(off.build_swamp_water(a,16))==var_to_bytes(on.build_swamp_water(b,16)),"Material variation never changes water payload")
		records.append({"seed":seed_id,"profile":profile,"cell":str(cell),"vertices":a[Mesh.ARRAY_VERTEX].size(),"path_map_bytes":a_flow.size()})
	var guards:Dictionary={}
	for path:String in [CANDIDATE.BASE,ORIGINAL,FROZEN,"res://tools/biome_extensions/tissue_variation_candidate.gd","res://tools/biome_extensions/check_tissue_variation_registration.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd","res://scripts/biome_extension_settings.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tissue_variation_registration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"checks":checks,"cases":records,"scope":"Exact complete registered shader formula versus accepted private source,independent saved controls,and complete terrain/water/control/path-atlas bytes across the original three-seed pure/overlay/unrelated profiles. No geometric displacement or new atlases. Native configured binding,physical/scenic/performance scope separate."},"  "));print("TISSUE_VARIATION_REGISTERED ",checks);quit()
