extends "res://tools/biome_extensions/check_all.gd"
const Spatial=preload("res://tools/biome_extensions/structure_collision_spatial_candidate.gd")
const Bounded=preload("res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/biome_extensions/structure_collision_spatial_candidate.gd","res://tools/biome_extensions/structure_collision_blocks_candidate.gd","res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd","res://tools/biome_extensions/check_structure_collision_spatial.gd"]:guards[path]=FileAccess.get_sha256(path)
	var faces:=PackedVector3Array()
	for z in range(-4,5):
		for x in range(-4,5):
			for i in range(67):
				var a:=Vector3(x*1000+i,0,z*1000);faces.append_array(PackedVector3Array([a,a+Vector3(0,0,3),a+Vector3(3,0,0)]))
	faces.append_array(PackedVector3Array([Vector3(-60000,12,-60000),Vector3(60000,12,-60000),Vector3(0,12,60000)]));faces.append_array(PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]))
	var metadata:Dictionary=Spatial.build(faces);var bounds:PackedVector3Array=Bounded.build(faces);var cases:Array=[]
	check(not metadata.is_empty() and metadata.overflow.size()>0,"Actual overflow path exercised without unbounded bucket expansion")
	for point:Vector3 in [Vector3.ZERO,Vector3(-.01,0,-.01),Vector3(255.99,0,255.99),Vector3(256,0,256),Vector3(-256,0,-256),Vector3(256,-256,0),Vector3(12000,100,12000)]:
		var reference:Dictionary=Bounded.select(faces,bounds,point);var selected:Dictionary=Spatial.select(faces,metadata,point);check(not selected.fallback and selected.faces==reference.faces,"Exact accepted bounds-preserving face bytes/order,not approximate spatial selection")
		cases.append({"point":str(point),"triangles":selected.faces.size()/3,"merged_ranges":selected.ranges.size()/2})
	check(metadata.references<=metadata.bounds.size()/2*64,"At most64bucket references per block;large boxes use fixed overflow list")
	for invalid:Dictionary in [{},{"version":2}, {"version":1,"faces_count":0}]:check(Spatial.select(faces,invalid,Vector3.ZERO).faces==faces,"Missing/unknown/stale spatial index fails open")
	check(Spatial.select(faces,metadata,Vector3.INF).faces==faces and Spatial.select(faces,metadata,Vector3.ONE*1e20).faces==faces,"Nonfinite/unrepresentable queries fail open before integer conversion")
	var malformed:Dictionary=metadata.duplicate(true);malformed.extrema=PackedInt32Array([-1,-1,-1,-1,-1,-1]);check(Spatial.select(faces,malformed,Vector3.ZERO).faces==faces,"Invalid retained-bound references fail open")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private spatial index source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_structure_collision_spatial.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"metadata_numeric_bytes":Spatial.numeric_bytes(metadata),"bucket_count":metadata.bins.size(),"bucket_references":metadata.references,"overflow_blocks":metadata.overflow.size(),"production_registration":false,"scope":"PRIVATE bounded1024m2buckets over64-triangle bounds,exact accepted bounds-preserving subset bytes/order including original extrema,256m3cell+600m protection unchanged. Huge spanning block uses bounded overflow;≤64references/block. Negative/boundary/empty/stale/unknown/unrepresentable metadata/query controls fail open. Numeric metadata bytes exclude Dictionary/object overhead. Internal worker-produced immutable metadata is trusted after build;not an adversarial file parser or production integration/performance/native-motion claim."},"  "))
	print("SPATIAL_COLLISION_CANDIDATE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
