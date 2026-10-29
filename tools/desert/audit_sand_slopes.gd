extends SceneTree
const Desert=preload("res://scripts/desert_sampler.gd")
func grad(s,x:float,z:float)->float:
	var a:float=(s.sample(x+1,z)-s.sample(x-1,z))*0.5
	var b:float=(s.sample(x,z+1)-s.sample(x,z-1))*0.5
	return Vector2(a,b).length()
func search(s,center:Vector2,span:float,step:float)->Dictionary:
	var worst:float=-1.0;var at:=Vector2.ZERO
	for j in range(ceili(span/step)+1):
		for i in range(ceili(span/step)+1):
			var p:Vector2=center+Vector2(i*step-span*0.5,j*step-span*0.5)
			var w:PackedFloat32Array=s.region_weights(p.x,p.y)
			if w[0]<0.999:continue
			var g:float=grad(s,p.x,p.y)
			if g>worst:worst=g;at=p
	s.sample(at.x,at.y)
	return {"slope":worst,"degrees":rad_to_deg(atan(worst)),"x":at.x,"z":at.y,"step":step,"family":s.last_family,"supply":s.control_region.w,"style":s.last_weights[7]}
func _initialize()->void:
	for extreme in [false,true]:
		var c:=DesertSettings.new()
		if extreme:c.dune_spacing=0.5;c.dune_asymmetry=0.82;c.slip_face_sharpness=0.0;c.dune_max_height=180.0;c.dune_frequency=1;c.wind_variation=1
		var s=Desert.new();s.configure(c,73921)
		var a:Dictionary=search(s,Vector2.ZERO,80000,200)
		var b:Dictionary=search(s,Vector2(a.x,a.z),800,8)
		var d:Dictionary=search(s,Vector2(b.x,b.z),40,.5)
		print(JSON.stringify({"extreme":extreme,"mode":"actual_pure_sand_terrain","result":d}))
	quit()
