extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	# Reuse every registered same-scene control and configured-binding check;
	# only select the ORIGINAL already-frozen zero-coverage overlay fixture.
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/render_tissue_variation_registered.gd")
	var marker:String="var script:=GDScript.new();script.source_code=code";assert(code.count(marker)==1)
	var edits:String='''code=code.replace("experiment_tissue_flow_adoption_1e396f3b7915/sources/tools/biome_extensions/artifacts/render_alien_tissue_flow.json.txt","experiment_tissue_flow_adoption_1e396f3b7915/sources/tools/biome_extensions/artifacts/render_tissue_flow_overlay.json.txt")
	code=code.replace("for seed_id:int in [73921,17,92881]:","for seed_id:int in [73921]:").replace(".builder(seed_id,true)",".builder(seed_id,true,1)")
	code=code.replace("tissue_variation_registered_%d_%s_","tissue_variation_overlay_%d_%s_").replace("render_tissue_variation_registered.json","render_tissue_variation_overlay.json")
	var overlay_guard:String="var cuts:Array=[]";assert(code.count(overlay_guard)==1)
	code=code.replace(overlay_guard,'hashes["res://tools/biome_extensions/render_tissue_variation_overlay.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/render_tissue_variation_overlay.gd")\\n\\t'+overlay_guard)
	code=code.replace('"scope":"REGISTERED actual configured','"scope":"ADDITIONAL one frozen seed73921 Grass100/Alien0/overlay.7 domain,not a substitute for any pure fixture. Three original dry nerve-material views/fifteen control images. REGISTERED actual configured')
	'''
	code=code.replace(marker,edits+marker)
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("prepare")
