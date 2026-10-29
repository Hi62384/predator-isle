extends SceneTree
func _initialize()->void:
	var original:String="res://tools/biome_extensions/check_crystal_bulk_optics.gd";var source:String=FileAccess.get_file_as_string(original)
	source=source.replace('"res://tools/biome_extensions/crystal_bulk_candidate.gd"','"res://scripts/lod_biome_extension_structures.gd"')
	source=source.replace('var candidate=Candidate.new()','var candidate=Candidate.new();candidate.crystal_bulk_material=true')
	source=source.replace('res://tools/biome_extensions/crystal_bulk_candidate.gdshader','res://shaders/crystal_bulk.gdshader').replace('res://tools/biome_extensions/crystal_bulk_optics.gdshaderinc','res://shaders/crystal_bulk_optics.gdshaderinc')
	source=source.replace('res://tools/biome_extensions/check_crystal_bulk_optics.gd','res://tools/biome_extensions/check_crystal_bulk_gpu_registered.gd')
	var marker:String='\tvar b:=Support.new();var geometry:Array=[]';assert(source.count(marker)==1)
	source=source.replace(marker,'\tguards["'+original+'"]=FileAccess.get_sha256("'+original+'")\n'+marker)
	source=source.replace('artifacts/crystal_bulk_optics_gpu.png','artifacts/crystal_bulk_gpu_registered.png').replace('artifacts/check_crystal_bulk_optics.json','artifacts/check_crystal_bulk_gpu_registered.json')
	source=source.replace('"production_registration":false','"production_registration":true').replace('PRIVATE18complete','REGISTERED18complete').replace('Native material/full-controller integration/visual acceptance separate.','Actual registered geometry class and shader include exercised;native material/full-controller integration/visual acceptance separate.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
