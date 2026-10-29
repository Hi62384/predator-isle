extends "res://tools/caves/check_crystal_features.gd"
const Regions=preload("res://scripts/caves/biome_regions.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_features.gd","res://tools/caves/check_frozen_features.gd","res://scripts/caves/crystal_features.gd","res://scripts/caves/crystal_geometry.gd","res://scripts/caves/field.gd","res://shaders/cave_crystal_feature.gdshader"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var settings:Dictionary=definition.feature_configuration.duplicate();settings.density=1.0;var region:Dictionary=crystal_fixture();var field=Field.new();field.include_surface_air=false
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	check(field.compile([region],height,[],region.cave_biome_regions),"Same real shared controlled chamber for complete mineral-axis transport")
	var seeds:Array=[73921,17,92881]
	for i in range(33):seeds.append(1000+i)
	var forms:int=0;var vertices:int=0;var mismatches:int=0;var tilted:int=0;var veins:int=0;var geometry=CrystalGeometry.new()
	for seed_id:int in seeds:
		for key:Vector3i in [Vector3i.ZERO,Vector3i(0,1,0)]:
			var payload:Dictionary=Crystal.new().build(field,key,seed_id,[region],settings,{})
			for batch:Dictionary in payload.batches:check(batch.arrays[Mesh.ARRAY_TEX_UV2].size()==batch.arrays[Mesh.ARRAY_VERTEX].size(),"Every committed batched vertex has complete mineral-axis transport")
			for placement:Dictionary in payload.placements:
				var selected:Array=payload.batches.filter(func(batch:Dictionary)->bool:return batch.kind==placement.batch);var data:PackedVector2Array=selected[0].arrays[Mesh.ARRAY_TEX_UV2]
				if placement.kind=="mineral_vein":
					veins+=1
					for i in range(placement.first_vertex,placement.first_vertex+placement.vertex_count):
						if data[i]!=Vector2.ZERO:mismatches+=1
					continue
				forms+=1
				if absf(placement.axis.y)<.9:tilted+=1
				var prototype:PackedVector3Array=geometry.prototype(placement.family,placement.broken)[Mesh.ARRAY_VERTEX];var phase:float=Regions.random("A",seed_id,"crystal/phase")*TAU
				if str(placement.id).contains("/secondary/"):phase+=.2*int(str(placement.id).get_slice("/secondary/",1))
				for i in range(prototype.size()):
					var expected:=Vector2(prototype[i].y*placement.height,phase);vertices+=1
					if data[placement.first_vertex+i]!=expected:mismatches+=1
	check(forms>100 and vertices>1000 and tilted>0 and veins>0 and mismatches==0,"Every actual generated growth coordinate matches physical local axis/height and deterministic patch phase exactly,including angled/ceiling crystals;not global-Y painted stripes")
	var source:String=FileAccess.get_file_as_string("res://shaders/cave_crystal_feature.gdshader");check(source.contains("float phase=UV2.x") and source.contains("float striae_phase=UV2.x") and source.contains("fwidth(striae_phase)"),"Native shader consumes the actual physical-axis coordinates and filters cleavage striae")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable original mineral-axis source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_growth_transport.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"actual_crystals":forms,"tested_crystal_vertices":vertices,"angled_or_wall_crystals":tilted,"vein_segments":veins,"exact_transport_mismatches":mismatches,"scope":"Same36fixed seeds/two half-open cells/actual shared mineral chamber. Complete UV2 physical-axis distance and patch phase compared with original hard-facet prototype transformed height;all bed vertices have complete zero fallback. No collision,world occurrence,rendered photographic art or full-live/FPS completion claim."},"  "));print("CRYSTAL_GROWTH_TRANSPORT ",checks," forms=",forms," vertices=",vertices," tilted=",tilted," mismatches=",mismatches," failures=",failures);quit(0 if failures.is_empty() else 1)
