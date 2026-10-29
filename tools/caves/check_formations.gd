extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/field.gd")
const Forms=preload("res://scripts/caves/formations.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/field.gd","res://scripts/caves/formations.gd","res://tools/caves/check_formations.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 150
	var field=Field.new();var region:Dictionary={"valid":true,"nodes":[{"point":Vector3(32,0,32),"level":0,"chamber_radius":26.0,"chamber_height":24.0},{"point":Vector3(-32,0,-32),"level":0,"chamber_radius":26.0,"chamber_height":24.0}],"edges":[{"points":PackedVector3Array([Vector3(-64,0,-32),Vector3(0,0,-32),Vector3(32,0,32),Vector3(64,0,32)]),"half_width":4.0,"headroom":8.0,"entrance":false}]};check(field.compile([region],height),"Complete positive/negative chamber and protected access fixture")
	var forms=Forms.new();var total:int=0;var triangles:int=0;var kinds:Dictionary={};var roots:Dictionary={};var cases:Array=[]
	check(field.kinds.count(2)==2 and field.sample(Vector3(20,2,27))<0,"Positive fixture contains genuine chamber volume,not only its narrow access routes")
	for seed_id:int in [73921,17,92881]:
		for key:Vector3i in [Vector3i.ZERO,Vector3i(-1,0,-1),Vector3i(0,-1,0),Vector3i(-1,-1,-1)]:
			var data:Dictionary=forms.build(field,key,seed_id,0);var original:PackedByteArray=var_to_bytes(data);check(original==var_to_bytes(forms.build(field,key,seed_id,0)),"Cold/repeated complete formations deterministic")
			for placement:Dictionary in data.placements:
				var root_key:String=str(seed_id)+str(placement.root);check(not roots.has(root_key),"One half-open root owner,including negative/Y boundary chunks");roots[root_key]=true;var tip:float=placement.root.y+placement.up*placement.height;check(not forms.protected(field,placement.root,placement.radius,minf(placement.root.y,tip),maxf(placement.root.y,tip)),"Complete formation radius/vertical span excludes protected route");check(absf(field.sample(placement.root))<.001,"Form anchored to actual implicit rock/air boundary");kinds[placement.kind]=true;total+=1
			if not data.arrays.is_empty():
				var positions:PackedVector3Array=data.arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=data.arrays[Mesh.ARRAY_NORMAL];triangles+=positions.size()/3
				for i in range(0,positions.size(),3):
					var n:Vector3=(positions[i+2]-positions[i]).cross(positions[i+1]-positions[i]).normalized();check(n.is_finite() and n.length_squared()>.99 and n.dot(normals[i])>.999,"Nondegenerate actual clockwise geometry and matching normals")
			cases.append({"seed":seed_id,"key":str(key),"forms":data.placements.size(),"statistics":data.get("statistics",{})})
	check(total>=6 and kinds.has("stalactite") and kinds.has("stalagmite"),"Positive varied actual stalactites/stalagmites,not registry-only placeholders")
	check(forms.build(field,Vector3i.ZERO,73921,0,0).arrays.is_empty(),"Independent zero density adds no geometry")
	check(forms.build(field,Vector3i.ZERO,73921,1).arrays.is_empty(),"Insoluble rock style does not receive universal calcite growth")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable geological formation source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_formations.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"forms":total,"triangles":triangles,"cases":cases,"scope":"Deterministic actual boundary-rooted calcite mesh generation,positive/negative coordinate half-open ownership,all complete formation extents outside protected graph volumes,valid geometry/normals,soluble geology and zero-density controls. Actual worker integration/render/traversal tested separately."},"  "));print("CAVE_FORMATIONS ",checks," forms=",total," triangles=",triangles," failures=",failures);quit(0 if failures.is_empty() else 1)
