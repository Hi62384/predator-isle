extends SceneTree
const References=preload("res://tools/biome_extensions/grounded_conduit_references.gd")
const FROZEN="res://tools/biome_extensions/artifacts/revisions/experiment_tissue_flow_adoption_1e396f3b7915/sources/tools/biome_extensions/artifacts/render_alien_tissue_flow.json.txt"
var checks:int=0
func verify(ok:bool,label:String)->void:checks+=1;assert(ok,label)
func payload(item:Dictionary,enabled:bool,reference:Script=null)->Dictionary:
	var key:=Vector3i(item.key[0],item.key[1],item.key[2]);var builder=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(item.seed,true);builder.settings.alien_infected.hive_grounded_shoulders=enabled;builder.chunk_size=256*float(1<<key.z);var coordinate:=Vector2i(key.x,key.y);var resolution:int=int(item.resolution)
	var arrays:Array=builder.build(coordinate,resolution);var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=mesher.build(builder,coordinate)
	if key.z<=1 and not features.is_empty() and not features.openings.is_empty():features["ground_collision"]=preload("res://scripts/terrain_collision.gd").clipped_ground(arrays,features.openings,resolution)
	var generator=reference.new() if reference!=null else preload("res://scripts/lod_biome_extension_structures.gd").new();var steps:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(256,128,16,4);var structures:Array=generator.build(builder,coordinate,steps,mesher.portal_sites)
	verify(generator.conduit_grounded_shoulders==enabled,"Actual producer consumes configured independent setting")
	var map:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").structure_atlas(builder,structures[2],Vector2(coordinate)*builder.chunk_size);var collision:Dictionary=preload("res://scripts/terrain_collision.gd").prepare(arrays,resolution,key.z<=1,structures,features)
	verify(structures[2][Mesh.ARRAY_VERTEX].size()==int(item.structure_vertices),"Complete original native-owned root vertex count preserved")
	return {"arrays":arrays,"features":features,"structures":structures,"map":map,"collision":collision,"water":builder.build_swamp_water(arrays,resolution),"packed":builder.built_extension_data.duplicate(),"flow":builder.built_alien_tissue_flow.duplicate()}
func _initialize()->void:
	var render=JSON.parse_string(FileAccess.get_file_as_string(FROZEN));assert(render.passed);var selected:Array=[]
	for phase:Dictionary in render.phases:
		if phase.phase!=1:continue
		var best:Dictionary={}
		for item:Dictionary in phase.structure_map_cases:
			if best.is_empty() or item.structure_vertices<best.structure_vertices:best=item.duplicate(true)
		best.seed=int(phase.seed);selected.append(best)
	verify(selected.size()==3,"Three original native-owned roots,not newly chosen easier geometry")
	var before:GDScript=References.before();var accepted:GDScript=References.accepted();var records:Array=[]
	for item:Dictionary in selected:
		var actuals:Dictionary={}
		for enabled:bool in [false,true]:
			var actual:Dictionary=payload(item,enabled);var expected:Dictionary=payload(item,enabled,accepted if enabled else before)
			verify(actual==expected,"COMPLETE actual worker payload equals full immutable off/on reference,including collision/maps/water/features")
			actuals[enabled]=actual;records.append({"seed":item.seed,"key":item.key,"enabled":enabled,"structure_vertices":item.structure_vertices,"map_bytes":actual.map.data.size()})
		for field:String in ["arrays","features","map","water","packed","flow"]:verify(actuals[false][field]==actuals[true][field],"Independent switch cannot change non-structure payload "+field)
		verify(actuals[false].structures!=actuals[true].structures,"True mode genuinely changes original root geometry")
		for field:String in actuals[false].collision:
			if field!="structure_faces":verify(actuals[false].collision[field]==actuals[true].collision[field],"Independent switch cannot change unrelated collision "+field)
	var guards:Dictionary={FROZEN:FileAccess.get_sha256(FROZEN)}
	for path:String in [References.BEFORE_BASE,References.BEFORE_LOD,References.ACCEPTED,"res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_collision.gd","res://scripts/alien_tissue_coordinates.gd","res://tools/biome_extensions/grounded_conduit_references.gd","res://tools/biome_extensions/check_grounded_worker_payloads.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_grounded_worker_payloads.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"checks":checks,"source_sha256":guards,"cases":records,"scope":"REGISTERED six COMPLETE real worker/reference payload pairs at the same three immutable native-verified roots. Off uses full frozen pre-feature near/far emitter,on uses exact archived accepted private source;all arrays/features/structures/maps/collision/water/packed fields compare exactly,not height probes alone. Actual setting consumed;only intended structure geometry and its corresponding faces differ between modes. Smallest admitted actual roots are bounded fixtures,not worst-case/arbitrary-world acceptance."},"  "));print("GROUNDED_WORKER_PAYLOADS ",checks);quit()
