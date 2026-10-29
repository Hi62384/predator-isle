extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/render_alien_tissue_flow.gd")
	var seeds:String="for seed_id:int in [73921,17,92881]:";assert(code.count(seeds)==1);code=code.replace(seeds,"for seed_id:int in [73921]:")
	var builder:String=".builder(seed_id,true);var field=";assert(code.count(builder)==1);code=code.replace(builder,".builder(seed_id,true,1);var field=")
	var admission:String="if candidate.weight>.5:point=p;frame=candidate;break";assert(code.count(admission)==1)
	code=code.replace(admission,"if candidate.weight>.5 and field.network(p).age>=.15 and field.network(p).age<=.3 and locator._get_height(p.x,p.y)>locator.get_water_surface_height(p.x,p.y)+2:point=p;frame=candidate;break")
	var gate:String='verify(maps>0 and shared_shell_maps>0,"Material transport actually used by terrain AND supplemental shells")';assert(code.count(gate)==1)
	code=code.replace(gate,'verify(maps>0 and terrain.settings.alien_infected_coverage==0 and terrain.settings.alien_infected.overlay_strength>0,"Actual zero-coverage partial overlay receives material transport")')
	code=code.replace("alien_tissue_flow_%d_%d_%s.png","tissue_flow_overlay_%d_%d_%s.png").replace("render_alien_tissue_flow.json","render_tissue_flow_overlay.json")
	var guard:String="for path:String in [SAMPLE_REFERENCE,";assert(code.count(guard)==1)
	var generated:String="res://tools/biome_extensions/artifacts/tissue_flow_overlay_fixture.txt"
	code=code.replace(guard,'for path:String in ["res://tools/biome_extensions/render_tissue_flow_overlay.gd","'+generated+'",SAMPLE_REFERENCE,')
	code=code.replace('"scope":"Actual production four-worker/controller pure Alien', '"scope":"ADDITIONAL single-seed zero-coverage partial-overlay domain:underlying pure Grass,Alien overlay.7,actual dry nerve-material/age admission before freezing views. This does not replace any pure-Alien fixture or certify mixed legacy/coastal worlds. Native production four-worker/controller')
	code=code.replace("at three fixed-discovered on-land nerve trunks,three views","at one newly admitted dry overlay nerve trunk,three views").replace("at all nine views","at all three views").replace("27 primary images,18 sample-reference/return images","Nine primary images,six sample-reference/return images")
	FileAccess.open(generated,FileAccess.WRITE).store_string(code)
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
