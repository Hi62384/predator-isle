extends SceneTree
const FROZEN="res://tools/biome_extensions/artifacts/revisions/experiment_render_alien_tissue_flow_fc1f200ac1af/sources/scripts/alien_tissue_coordinates.gd.txt"
const Coordinates=preload("res://scripts/alien_tissue_coordinates.gd")
func _initialize()->void:
	var original:=GDScript.new();original.source_code=FileAccess.get_file_as_string(FROZEN);assert(original.reload()==OK);var reference=original.new()
	var guards:Dictionary={}
	for path:String in [FROZEN,"res://scripts/alien_tissue_coordinates.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd","res://tools/biome_extensions/check_packed_tissue_coordinates.gd"]:guards[path]=FileAccess.get_sha256(path)
	var records:Array=[];var failures:Array=[];var ratios:Array=[];var number:int=0
	for seed_id:int in [73921,17,92881]:
		for scale:float in [.2,1,2]:
			for shape:int in range(3):
				var results:Dictionary={};var times:Dictionary={}
				for packed:bool in ([false,true] if number%2==0 else [true,false]):
					var b=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(seed_id,true);b.settings.alien_infected.feature_scale=scale;b._configure_noise();var field=b._extras[7]
					var paths:PackedVector2Array=field.network_edges(Vector2i(-2,3));var center:Vector2=paths[0].lerp(paths[1],.5)
					var span:Vector2=[Vector2(256,256),Vector2(1024,512),Vector2(4096,2048)][shape];var cells:Vector2i=[Vector2i(32,32),Vector2i(128,64),Vector2i(128,128)][shape];var origin:Vector2=(center-span*.5)/8;origin=origin.floor()*8
					var start:int=Time.get_ticks_usec();results[packed]=Coordinates.rectangle(field,origin,span,cells) if packed else reference.rectangle(field,origin,span,cells);times[packed]=float(Time.get_ticks_usec()-start)/1000
				if results[false]!=results[true]:failures.append("Complete packed map changed "+str([seed_id,scale,shape]))
				var ratio:float=times[true]/maxf(times[false],.001);ratios.append(ratio);records.append({"seed":seed_id,"scale":scale,"shape":shape,"bytes":results[true].data.size(),"complete_exact":results[true]==results[false],"dictionary_ms":times[false],"packed_ms":times[true],"ratio":ratio});number+=1
	for path:String in guards:
		if FileAccess.get_sha256(path)!=guards[path]:failures.append("Changed packed source "+path)
	ratios.sort();var result:Dictionary={"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"cases":records,"median_packed_to_frozen_ratio":ratios[ratios.size()/2],"scope":"Twenty-seven complete numeric map comparisons to the frozen preceding production implementation:three seeds,min/default/max feature scales,square and rectangular domains up to129² nodes. Every float32 byte/local path ID/dimension exact. Alternating fresh-field CPU timings characterize allocation reduction,not isolated multithread/GPU or all-world performance."}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_packed_tissue_coordinates.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("PACKED_TISSUE_COORDINATES ratio=",result.median_packed_to_frozen_ratio," failures=",failures);quit(0 if failures.is_empty() else 1)
