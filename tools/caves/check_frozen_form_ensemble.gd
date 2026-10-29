extends "res://tools/caves/check_frozen_features.gd"
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://config/caves/biomes/frozen_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 150.0
	var definition:Resource=load("res://config/caves/biomes/frozen_cave_definition.tres");var region:Dictionary=Features.new().decorate_region(fixture(),height,73921,definition.feature_configuration,400,10);var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Real shared chamber/basin with protected original route")
	var seeds:Array[int]=[73921,17,92881]
	for value in range(1000,1045):seeds.append(value)
	var kinds:Dictionary={};var thin_batches:int=0;var first_column:int=-1;var first_thin:int=-1;var records:Array=[];var attached:int=0;var total:int=0;var minimum:float=INF;var maximum:float=0
	for seed_id:int in seeds:
		var generator=Features.new();var configuration:Dictionary={"density":1.0,"curtain_chance":0.0,"lake_ice":false};var result:Dictionary=generator.build(field,Vector3i.ZERO,seed_id,[region],configuration,{})
		check(result.valid and var_to_bytes(result)==var_to_bytes(generator.build(field,Vector3i.ZERO,seed_id,[region],configuration,{})),"Complete retained48seed ensemble cold/repeat deterministic,without early stop on a favorable form")
		var flat_configuration:Dictionary=configuration.duplicate();flat_configuration.smooth_normals=false;var flat:Dictionary=Features.new().build(field,Vector3i.ZERO,seed_id,[region],flat_configuration,{})
		check(var_to_bytes(result.placements)==var_to_bytes(flat.placements) and result.batches.size()==flat.batches.size(),"Render-only smoothing does not move/regenerate any feature,attachment or ownership")
		for batch in range(result.batches.size()):
			for channel:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_COLOR]:check(var_to_bytes(result.batches[batch].arrays[channel])==var_to_bytes(flat.batches[batch].arrays[channel]),"Complete native collision-source/ice character arrays bit-exact with smoothing off")
		var case_kinds:Dictionary={}
		for placement:Dictionary in result.placements:
			kinds[placement.kind]=int(kinds.get(placement.kind,0))+1;case_kinds[placement.kind]=int(case_kinds.get(placement.kind,0))+1;total+=1;minimum=minf(minimum,placement.height);maximum=maxf(maximum,placement.height)
			if placement.kind=="ice_column" and first_column<0:first_column=seed_id
			var tip:float=placement.root.y+placement.up*placement.height;check(not generator.shapes.protected(field,placement.root,placement.radius,minf(placement.root.y,tip),maxf(placement.root.y,tip)),"Every full column/icicle/stalagmite footprint keeps original mandatory clearance")
			for ring:PackedVector3Array in placement.attachments:
				for point:Vector3 in ring:attached+=1;check(field.sample(point)>.06,"Every actual column foot/crown and icicle contact embedded in measured rock")
		for batch:Dictionary in result.batches:
			if batch.kind=="thin_ice":
				thin_batches+=1
				if first_thin<0:first_thin=seed_id
			var positions:PackedVector3Array=batch.arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=batch.arrays[Mesh.ARRAY_NORMAL]
			for i in range(0,positions.size(),3):check(absf(normals[i].length()-1)<.0001 and (positions[i+2]-positions[i]).cross(positions[i+1]-positions[i]).normalized().dot(normals[i])>.1,"Actual smooth forms retain unit render normals on correct side of nondegenerate native triangles")
		records.append({"seed":seed_id,"forms":result.placements.size(),"kinds":case_kinds,"batch_kinds":result.batches.map(func(item:Dictionary)->String:return item.kind)})
	check(records.size()==48 and total>=24 and kinds.has("ice_column") and kinds.has("icicle") and kinds.has("ice_stalagmite"),"Positive generated floor-to-ceiling columns,variable hanging ice and rising ice—not only registry enums")
	check(thin_batches>0 and maximum-minimum>5,"Sparse selective thin-ice batch and broad actual geometric scale range")
	var opaque:ShaderMaterial=definition.surface_provider.new().feature_material("ice",definition.material_configuration,true);var thin_material:ShaderMaterial=definition.surface_provider.new().feature_material("thin_ice",definition.material_configuration,true);check(not opaque.shader.code.contains("ALPHA=") and thin_material.shader.code.contains("ALPHA=.82") and thin_material.shader.code.contains("depth_prepass_alpha"),"Transparency restricted to selected tiny thin-ice batches,never all cave walls or lake sheets")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable generated Frozen form ensemble "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frozen_form_ensemble.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"forms":total,"kinds":kinds,"thin_batches":thin_batches,"attached_samples":attached,"height_minimum":minimum,"height_maximum":maximum,"first_column_seed_in_declared_order":first_column,"first_thin_seed_in_declared_order":first_thin,"scope":"Complete predetermined48seed controlled real shared chamber/large retained basin,all cases/negative kinds retained;density1 only to inspect mechanism,normal column probability/geometry/protection unchanged,curtains/lake meshes off to isolate forms. Actual variable geometry,cold/repeated exact output,complete rock contacts and mandatory clearance. Not48independent natural-world occurrence samples,native walks,rendered thin transmission or complete Frozen acceptance."},"  "));print("FROZEN_FORM_ENSEMBLE ",checks," forms=",total," kinds=",kinds," thin=",thin_batches," failures=",failures);quit(0 if failures.is_empty() else 1)
