extends RefCounted
const Previous=preload("res://tools/biome_extensions/conduit_shoulder_candidate.gd")
const SOURCE=Previous.SOURCE
const BASE=Previous.BASE
static func source_for(source:String,enabled:bool=true)->String:
	if not enabled:return source
	var code:String=Previous.source_for(source)
	var old_profile:String="if conduit_aprons and conduit_shoulders:rise=lerpf(rise*rise,pow(rise,4),smoothstep(9,15,radius))";assert(code.count(old_profile)==2)
	code=code.replace(old_profile,"if conduit_aprons and conduit_shoulders:rise*=rise")
	var row_marker:String="var left_h:float=builder._get_height(left.x,left.y);var right_h:float=builder._get_height(right.x,right.y)";assert(code.count(row_marker)==2)
	var row_code:String='''
		var shoulder_strength:float=smoothstep(9,15,radius) if conduit_aprons and conduit_shoulders else 0.0
		for site:Dictionary in _protected_sites:
			var reserve:float=maxf(320,site.half*1.2)+radius+64
			shoulder_strength*=smoothstep(reserve,reserve+128,p.distance_to(site.position))'''
	code=code.replace(row_marker,row_marker+row_code)
	var edge_marker:String="if i==0 or i==8:v.y=ground-(2 if conduit_aprons and conduit_shoulders else 3)";assert(code.count(edge_marker)==2)
	var guide_code:String='''
			if shoulder_strength>0:
				# Actual canonical ground under EACH profile point,not a chord
				# between three guide heights. The compact quartic grows from
				# that floor with almost horizontal lips and the exact old crest.
				# Outer conservative aprons/caps remain unchanged and buried.
				var floor_height:float=builder._get_height(v.x,v.z)
				var grown:float=floor_height-.02+maxf(0,radius*.35-1.98)*pow(sin(angle),4)
				v.y=lerpf(v.y,grown,shoulder_strength)'''
	code=code.replace(edge_marker,edge_marker+guide_code)
	return code.replace("private_quartic_shoulder_v1/","private_ground_union_shoulder_v1/")
static func script_for(enabled:bool=true)->GDScript:
	var script:=GDScript.new();script.source_code=source_for(FileAccess.get_file_as_string(SOURCE),enabled);assert(script.reload()==OK);return script
