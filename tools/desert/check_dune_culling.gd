extends SceneTree
class Unculled extends "res://scripts/desert_sampler.gd":
	func _near_dune_sites(q: Vector2,pitch: float,_width: float,_family: int) -> Array[Vector4]:
		return _dune_sites(Vector2i(floori(q.x/pitch),floori(q.y/pitch)))
func _initialize() -> void:
	var current=preload("res://scripts/desert_sampler.gd").new()
	var old=Unculled.new()
	var failures: Array=[]
	var count: int=0
	var timings: Array=[]
	for seed_value in [73921,12345,-12345]:
		var config:=DesertSettings.new()
		config.dune_width_range=Vector2(230,540)
		current.configure(config,seed_value);old.configure(config,seed_value)
		for family in [2,3,4]:
			var width: float=current._dune_width*(1.45 if family==3 else (0.8 if family==4 else 1.0))
			var pitch: float=width*current._dune_spacing*1.65
			for i in range(7000):
				var q:=Vector2((i*37)%1301-650,(i*83)%997-498)*0.31*pitch
				if i%3==0:q=Vector2(i%11-5,i%13-6)*pitch/8.0+Vector2(0.001,-0.001)
				var a: float=current._isolated_dunes(q,width,family)
				var b: float=old._isolated_dunes(q,width,family)
				count+=1
				if a!=b:failures.append({"q":str(q),"a":a,"b":b,"family":family})
	for sampler in [old,current]:
		var tick:=Time.get_ticks_usec();var sum: float=0.0
		for i in range(20000):sum+=sampler._isolated_dunes(Vector2(i%256,(i*7)%256),sampler._dune_width,2)
		timings.append({"us":Time.get_ticks_usec()-tick,"checksum":sum})
	var result: Dictionary={"comparisons":count,"failures":failures,"unculled_then_culled":timings,"scope":"Exact same analytic profiles, three signed seeds, all isolated families, subcell boundaries and cache eviction."}
	FileAccess.open("res://tools/desert/dune_culling_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
