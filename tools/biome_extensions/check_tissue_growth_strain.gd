extends SceneTree
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1;assert(ok,label)
func strain(u:float,v:float)->PackedFloat64Array:
	return PackedFloat64Array([u+.45*sin(v*.73)+.2*sin(u*.37),v+.18*sin(u*.51)+.08*sin(v*.83)])
func _initialize()->void:
	var minimum_det:float=INF;var maximum_rotation:float=0;var maximum_error:float=0;var epsilon:float=.0001
	for index in range(8192):
		var u:float=-4096+float(index)*1.001;var v:float=-3781+float(index)*.923
		var a:float=1+.074*cos(u*.37);var b:float=.0918*cos(u*.51);var c:float=.3285*cos(v*.73);var d:float=1+.0664*cos(v*.83)
		var px:=strain(u+epsilon,v);var mx:=strain(u-epsilon,v);var py:=strain(u,v+epsilon);var my:=strain(u,v-epsilon)
		var error:float=maxf(maxf(absf((px[0]-mx[0])/(2*epsilon)-a),absf((px[1]-mx[1])/(2*epsilon)-b)),maxf(absf((py[0]-my[0])/(2*epsilon)-c),absf((py[1]-my[1])/(2*epsilon)-d)))
		var determinant:float=a*d-b*c;var rotation:float=rad_to_deg(absf(atan2(b,a)));minimum_det=minf(minimum_det,determinant);maximum_rotation=maxf(maximum_rotation,rotation);maximum_error=maxf(maximum_error,error)
		verify(error<.0000001,"Analytic strain footprint matches independent central difference")
		verify(determinant>.83,"Growth strain never folds or reverses tissue orientation")
		verify(rotation<6,"Longitudinal strain preserves actual trunk direction within six degrees")
		var p:=strain(u,v);verify(absf(p[0]-u)<=.650001 and absf(p[1]-v)<=.260001,"Sub-metre bounded displacement,not new physical geometry")
	var guards:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_tissue_growth_strain.gd","res://tools/biome_extensions/tissue_variation_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/tissue_variation_candidate.gd")
	for expression:String in ["1.0+.074*cos(uv.x*.37)",".0918*cos(uv.x*.51)",".3285*cos(uv.y*.73)","1.0+.0664*cos(uv.y*.83)",".45*sin(uv.y*.73)+.2*sin(uv.x*.37)",".18*sin(uv.x*.51)+.08*sin(uv.y*.83)"]:verify(code.contains(expression),"Exact candidate shader formula guard")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tissue_growth_strain.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"checks":checks,"minimum_jacobian_determinant":minimum_det,"maximum_longitudinal_deflection_degrees":maximum_rotation,"maximum_central_difference_error":maximum_error,"scope":"8192 signed finite-path coordinate probes with double-precision independent central differences,nonfolding Jacobian and bounded small longitudinal deflection. Shader expression guards bind exact private formula. This is math,not GPU-derivative accuracy or native art acceptance."},"  "));print("TISSUE_GROWTH_STRAIN ",checks);quit()
