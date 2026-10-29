extends "res://tools/biome_extensions/check_all.gd"
const References=preload("res://tools/biome_extensions/crystal_bulk_references.gd")
func attributes(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func run()->void:
	var guards:Dictionary={};var records:Array=[];var roots:Array=[]
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/biome_extension_settings.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://shaders/crystal_bulk.gdshader","res://shaders/crystal_bulk_optics.gdshaderinc","res://shaders/crystal_transmission.gdshader","res://tools/biome_extensions/crystal_bulk_references.gd","res://tools/biome_extensions/check_crystal_bulk_registration.gd",References.ROOT+"scripts/biome_extension_structures.gd.txt",References.ROOT+"tools/biome_extensions/crystal_bulk_candidate.gd.txt",References.ROOT+"tools/biome_extensions/crystal_bulk_candidate.gdshader.txt",References.ROOT+"tools/biome_extensions/crystal_bulk_optics.gdshaderinc.txt"]:guards[path]=FileAccess.get_sha256(path)
	check(FileAccess.get_file_as_string("res://shaders/crystal_bulk.gdshader").replace('res://shaders/crystal_bulk_optics.gdshaderinc','res://tools/biome_extensions/crystal_bulk_optics.gdshaderinc').strip_edges()==FileAccess.get_file_as_string(References.ROOT+"tools/biome_extensions/crystal_bulk_candidate.gdshader.txt").strip_edges(),"Complete registered shader exactly matches frozen accepted trial except include location")
	check(FileAccess.get_file_as_string("res://shaders/crystal_bulk_optics.gdshaderinc").strip_edges()==FileAccess.get_file_as_string(References.ROOT+"tools/biome_extensions/crystal_bulk_optics.gdshaderinc.txt").strip_edges(),"Accepted optical formula unchanged")
	var before:=References.script_for(false);var accepted:=References.script_for(true)
	var saved:Resource=load("res://config/biomes/crystal_wastes_settings.tres");check(saved.crystal_bulk_material and saved.crystal_grounded_roots,"Independent default-on optical and foundation controls")
	var config:Resource=saved.duplicate();config.crystal_bulk_material=false;check(config.crystal_grounded_roots,"Optical off does not disable grounded roots");var roundtrip_path:String="res://tools/biome_extensions/artifacts/crystal_bulk_settings_roundtrip.tres";check(ResourceSaver.save(config,roundtrip_path)==OK,"Saved optical control");var reloaded:Resource=ResourceLoader.load(roundtrip_path,"",ResourceLoader.CACHE_MODE_IGNORE);check(not reloaded.crystal_bulk_material and reloaded.crystal_grounded_roots,"Independent setting roundtrip")
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(5,seed_id);var field=b._extras[5];var d:Dictionary=field.descriptor(Vector2i(-4,-3),1700);var p:Vector2=d.position;var anchor:=Vector3(p.x,b._get_height(p.x,p.y)-8,p.y)
		for habit:int in range(6):
			for broken:bool in [false,true]:
				for enabled:bool in [false,true]:
					var actual=Structures.new();actual.crystal_grounded_roots=true;actual.crystal_bulk_material=enabled;var reference=(accepted if enabled else before).new();reference.crystal_grounded_roots=true
					for g in [actual,reference]:
						g.origin=Vector3(floorf(p.x/256)*256,0,floorf(p.y/256)*256);g._support_steps=Structures.support_grids();g.prism(b,anchor,24+habit*3,120+habit*50,habit,d.angle,Vector2(.1,-.08),broken,Color(.59,.61,.58))
					check(attributes(actual)==attributes(reference),"Actual complete off/on arrays match independent full frozen methods")
					records.append({"seed":seed_id,"habit":habit,"broken":broken,"enabled":enabled,"vertices":actual.vertices.size()})
	var admission_path:String=References.ROOT+"tools/biome_extensions/artifacts/admit_crystal_bulk_styles.json.txt";var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));assert(admission.passed);guards[admission_path]=FileAccess.get_sha256(admission_path)
	for site:Dictionary in admission.cases:
		var b=make_builder(5,73921);var p:=Vector2(site.position[0],site.position[1]);var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256));var original:Array=[]
		for enabled:bool in [false,true,false]:
			b.settings.crystal_wastes.crystal_bulk_material=enabled;var actual:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate);var reference:Array=(accepted if enabled else before).new().build(b,coordinate)
			check(actual==reference and actual[0]!=null,"Complete saved-control root matches frozen accepted/original full method")
			if original.is_empty():original=actual
			elif enabled:
				check(actual!=original,"Actual optical metadata intervention")
				for channel:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR]:check(actual[0][channel]==original[0][channel],"All physical geometry/normals/tint unchanged")
			else:check(actual==original,"Original full UV arrays restored independently")
			roots.append({"kind":site.kind,"id":site.id,"enabled":enabled,"vertices":actual[0][Mesh.ARRAY_VERTEX].size()})
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable registered optics source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_crystal_bulk_registration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"roots":roots,"scope":"REGISTERED independent default-on crystal_bulk_material. Exact accepted shader/formula,Resource storage roundtrip,72 complete primitive off/on pairs across six habits/broken/intact/three seeds,and six original pre-admitted actual-habit complete saved-control root off/on/off triplets. Full frozen prior geometry method plus independently archived optical metadata formula,not a regenerated coupled oracle. Only UV metadata changes;all vertices/normals/colors and foundation control preserved. Actual configured controller shader binding,native rendering,GPU cost/current shared regression are separate gates."},"  "))
	print("CRYSTAL_BULK_REGISTERED ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
