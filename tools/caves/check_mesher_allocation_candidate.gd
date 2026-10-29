extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
const Production=preload("res://scripts/caves/mesher.gd")
class NumericField:
	extends RefCounted
	func normal(p:Vector3)->Vector3:return -Vector3(.2+sin(p.x)*.1,1,.3).normalized()
	func surface_height(_p:Vector2)->float:return 1000000000.0
	var surface_columns:Dictionary={}
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://scripts/terrain_mesh_builder.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var source:String=FileAccess.get_file_as_string("res://scripts/caves/mesher.gd");var table:Array=[]
	for mask in range(16):
		var inside:Array=[];var outside:Array=[];var edges:Array=[]
		for i in range(4):
			if mask&(1<<i):inside.append(i)
			else:outside.append(i)
		if mask!=0 and mask!=15:
			if inside.size()==1 or outside.size()==1:
				var single:int=inside[0] if inside.size()==1 else outside[0];var others:Array=outside if inside.size()==1 else inside
				for other:int in others:edges.append(single);edges.append(other)
			else:
				for pair:Array in [[inside[0],outside[0]],[inside[0],outside[1]],[inside[1],outside[1]],[inside[1],outside[0]]]:edges.append_array(pair)
		table.append(edges)
	var first:int=source.find("func tetra(");var last:int=source.find("func build(",first);check(first>0 and last>first,"Identify complete original tetra extractor without editing production")
	var tetra:String="func tetra(points:PackedVector3Array,values:PackedFloat32Array,indices:Array)->void:\n\tvar mask:int=0\n\tif values[indices[0]]<0:mask|=1\n\tif values[indices[1]]<0:mask|=2\n\tif values[indices[2]]<0:mask|=4\n\tif values[indices[3]]<0:mask|=8\n\tif mask==0 or mask==15:return\n\tvar p:Vector3=points[indices[0]];var a:Vector3=points[indices[1]]-p;var b:Vector3=points[indices[2]]-p;var c:Vector3=points[indices[3]]-p;var reflected:bool=a.dot(b.cross(c))<0\n\tcase_flip=bool(CASE_FLIP[mask])!=reflected\n\tvar edges:Array=CUT_EDGES[mask];var cuts:=PackedVector3Array()\n\tfor i in range(0,edges.size(),2):\n\t\tvar left:int=indices[edges[i]];var right:int=indices[edges[i+1]];cuts.append(crossing(points[left],points[right],values[left],values[right]))\n\temit(cuts[0],cuts[1],cuts[2])\n\tif cuts.size()==4:emit(cuts[0],cuts[2],cuts[3])\n"
	var replacement:String=source.left(first)+tetra+source.substr(last);replacement=replacement.replace("const TETS=","const CUT_EDGES="+var_to_str(table)+"\nconst TETS=")
	# Keep both NaN-aware predicates and all original comparison operators.
	var loop:String="\t\t\t\tvar base:int=x+row*y+plane*z;var any_air:bool=false;var any_rock:bool=false\n\t\t\t\tfor offset:int in offsets:\n\t\t\t\t\tany_air=any_air or values[base+offset]<0;any_rock=any_rock or values[base+offset]>=0\n\t\t\t\t\tif any_air and any_rock:break"
	var air:Array[String]=[];var rock:Array[String]=[]
	for offset:String in ["0","1","1+row","row","plane","1+plane","1+row+plane","row+plane"]:air.append("values[base+"+offset+"]<0");rock.append("values[base+"+offset+"]>=0")
	check(replacement.contains(loop),"Identify temporary per-cube offset loop exactly");replacement=replacement.replace(loop,"\t\t\t\tvar base:int=x+row*y+plane*z;var any_air:bool="+" or ".join(air)+";var any_rock:bool="+" or ".join(rock))
	var candidate:=GDScript.new();candidate.source_code=replacement;check(candidate.reload()==OK,"PRIVATE allocation-free case-table extractor compiles")
	var numeric:=NumericField.new();var local_checks:int=0
	for base:Vector3 in [Vector3.ZERO,Vector3(20000,-200,20000),Vector3(-20000,-200,-20000),Vector3(10000000,-200,-10000000)]:
		for angle:float in [0,.43,1.7]:
			for reflected:float in [1,-1]:
				var points:=PackedVector3Array([base,base+Vector3(2,0,0).rotated(Vector3.UP,angle),base+Vector3(0,2,0),base+Vector3(0,0,2*reflected).rotated(Vector3.UP,angle)])
				for mask in range(16):
					var values:=PackedFloat32Array()
					for i in range(4):values.append((-1.0 if mask&(1<<i) else 1.0)*(.5+i*.31))
					var original=Production.new();var other=candidate.new();original.field=numeric;other.field=numeric;original.origin=base;other.origin=base;original.tetra(points,values,[0,1,2,3]);other.tetra(points,values,[0,1,2,3]);check(var_to_bytes([original.vertices,original.normals,original.colors])==var_to_bytes([other.vertices,other.normals,other.colors]),"All16sign cases preserve exact crossing/case parity/normals at signed/far/rotated/reflected coordinates");local_checks+=1
	# The actual PortalMesher filter is retained verbatim around the private
	# numeric extractor; no world samples, winding, normals or cells skipped.
	var portal:String=FileAccess.get_file_as_string("res://scripts/caves/portal_mesher.gd");candidate=GDScript.new();candidate.source_code=replacement.replace("func emit(","func raw_emit(")+portal.substr(portal.find("func emit(")).replace("super.emit(a,b,c)","raw_emit(a,b,c)");check(candidate.reload()==OK,"Actual portal clipping surrounds PRIVATE candidate unchanged")
	var work_source:String=FileAccess.get_file_as_string("res://scripts/caves/workload.gd").replace("const Mesher=preload(\"res://scripts/caves/portal_mesher.gd\")","var Mesher");var private_work:=GDScript.new();private_work.source_code=work_source;check(private_work.reload()==OK,"PRIVATE worker injects numeric candidate only")
	var config=Config.new();config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=make_builder(5,73921);var work=Workload.new();var alternate=private_work.new();alternate.Mesher=candidate;check(work.configure(b.settings,config,73921,0) and alternate.configure(b.settings,config,73921,0),"Identical original normal Crystal workers");var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(6,-2));var baseline:Dictionary={};var rows:Array=[]
		for item:Dictionary in [{"name":"production","work":work},{"name":"private_case_table","work":alternate},{"name":"production_return","work":work}]:
			var current=item.work;current.bundle_key=Vector2i(2147483647,2147483647);var valid:bool=current.use_bundle(bundle);current._water_cache.clear();var began:int=Time.get_ticks_usec();var exact:bool=true;var vertices:int=0
			for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
				var data:Dictionary=current.build_cell(key);var bytes:PackedByteArray=var_to_bytes(data)
				if item.name=="production":baseline[key]=bytes
				else:exact=exact and bytes==baseline[key]
				if not data.arrays.is_empty():vertices+=data.arrays[Mesh.ARRAY_VERTEX].size()
			rows.append({"mode":item.name,"valid":valid,"complete_payload_exact":exact,"base_vertices":vertices,"single_order_nonisolated_seconds":(Time.get_ticks_usec()-began)/1000000.0})
		output.append(rows)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var rows:Array=output[0] if not output.is_empty() else [];check(rows.size()==3,"All current/private/current-return cases complete")
	for row:Dictionary in rows:check(row.valid and row.complete_payload_exact and row.base_vertices>0,"COMPLETE actual three-cell payload/collision/normal/UV/feature/water/frontier/LOD equality "+row.mode)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Production sources unchanged during private extractor study "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_mesher_allocation_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"private_mesher_sha256":candidate.source_code.sha256_text(),"case_table":table,"local_case_count":local_checks,"rows":rows,"scope":"PRIVATE per-tetra inside/outside/pair-array elimination with exact original edge/crossing/emit order,original dynamic determinant parity retained. Per-cube loop flattened with both unchanged NaN-aware predicates.384signed/far/rotated/reflected sign cases plus complete actual original three-cell production/private/production-return payload comparisons. Single-order nonisolated timings,not FPS/live acceptance. No production adoption by this study."},"  "));print("MESHER_ALLOCATION_CANDIDATE ",checks," ",rows," failures=",failures);quit(0 if failures.is_empty() else 1)
