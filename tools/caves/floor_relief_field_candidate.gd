extends "res://scripts/caves/portal_field.gd"
const Relief=preload("res://tools/caves/floor_relief_candidate.gd")
var relief_enabled:bool=true
var relief_strength:float=.65
func evaluate(point:Vector3,features:PackedInt32Array)->float:
	var original:float=super.evaluate(point,features)
	if not relief_enabled or relief_strength<=0 or original>=FAR:return original
	var eligible:bool=false
	for feature:int in features:
		if kinds[feature]==2 and absf(point.y-begins[feature].y)<=5:eligible=true;break
	if not eligible:return original
	var offset:float=Relief.offset(self,point,relief_strength)
	if offset<=0:return original
	var result:float=FAR
	for feature:int in features:
		var value:float=super.evaluate(point,PackedInt32Array([feature]))
		if kinds[feature]==2:value=maxf(value,begins[feature].y-point.y+offset)
		result=minf(result,value)
	return minf(FAR,result)
