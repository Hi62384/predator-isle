extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/render_grounded_conduits.gd")
	code=code.replace("experiment_ground_union_trial_4da5146ad6b0/sources/tools/biome_extensions/artifacts/render_tissue_variation_registered.json.txt","experiment_tissue_variation_adoption_8ceb1fbfe9a3/sources/tools/biome_extensions/artifacts/render_tissue_variation_overlay.json.txt")
	var marker:String="var script:=GDScript.new();script.source_code=code";assert(code.count(marker)==1)
	code=code.replace(marker,'''code=code.replace("for seed_id:int in [73921,17,92881]:","for seed_id:int in [73921]:").replace(".builder(seed_id,true)",".builder(seed_id,true,1)")
	code=code.replace("grounded_conduits_worker_%d_%d_%s.png","grounded_overlay_worker_%d_%d_%s.png").replace("render_grounded_conduits.json","render_grounded_overlay.json")
	var extra_guard:String="var phases:Array=[]";assert(code.count(extra_guard)==1);code=code.replace(extra_guard,'hashes["res://tools/biome_extensions/render_grounded_overlay.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/render_grounded_overlay.gd")\\n\\t'+extra_guard)
	var live_guard:String="var current:Dictionary=cut();";assert(code.count(live_guard)==1);code=code.replace(live_guard,'verify(terrain._settings_snapshot.alien_infected_coverage==0 and terrain._settings_snapshot.alien_infected.overlay_strength>.0,"Actual zero-coverage partial infection over Grass");'+live_guard)
	code=code.replace('"scope":"REGISTERED actual','"scope":"ADDITIONAL single ORIGINAL frozen partial-infection domain,seed73921/Grass100/Alien0/overlay.7. Three actual false/true/false cuts/nine near-context-ground images,not a replacement for pure worlds. REGISTERED actual')
	'''+marker)
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("prepare")
