extends RefCounted
## Private graded-deposit study,not registered production terrain. Build from
## the exact current sampler so zero mode can be compared against that source.
static func replace_once(source:String,before:String,after:String)->String:
	assert(source.count(before)==1,"Fan gradient private source contract changed");return source.replace(before,after)
static func source_for(source:String)->String:
	var code:String=replace_once(source,"extends RefCounted","extends RefCounted\nvar fan_gradient:float=.025")
	code=replace_once(code,"var drainage:float=main;var second:float=0;var fan:float=0;var remnant:float=0","var drainage:float=main;var second:float=0;var fan:float=0;var remnant:float=0\n\tvar fan_deposit_sum:float=0;var fan_deposit_weight:float=0")
	var marker:String="fan=maxf(fan,fan_mask*settings.fans*(w[14]+w[8]*.6+w[9]*.3))"
	var extra:String="if fan_gradient>0 and settings.fan_shape_strength>0:\n\t\t\tvar contribution:float=fan_mask*settings.fans*(w[14]+w[8]*.6+w[9]*.3)*clampf(settings.fan_shape_strength,0,1)\n\t\t\tif contribution>0:\n\t\t\t\tvar basis:PackedFloat64Array=preload(\"res://scripts/badlands_fan_geometry.gd\").frame(tree)\n\t\t\t\tif not basis.is_empty():\n\t\t\t\t\tvar upstream:float=clampf((p-Vector2(basis[0],basis[1])).dot(Vector2(basis[2],basis[3])),0,minf(fan_span,maxf(32,basis[4]*.85)))\n\t\t\t\t\tfan_deposit_sum+=contribution*upstream*fan_gradient;fan_deposit_weight+=contribution\n\t\t"+marker
	code=replace_once(code,marker,extra)
	code=replace_once(code,"h=lerpf(h,28+weather,fan*.6*(1-floor_protection*clampf(settings.fan_shape_strength,0,1)))","h=lerpf(h,28+weather+(fan_deposit_sum/fan_deposit_weight if fan_deposit_weight>0 else 0),fan*.6*(1-floor_protection*clampf(settings.fan_shape_strength,0,1)))")
	return code
static func builder(seed_id:int,slope:float):
	var original:String=FileAccess.get_file_as_string("res://scripts/badlands_sampler.gd");var script:=GDScript.new();script.source_code=source_for(original);assert(script.reload()==OK)
	var b=preload("res://tools/badlands/check_fan_geometry.gd").builder(seed_id);var field=script.new();field.fan_gradient=slope;field.configure(b.settings.badlands,seed_id,b);b._badlands=field;return b
