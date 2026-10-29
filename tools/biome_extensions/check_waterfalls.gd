extends "res://tools/biome_extensions/check_all.gd"
const Features=preload("res://scripts/terrain_feature_meshes.gd")
func run()->void:
	var b=make_builder(1);b.settings.wise_mountains.caves_enabled=false;b.chunk_size=8192;b._configure_noise();var cases:Array=[]
	for i in range(120):
		var c:=Vector2i(i%12-6,i/12-5);var f:Dictionary=Features.new().build(b,c)
		for fall:Dictionary in f.waterfalls:
			check(fall.connected_to_carrier and fall.drop_metres==34,"Actual connected fall profile")
			var p:Vector2=fall.position;var sampler=b._extras[1];var side:float=signf(p.y-fall.outlet.y);var prev:float=-INF
			for j in range(101):
				var q:=Vector2(p.x,fall.outlet.y+side*(120+j*8));var level:float=sampler.tributary(q).x
				check(level>=prev,"Tributary rises towards its source, not uphill flow");prev=level
			cases.append(fall)
		if cases.size()>2:break
	check(not cases.is_empty(),"Actual waterfall surfaces exist")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_waterfalls.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"));print("WATERFALL_CHECKS ",checks," ",failures);quit(0 if failures.is_empty() else 1)
