extends "res://tools/caves/check_crystal_world_cohort.gd"
const FrozenMesher=preload("res://tools/caves/references/shore_original_mesher.gd")
const FrozenCandidate=preload("res://tools/caves/references/shore_crossing_candidate.gd")
const CurrentMesher=preload("res://scripts/caves/portal_mesher.gd")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/references/shore_original_mesher.gd","res://tools/caves/references/shore_crossing_candidate.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);definition.feature_configuration.large_lake_frequency=1.0;var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var b=owner("crystal_wastes",17);var work=Workload.new();check(work.configure(b.settings,config,17,0),"Same first actual diagnostic lake configuration");var bundle:Dictionary=work.discover(Vector2i(9,-3));check(not bundle.has("error"),"Same actual original complete discovery bundle")
	var pool:Dictionary={}
	for region:Dictionary in bundle.regions:
		for body:Dictionary in region.get("pools",[]):
			if str(body.id)=="9:-3:1:3:lobe:0:seepage":pool=body;break
	check(not pool.is_empty() and pool.get("precise_shore",false),"Original preselected actual lake enables bounded shore refinement")
	if pool.is_empty():quit(1);return
	var scopes:Array=work.field.precise_shores.duplicate(true);var original_field:PackedByteArray=var_to_bytes([work.field.begins,work.field.ends,work.field.dimensions,work.field.kinds,work.field.styles]);var rows:Array=[];var boundary:Dictionary={};var changed:int=0
	var center:Vector3i=work.field.cell(pool.center)
	for key:Vector3i in [center,center+Vector3i.UP,center+Vector3i.BACK,center+Vector3i.UP+Vector3i.BACK]:
		var candidate=FrozenCandidate.new();candidate.shore_center=pool.center;candidate.shore_radius=pool.radius;var reference:Array=candidate.build(work.field,key,2);var actual:Array=CurrentMesher.new().build(work.field,key,2);check(var_to_bytes(actual)==var_to_bytes(reference),"Production shore is complete byte-exact frozen pre-adoption private candidate "+str(key));var topology:Dictionary=FrozenCandidate.topology(actual,Vector3(key)*64);check(topology.interior_open_edges==0 and topology.nonmanifold_edges==0 and topology.collapsed==0,"No interior openings/nonmanifold/zero-area faces "+str(key))
		for edge:Array in topology.boundary:
			var a:Vector3i=Vector3i((edge[0]*4096).round());var c:Vector3i=Vector3i((edge[1]*4096).round());var id:Array=[a,c];boundary[id]=int(boundary.get(id,0))+1
		work.field.precise_shores=[];var off:Array=CurrentMesher.new().build(work.field,key,2);var old:Array=FrozenMesher.new().build(work.field,key,2);check(var_to_bytes(off)==var_to_bytes(old),"Independent complete frozen original mesh exact in OFF mode "+str(key));work.field.precise_shores=scopes;changed+=int(var_to_bytes(actual)!=var_to_bytes(off));check(var_to_bytes(CurrentMesher.new().build(work.field,key,2))==var_to_bytes(actual),"Exact ON/OFF/ON complete geometry return "+str(key));rows.append({"key":str(key),"refined_edges":candidate.refined_edges,"old_max_residual":candidate.original_residual,"new_max_residual":candidate.refined_residual,"vertices":actual[Mesh.ARRAY_VERTEX].size()})
	var internal_unmatched:int=0;var matched:int=0
	for edge:Array in boundary:
		var a:Vector3=Vector3(edge[0])/4096;var c:Vector3=Vector3(edge[1])/4096
		if (a.y==0 and c.y==0) or (a.z==(center.z+1)*64 and c.z==(center.z+1)*64):
			if boundary[edge]!=2:internal_unmatched+=1
			else:matched+=1
	check(internal_unmatched==0 and matched>0,"Actual neighboring cell face segments match after independent refined extraction")
	check(changed>0 and original_field==var_to_bytes([work.field.begins,work.field.ends,work.field.dimensions,work.field.kinds,work.field.styles]),"Positive mesh correction leaves complete compiled primitive volume unchanged")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable shore adoption "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_shore_adoption.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"rows":rows,"matched_internal_segments":matched,"internal_unmatched":internal_unmatched,"scope":"Same first actual diagnostic lake;production mesh byte-exact independent frozen pre-adoption candidate,full original OFF and ON/OFF/ON,closed per-cell topology and shared cell-face segments,unchanged scalar primitives. No native candidate physical or FPS claim."},"  "));print("CRYSTAL_SHORE_ADOPTION ",checks," rows=",rows," matched=",matched," unmatched=",internal_unmatched," failures=",failures);quit(0 if failures.is_empty() else 1)
