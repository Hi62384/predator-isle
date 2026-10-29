extends "res://tools/caves/check_frozen_features.gd"
const Original=preload("res://tools/caves/references/magma_pre_large_bin_field.gd")
func original_owner(host:String,seed_id:int):
	var builder=make_builder(1,seed_id)
	if host!="wise_mountains":builder.settings.wise_mountains_coverage=0;builder.settings.set(host+"_coverage",100);builder._configure_noise()
	return builder
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/references/magma_pre_large_bin_field.gd","res://tools/biome_extensions/artifacts/diagnose_magma_field_rejection.json","res://config/caves/biomes/magma_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var prior=Original.new();var current=Field.new();current.include_surface_air=false;var region:Dictionary=fixture();region.erase("pools")
	check(prior.compile([region],flat,[],region.cave_biome_regions) and current.compile([region],flat,[],region.cave_biome_regions),"Original supported cold fixture compiles both independent kernels")
	var errors:int=0
	for x in range(-24,113,4):
		for z in range(0,65,4):
			for y:float in [16,19.75,20,20.25,24,40,60]:
				var point:=Vector3(x,y,z);errors+=int(prior.sample(point)!=current.sample(point) or prior.normal(point)!=current.normal(point))
	check(errors==0 and var_to_bytes(prior.bins)==var_to_bytes(current.bins) and prior.numeric_bytes()==current.numeric_bytes(),"All original scalar/normals/spatial references/numeric size exact for supported fields")
	for key:Vector3i in [Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0)]:check(var_to_bytes(Mesher.new().build(prior,key,2))==var_to_bytes(Mesher.new().build(current,key,2)),"Entire original native mesh/normal/indices byte-exact")
	var trace:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/diagnose_magma_field_rejection.json"));var repaired:Array=[]
	for row:Dictionary in trace.rows:
		var builder=original_owner(str(row.host),int(row.seed))
		var work=preload("res://scripts/caves/workload.gd").new();check(work.configure(builder.settings,Config.new(),int(row.seed),0),"Original failed actual host/seed configures")
		var actual:Dictionary=work.network.region(Vector2i(row.site[0],row.site[1]));check(work.use_bundle({"cell":actual.id,"regions":[actual],"connections":[]}),"Original failed actual large-room field now compiles "+str(row.ordinal))
		var rejected=Original.new();check(not rejected.compile([actual],builder._get_height,[],actual.cave_biome_regions),"Independent old128-bin kernel still rejects this exact original actual region")
		check(work.field.numeric_bytes()<32*1024*1024 and work.field._spatial_reference_count<=Field.MAX_SPATIAL_REFERENCES,"Actual repaired world remains under unchanged32MiB numeric test and bounded aggregate references");repaired.append({"ordinal":row.ordinal,"numeric_bytes":work.field.numeric_bytes(),"features":work.field.begins.size(),"references":work.field.references})
	var bounded=Field.new();var accepted:int=0
	while accepted<65536 and bounded.append_feature(Vector3(1,0,1),Vector3(1,0,1),Vector2(32,30),2,3):accepted+=1
	check(accepted>0 and accepted<65536 and bounded._spatial_reference_count<=Field.MAX_SPATIAL_REFERENCES,"Actual repeated large primitives hit finite aggregate reference budget before feature ceiling")
	var before:int=bounded.begins.size();check(not bounded.append_feature(Vector3(1,0,1),Vector3(1,0,1),Vector2(32,30),2,3) and bounded.begins.size()==before,"Budget rejection occurs before partially mutating primitive arrays")
	bounded.clear();check(bounded._spatial_reference_count==0 and bounded.append_feature(Vector3.ZERO,Vector3.ZERO,Vector2(4,8),2),"Clear releases aggregate budget and ordinary generation resumes")
	check(not bounded.append_feature(Vector3.ZERO,Vector3.ZERO,Vector2(1000000,1000000),2),"Malformed huge extent rejects before reference-count multiplication or allocation")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable large-room spatial-bound source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_large_magma_field_bounds.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"old_supported_errors":errors,"repaired":repaired,"aggregate_limit":Field.MAX_SPATIAL_REFERENCES,"large_primitives_before_limit":accepted,"scope":"Original four720cohort field failures;actual bounded144bin collapse rooms compile under256primitive/2097152aggregate references. Already supported full scalar/normals/bins/numeric size and3wholemeshes byte-exact against independent old kernel;real aggregate exhaustion/atomic reject/clear/overflow controls. Existing32MiB numeric and2048MiB native gates unchanged;not world scenic acceptance."},"  "));print("LARGE_MAGMA_FIELD_BOUNDS ",checks," repaired=",repaired," accepted=",accepted," failures=",failures);quit(0 if failures.is_empty() else 1)
