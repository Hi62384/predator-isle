extends SceneTree
const References=preload("res://tools/biome_extensions/grounded_conduit_references.gd")
const Support=preload("res://tools/biome_extensions/check_conduit_shoulder_candidate.gd").PlanarSupport
const LOD=preload("res://scripts/lod_biome_extension_structures.gd")
var checks:int=0
func verify(ok:bool,label:String)->void:checks+=1;assert(ok,label)
func packed(generator)->Array:return [generator.vertices,generator.normals,generator.colors,generator.uvs]
func _initialize()->void:
	var off_reference:GDScript=References.before();var on_reference:GDScript=References.accepted();var records:Array=[]
	var settings=preload("res://scripts/biome_extension_settings.gd").new();verify(settings.hive_grounded_shoulders,"Independent configured default on");settings.hive_grounded_shoulders=false
	var saved:String="res://tools/biome_extensions/artifacts/grounded_shoulders_saved_settings.tres";verify(ResourceSaver.save(settings,saved)==OK,"Setting saves");var loaded:Resource=ResourceLoader.load(saved,"",ResourceLoader.CACHE_MODE_IGNORE);verify(not loaded.hive_grounded_shoulders and loaded.hive_surface_guided_roots and loaded.hive_structure_lod_enabled,"Independent off survives save/load without changing junction guides or LOD")
	for gradient:Vector2 in [Vector2.ZERO,Vector2(.1,0),Vector2(0,.2),Vector2(-.1,-.2)]:
		for width:float in [8.0,12.0,20.0,28.0]:
			for phase:float in [0.0,1.7,4.5]:
				var builder=Support.new();builder.gradient=gradient
				for enabled:bool in [false,true]:
					var reference=on_reference.new() if enabled else off_reference.new();var actual=LOD.new();actual.conduit_grounded_shoulders=enabled
					for generator in [reference,actual]:generator.conduit(builder,Vector2.ZERO,Vector2(1024,0),width,phase,Color(.34,.28,.26))
					verify(packed(actual)==packed(reference),"COMPLETE production primitive equals frozen pre-feature or accepted private source")
					records.append({"gradient":str(gradient),"width":width,"phase":phase,"enabled":enabled,"vertices":actual.vertices.size()})
	# Explicit finite-far and retained-contact fallback paths,not just the near
	# dispatcher that hid the first inactive trial. Same old roots/vertex controls.
	for floor_value:float in [-1000.0,INF]:
		for enabled:bool in [false,true]:
			var builder=Support.new();builder.set_meta(LOD.CONTEXT,{"bounds":Rect2(Vector2(-32000,-32000),Vector2(65536,65536)),"ratio":.5,"enabled":true,"floor":floor_value})
			var reference=on_reference.new() if enabled else off_reference.new();var actual=LOD.new();actual.conduit_grounded_shoulders=enabled
			for generator in [reference,actual]:generator.conduit(builder,Vector2.ZERO,Vector2(1024,0),28,1.7,Color(.34,.28,.26))
			verify(packed(actual)==packed(reference),"Complete finite-far/retained-contact production equals exact reference")
	var guards:Dictionary={}
	for path:String in [References.BEFORE_BASE,References.BEFORE_LOD,References.ACCEPTED,"res://scripts/biome_extension_settings.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://tools/biome_extensions/grounded_conduit_references.gd","res://tools/biome_extensions/check_conduit_shoulder_candidate.gd","res://tools/biome_extensions/check_grounded_conduit_registration.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_grounded_conduit_registration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"checks":checks,"source_sha256":guards,"cases":records,"far_reference_cases":4,"scope":"REGISTERED independent saved control,96 complete actual near primitive/reference pairs at48 support/width/phase cases,plus four complete finite-far/retained-contact pairs. Off compares full frozen original near/far methods;on compares exact archived accepted private source,not code regenerated from edited production. All vertices/normals/colors/UVs exact. No native/controller/full worker/cache/traversal/art certificate."},"  "));print("GROUNDED_CONDUIT_REGISTERED ",checks);quit()
