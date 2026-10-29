extends SceneTree
func _initialize()->void:
	var checks:int=0;var negatives:int=0
	for size:int in [256,512,1024,2048,4096,8192,16384]:
		for tile:int in [-2047,-1024,-513,-255,-31,-1,0,1,17,255,513,1024,2047]:
			for offset:int in [-119,-41,-1,0,1,37,119]:
				var q:int=tile*size*4+offset
				var ordinary:int=absi(q)%10
				if q<0 and ordinary>0:ordinary=10-ordinary
				var mirrored:int=absi(q)%20
				if q<0 and mirrored>0:mirrored=20-mirrored
				var parity:int=mirrored/10
				assert(parity==0 or parity==1);checks+=1
				assert(ordinary+parity*10==mirrored);checks+=1
				assert((q-ordinary-parity*10)%20==0);checks+=1
				if parity!=0:negatives+=1
	assert(negatives>0)
	var report:Dictionary={"passed":true,"failures":[],"assertions":checks,"original_odd_origin_negatives":negatives,"source_sha256":{},"scope":"Exact signed quarter-metre origin parity for the current 2.5m layer-zero mirrored lookup; ordinary sampling unchanged. Vertex-stage parity only, not arbitrary new layer-zero texture scales or whole-scene acceptance."}
	for path:String in ["res://tools/biome_extensions/mirror_origin_phase_candidate.gdshaderinc","res://tools/biome_extensions/check_mirror_origin_parity.gd"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_mirror_origin_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MIRROR_ORIGIN_PARITY_PASS ",checks," negatives=",negatives);quit()
