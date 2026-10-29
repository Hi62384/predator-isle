extends SceneTree
const Ready=preload("res://scripts/terrain_ready_cut.gd")
const Planner=preload("res://scripts/terrain_partition.gd")
var checks:int=0
func profile(resolution:int,phase:float)->Dictionary:
	var result:Dictionary={"resolution":resolution}
	for side:int in range(4):
		var top:=PackedFloat32Array();var b0:=PackedFloat32Array();var b1:=PackedFloat32Array()
		for i:int in range(resolution+1):top.append(sin(float(i)/resolution*21+phase)*5)
		for i:int in range(resolution):b0.append(top[i]-20);b1.append(top[i+1]-20)
		result[side]={"top":top,"bottom0":b0,"bottom1":b1}
	return result
func oracle(fine:Dictionary,coarse:Dictionary)->bool:
	# Independent dense evaluation of actual linearly interpolated curtains,
	# including fine/coarse interior points, rather than the selector's code.
	for sample:int in range((fine.top.size()-1)*16+1):
		var t:float=float(sample)/((fine.top.size()-1)*16)
		var fx:float=t*(fine.top.size()-1);var cx:float=t*(coarse.top.size()-1)
		var fi:int=mini(floori(fx),fine.top.size()-2);var ci:int=mini(floori(cx),coarse.top.size()-2)
		var ft:float=lerpf(fine.top[fi],fine.top[fi+1],fx-fi);var ct:float=lerpf(coarse.top[ci],coarse.top[ci+1],cx-ci)
		var fb:float=lerpf(fine.bottom0[fi],fine.bottom1[fi],fx-fi);var cb:float=lerpf(coarse.bottom0[ci],coarse.bottom1[ci],cx-ci)
		if maxf(fb,cb)>minf(ft,ct)+.0001:return false
	return true
func _initialize()->void:
	var planner=Planner.new()
	for origin:Vector2i in [Vector2i.ZERO,Vector2i(-1000,-2000)]:
		for side:int in range(4):
			var directions:Array[Vector2i]=[Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]
			var a:=Vector3i(origin.x,origin.y,0);var p:Vector2i=origin+directions[side];var b:=Vector3i(p.x,p.y,0)
			var opposite:int=[1,0,3,2][side]
			for coarse_res:int in [64,32,16,8,2]:
				var fp:Dictionary=profile(128,.2);var cp:Dictionary=profile(coarse_res,1.1)
				for broken:bool in [false,true]:
					if broken:
						fp[side].top[39]=100;fp[side].bottom0[39]=95;fp[side].bottom1[38]=95
					var expected:bool=oracle(fp[side],cp[opposite])
					assert(expected==not broken,"Oracle must exercise a positive covered edge and a valid but disjoint curtain")
					var proof:Dictionary=Ready.covered_edge(a,b,{a:128,b:coarse_res},{a:fp,b:cp},planner)
					assert(not proof.is_empty()==expected,"Dense independent curtain oracle and segment proof agree")
					checks+=1
	print("EDGE_COVERAGE_ORACLE ",checks," positive/negative cases;four directions;negative coordinates;density ratios2 to64");quit()
