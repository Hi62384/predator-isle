extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Batch=preload("res://scripts/caves/surface_batch.gd")
const Collision=preload("res://scripts/terrain_collision.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in ["workload","cave_settings","surface_batch","surface_context","surface_payload","surface_cut","field","mesher","portal_field","portal_mesher","network","route_solver"]:
		var path:String="res://scripts/caves/"+name+".gd";guards[path]=FileAccess.get_sha256(path)
	guards["res://tools/caves/check_portal_batch_equivalence.gd"]=FileAccess.get_sha256("res://tools/caves/check_portal_batch_equivalence.gd")
	var b=make_builder(3,73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual independent numeric worker configured");var bundle:Dictionary=work.discover(Vector2i(9,-3));check(not bundle.has("error"),"Original complete3x3graph and neighboring links discovered")
	var entrance:Dictionary={}
	for candidate:Dictionary in bundle.entrances:
		if candidate.region==Vector2i(9,-3):entrance=candidate;break
	check(not entrance.is_empty() and entrance.columns.size()==16 and is_finite(entrance.minimum_exposed_floor),"Original actual16-column mouth retained with measured exposed-altitude bound")
	var parents:Array=[];var keys:Dictionary={}
	for column:Vector2i in entrance.columns:keys[Vector2i(floori(float(column.x)/4),floori(float(column.y)/4))]=true
	for key:Vector2i in keys:
		var arrays:Array=b.build(key,128);parents.append({"id":str(Vector3i(key.x,key.y,0)),"origin":Vector3(key.x*256,0,key.y*256),"span":256.0,"resolution":128,"arrays":arrays,"extension_normalization":true,"ground_faces":Collision.surface_faces(arrays,128)})
	var began:int=Time.get_ticks_usec();var whole:Dictionary=work.portal(bundle,entrance.columns,parents);check(whole.valid,"Original full surface extraction completes");var full_seconds:float=(Time.get_ticks_usec()-began)/1000000.0;print("PORTAL_BATCH_REFERENCE cells=",whole.get("cells",[]).size()," seconds=",full_seconds);var batch=Batch.new();check(batch.configure(1,0,{"columns":entrance.columns,"snapshot":{"records":parents}}),"Actual mask split into bounded complete groups");began=Time.get_ticks_usec()
	while batch.pending():
		var task:Dictionary=batch.take();var part:Dictionary=work.portal(bundle,entrance.columns,parents,task.columns,task.part==0);check(batch.accept(1,0,task.part,part),"Actual owned column group accepted");print("PORTAL_BATCH_PART ",task.part," cells=",part.get("cells",[]).size());await process_frame
	var assembled:Dictionary=batch.assemble();check(assembled.valid,"Only all complete actual groups produce a ready surface result");var reference:Dictionary={}
	for cell:Dictionary in whole.cells:reference[cell.key]=cell
	check(assembled.cells.size()==reference.size(),"Identical complete cell set,including empty cells")
	for cell:Dictionary in assembled.cells:check(reference.has(cell.key) and var_to_bytes(cell)==var_to_bytes(reference[cell.key]),"Every position,normal,color,semantic payload,atlas byte and collision face identical")
	check(var_to_bytes(assembled.ground)==var_to_bytes(whole.ground),"Original-parent ground subtraction remains byte-identical")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual batch source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_portal_batch_equivalence.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"columns":entrance.columns.size(),"parent_snapshots":parents.size(),"cells":whole.cells.size(),"groups":batch.groups.size(),"reference_seconds":full_seconds,"serial_group_seconds":(Time.get_ticks_usec()-began)/1000000.0,"scope":"Original actual Spore seed73921/cell(9,-3),complete3x3connected field,16 original columns and real128-resolution parent arrays. Full single-job surface result versus same full field split into4owned-column groups:all complete per-cell arrays,payload atlas bytes,collision faces and full original-ground subtraction exact. Serial correctness comparison,not parallel timing or live worker-cap evidence."},"  "));print("CAVE_PORTAL_BATCH_EQUIVALENCE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
