extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Blueprint=preload("res://scripts/blobs/blob_blueprint.gd")
const Cache=preload("res://scripts/blobs/blob_mesh_cache.gd")
const OUTPUT="res://.godot/blob_validation_v4_release"
func _initialize()->void:call_deferred("run")
static func settings(i:int)->Dictionary:
	if i==0:return {"profile":"swollen","body_plan":"compact"}
	if i==1:return {"profile":"tendril","body_plan":"flattened"}
	if i==2:return {"profile":"muscular","body_plan":"muscular"}
	if i==3:return {"profile":"membranous","body_plan":"lopsided"}
	if i==4:return {"profile":"sensory","body_plan":"tower"}
	if i==5:return {"profile":"mimic","body_plan":"tower"}
	return {"profile":Blueprint.PROFILES[i%12],"body_plan":Blueprint.PLANS[i%10]}
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUTPUT);var rows:Array=[];var failures:Array=[]
	for i in 24:
		var started:=Time.get_ticks_msec();var path:String=OUTPUT.path_join("model_%02d.bin"%i);var data:Dictionary
		if "--reuse" in OS.get_cmdline_user_args() and FileAccess.file_exists(path):
			var file:=FileAccess.open(path,FileAccess.READ);data=file.get_var(false);file.close()
		else:
			data=Pipeline.new().build(5100+i,0,["roll","vine","limb","auto","auto","auto"][i] if i<6 else "auto",7,null,settings(i))
		if data.has("error"):
			failures.append({"seed":5100+i,"failure":data});print("BUILD_FAILED ",data);continue
		var omitted:Array=[]
		for f:Dictionary in data.features:
			if f.get("omitted",false):omitted.append({"id":f.id,"type":f.feature_type,"reason":f.get("omission_reason","")})
		var row:Dictionary={"seed":data.dna.seed,"generation_ms":Time.get_ticks_msec()-started,"triangles":data.statistics.triangles,"vertices":data.statistics.vertices,"profile":data.dna.profile,"plan":data.dna.body_plan,"mode":data.dna.locomotion,"roll_safe":data.rig.roll_safe,"omitted_features":omitted,"body_integrity":data.mesh_integrity,"packed_bytes":data.statistics.packed_bytes}
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(data);file.close();rows.append(row);print("V4_BATCH ",i+1,"/24 ",row)
	if failures.is_empty():
		var marker:=FileAccess.open(OUTPUT.path_join("batch.complete"),FileAccess.WRITE);marker.store_string(Cache.key(5100,0,"roll",7,settings(0)));marker.close()
	var file:=FileAccess.open("res://data/blobs_v4/generation_validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"models":rows,"failures":failures},"\t"));file.close()
	print("V4_BATCH_COMPLETE failures=",failures.size());quit(0 if failures.is_empty() else 1)
