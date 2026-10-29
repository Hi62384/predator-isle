extends "res://tools/biome_extensions/check_all.gd"
const Blocks=preload("res://tools/biome_extensions/structure_collision_blocks_candidate.gd")
func oracle_overlap(a:Vector3,b:Vector3,c:Vector3,low:Vector3,high:Vector3)->bool:
	return minf(a.x,minf(b.x,c.x))<=high.x and maxf(a.x,maxf(b.x,c.x))>=low.x and minf(a.y,minf(b.y,c.y))<=high.y and maxf(a.y,maxf(b.y,c.y))>=low.y and minf(a.z,minf(b.z,c.z))<=high.z and maxf(a.z,maxf(b.z,c.z))>=low.z
func verify_query(faces:PackedVector3Array,bounds:PackedVector3Array,point:Vector3)->Dictionary:
	var selected:Dictionary=Blocks.select(faces,bounds,point);check(not selected.fallback,"Valid index is queried,not silently bypassed")
	var expected:=PackedVector3Array();var included:Dictionary={}
	for i in range(0,selected.ranges.size(),2):
		var first:int=selected.ranges[i];var last:int=selected.ranges[i+1];check(first%3==0 and last%3==0 and first>=0 and last<=faces.size(),"Whole original triangles and valid ranges")
		for index in range(first,last):expected.append(faces[index]);included[index/3]=true
	check(expected==selected.faces,"Selected faces are exact ordered original triangle subsequence")
	var origin:Vector3=Vector3(Blocks.cell(point))*Blocks.CELL_METRES;var low:Vector3=origin-Vector3.ONE*600;var high:Vector3=origin+Vector3.ONE*856;var required:int=0
	for triangle in range(faces.size()/3):
		if oracle_overlap(faces[triangle*3],faces[triangle*3+1],faces[triangle*3+2],low,high):required+=1;check(included.has(triangle),"EVERY original triangle touching the entire protected cell+600m volume is retained")
	return {"point":str(point),"cell":str(Blocks.cell(point)),"original_triangles":faces.size()/3,"selected_triangles":selected.faces.size()/3,"required_triangle_aabb_hits":required,"selected_original_blocks":selected.ranges.size()/2,"bound_bytes":bounds.size()*12}
func run()->void:
	var guards:Dictionary={};var records:Array=[]
	for path:String in ["res://tools/biome_extensions/structure_collision_blocks_candidate.gd","res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd","res://scripts/terrain_collision.gd"]:guards[path]=FileAccess.get_sha256(path)
	# Adversarial synthetic geometry:negative cells,degenerate/zero-thickness
	# floors,large crossing faces,cell boundaries,and partial final blocks.
	var faces:=PackedVector3Array()
	for z in range(-4,5):
		for x in range(-4,5):
			for i in range(67):
				var a:=Vector3(x*1000+i,0,z*1000);faces.append_array(PackedVector3Array([a,a+Vector3(0,0,3),a+Vector3(3,0,0)]))
	faces.append_array(PackedVector3Array([Vector3(-4000,12,-4000),Vector3(4000,12,-4000),Vector3(0,12,4000)]));faces.append_array(PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]));var original:PackedByteArray=faces.to_byte_array();var bounds:PackedVector3Array=Blocks.build(faces)
	for point:Vector3 in [Vector3.ZERO,Vector3(-.01,0,-.01),Vector3(255.99,0,255.99),Vector3(256,0,256),Vector3(-256,0,-256),Vector3(256,-256,0),Vector3(12000,100,12000)]:records.append(verify_query(faces,bounds,point))
	check(faces.to_byte_array()==original,"Index/query never mutates original geometry")
	check(bounds.size()*12<=24*ceili(float(faces.size())/(64*3)),"Exactly24bytes per64triangles,no per-triangle map")
	for broken:PackedVector3Array in [PackedVector3Array(),bounds.slice(0,bounds.size()-1),PackedVector3Array([Vector3(INF,0,0),Vector3.ZERO])]:check(Blocks.select(faces,broken,Vector3.ZERO).faces==faces,"Missing/malformed metadata fails open to complete original geometry")
	check(Blocks.select(faces,bounds,Vector3.INF).faces==faces,"Nonfinite query fails open")
	check(Blocks.select(PackedVector3Array(),PackedVector3Array(),Vector3.ZERO).faces.is_empty(),"Empty structure stays empty")
	var repeated:Dictionary=Blocks.select(faces,bounds,Vector3.ZERO)
	for point:Vector3 in [Vector3(.01,1,.01),Vector3(255.99,255.99,255.99)]:check(Blocks.select(faces,bounds,point).faces==repeated.faces,"Full cell coverage permits stable reuse while moving inside cell")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private index source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_structure_collision_blocks_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"production_registration":false,"scope":"PRIVATE conservative ordered collision-block index,24bytes per64triangles. Full original geometry unmodified. Independent per-triangle oracle checks EVERY intersecting triangle in a complete256m3cell plus600m preload on every side;negative/boundary/degenerate/long-crossing geometry,partial blocks,empty and invalid-metadata/query fail-open controls. Exact original ordered subsequences. Synthetic numeric proof only;actual biome geometry,CPU/memory benefit,native Jolt contacts,streamed capsule routes and production integration still required."},"  "))
	print("COLLISION_BLOCK_CANDIDATE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
