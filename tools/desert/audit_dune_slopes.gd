extends SceneTree
const Desert = preload("res://scripts/desert_sampler.gd")
func dh(s, x:float, z:float, family:int=-1) -> float:
	var q:Vector2=s.wind_coordinates(x,z)
	if family>=0:
		var width:float=maxf(200.0,maxf(s.settings.dune_width_range.x,s.settings.dune_width_range.y))
		if family==3:width*=1.45
		if family==4:width*=0.8
		return s._isolated_dunes(q,width,family)*s.settings.dune_frequency
	return s._dunes(q,x,z,1.0,1.0)
func grad(s,x:float,z:float,family:int=-1,delta:float=1.0)->float:
	var a:float=(dh(s,x+delta,z,family)-dh(s,x-delta,z,family))/(2.0*delta)
	var b:float=(dh(s,x,z+delta,family)-dh(s,x,z-delta,family))/(2.0*delta)
	return Vector2(a,b).length()
func search(s, center:Vector2, span:float, step:float, family:int=-1)->Dictionary:
	var worst:float=-1.0
	var at:=Vector2.ZERO
	var count:int=ceili(span/step)
	for j in range(count+1):
		for i in range(count+1):
			var p:Vector2=center+Vector2(i*step-span*0.5,j*step-span*0.5)
			var g:float=grad(s,p.x,p.y,family)
			if g>worst:worst=g;at=p
	return {"slope":worst,"degrees":rad_to_deg(atan(worst)),"x":at.x,"z":at.y,"step":step,"family_fixed":family}
func _initialize()->void:
	var start:int=Time.get_ticks_msec()
	for extreme in [false,true]:
		var config:=DesertSettings.new()
		if extreme:
			config.dune_spacing=0.5;config.dune_asymmetry=0.82;config.slip_face_sharpness=0.0;config.dune_max_height=180.0;config.dune_frequency=1.0;config.wind_variation=1.0
		var s=Desert.new();s.configure(config,73921)
		var broad:Dictionary=search(s,Vector2.ZERO,80000.0,400.0)
		print(JSON.stringify({"extreme":extreme,"phase":"coarse_composite","result":broad}))
		var refined:Dictionary=search(s,Vector2(broad.x,broad.z),800.0,8.0)
		var dense:Dictionary=search(s,Vector2(refined.x,refined.z),40.0,0.5)
		dh(s,dense.x,dense.z)
		dense["dominant_family"]=s.last_family
		print(JSON.stringify({"extreme":extreme,"phase":"dense_composite","result":dense}))
		for family in [2,3,4]:
			var iso:Dictionary=search(s,Vector2.ZERO,8000.0,40.0,family)
			var iso_dense:Dictionary=search(s,Vector2(iso.x,iso.z),120.0,1.0,family)
			print(JSON.stringify({"extreme":extreme,"phase":"dense_isolated","result":iso_dense}))
	print("elapsed_seconds=",(Time.get_ticks_msec()-start)/1000.0)
	quit()
