extends "res://tools/biome_extensions/check_all.gd"
func _initialize()->void:call_deferred("run")
func run()->void:
	var records:Array=[];var positive:int=0;var skipped:int=0
	for span:float in [256,4096]:
		for density:float in [0.0,1.0]:
			var arrays:Array=[];var timings:Array=[];var calls:Array=[]
			for lazy:bool in [false,true]:
				var b=make_builder(7,73921);b.chunk_size=span;b.settings.alien_infected.structure_density=density;b._configure_noise()
				var coordinate:=Vector2i(floori(87471.5859375/span),floori(-112298.5078125/span))
				var feature=preload("res://scripts/terrain_feature_meshes.gd").new();feature.builder=b
				var counter:Array=[0];var provider:Callable=func(bounds:Rect2)->Array:counter[0]+=1;return feature.portal_sites(bounds)
				var emitter=Structures.new();emitter.lazy_hive_portal_queries=lazy
				var began:int=Time.get_ticks_usec();arrays.append(emitter.build(b,coordinate,Structures.support_grids(),provider));timings.append((Time.get_ticks_usec()-began)/1000.0);calls.append(counter[0])
			check(var_to_bytes(arrays[0])==var_to_bytes(arrays[1]),"Exact complete mesh vertices,normals,colors,UVs and indices across query order")
			var vertices:int=arrays[1][2][Mesh.ARRAY_VERTEX].size() if arrays[1][2]!=null else 0
			if vertices>0:positive+=1;check(calls==[1,1],"Admitted Hive retains original portal exclusion query")
			if density==0:skipped+=1;check(calls==[1,0] and vertices==0,"No admitted Hive avoids the entire unused portal query")
			records.append({"span":span,"density":density,"vertices":vertices,"eager_ms":timings[0],"lazy_ms":timings[1],"provider_calls":calls})
	check(positive>0 and skipped>0,"Both actual emitted Hive and empty-leaf cases exercised")
	var output:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records,"source_sha256":{"res://scripts/biome_extension_structures.gd":FileAccess.get_sha256("res://scripts/biome_extension_structures.gd")},"scope":"Complete actual Hive array equality and original portal-provider output;ordered headless timings are not an isolated speed claim"}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_lazy_hive_portals.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "));print("LAZY_HIVE_PORTALS ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
