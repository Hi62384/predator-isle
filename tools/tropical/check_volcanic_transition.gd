extends SceneTree
const Fixture=preload("res://tools/tropical/volcanic_transition_fixture.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var hashes:Dictionary=Fixture.sources();hashes["res://tools/tropical/check_volcanic_transition.gd"]=FileAccess.get_sha256("res://tools/tropical/check_volcanic_transition.gd")
	var records:Array=[]
	for seed_id:int in [73921,17,92881]:
		var b=Fixture.builder(seed_id);var p:Vector2=Fixture.locate(b)
		check(p.is_finite(),"Actual inland Tropical/Volcanic overlap")
		if not p.is_finite():continue
		b._biome_weights(p.x,p.y);var weights:=Vector2(b._tropical_weight,b._extra_weights[2])
		check(absf(weights.x+weights.y-1)<.00001,"Only the two requested owners are active")
		var cell:=Vector2i(floori(p.x/256),floori(p.y/256));var a:Array=b.build(cell,32);var atlas:PackedByteArray=b.built_extension_data.duplicate()
		check((b.built_extension_mask & (1<<2))!=0,"Mixed tile actually carries the Volcanic slot")
		check(b.built_extension_rows==33 and atlas.size()==33*33*8*4,"Existing eight-slot extension transport retained")
		var right:Array=b.build(cell+Vector2i.RIGHT,32)
		for z in range(33):
			var ia:int=z*33+32;var ib:int=z*33
			check(a[Mesh.ARRAY_VERTEX][ia].y==right[Mesh.ARRAY_VERTEX][ib].y,"Adjacent mixed-owner height seam")
			check(a[Mesh.ARRAY_NORMAL][ia].is_equal_approx(right[Mesh.ARRAY_NORMAL][ib]),"Adjacent mixed-owner normal seam")
			check(a[Mesh.ARRAY_TEX_UV][ia].x==right[Mesh.ARRAY_TEX_UV][ib].x,"Adjacent mixed-owner water seam")
		var maximum_owner_error:float=0
		for i in range(0,33*33,7):
			var local:Vector3=a[Mesh.ARRAY_VERTEX][i];var q:=Vector2(local.x+cell.x*256,local.z+cell.y*256)
			check(is_finite(local.y),"Finite real blended terrain")
			check(absf(local.y-b._get_height(q.x,q.y))<.001,"Mixed mesh matches canonical terrain")
			var encoded:float=a[Mesh.ARRAY_CUSTOM2][i*4]
			check(encoded<0,"Tropical packed controls retained beside extension atlas")
			var tropical_weight:float=float((int(-encoded-1)>>16)&255)/255
			maximum_owner_error=maxf(maximum_owner_error,absf(tropical_weight-b._last_tropical.x))
			var row:int=i/33;var column:int=i%33;var offset:int=(row*33*8+2*33+column)*4
			check(absf(float(atlas[offset])/255-b._extra_weights[2])<.5/255+.00001,"Volcanic ownership survives numeric transport")
		check(maximum_owner_error<.5/255+.00001,"Tropical ownership survives numeric transport")
		records.append({"seed":seed_id,"position":p,"owner_weights":weights,"maximum_tropical_transport_error":maximum_owner_error,"chunk":cell})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Source stable: "+path)
	FileAccess.open("res://tools/tropical/artifacts/check_volcanic_transition.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"records":records,"source_sha256":hashes,"scope":"Three actual inland Tropical/Volcanic overlaps: canonical mesh, numeric transport, adjacent heights/normals/water. Not artistic or exhaustive traversal acceptance."},"  "))
	print("TROPICAL_VOLCANIC_TRANSITION ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
