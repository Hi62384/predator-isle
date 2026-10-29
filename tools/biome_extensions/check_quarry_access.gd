extends "res://tools/biome_extensions/check_all.gd"
func mesh_height(b,p:Vector2,step:float,cache:Dictionary)->float:
	var cell:=Vector2i(floori(p.x/step),floori(p.y/step));var f:Vector2=p/step-Vector2(cell);var h:Array[float]=[]
	for offset:Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
		var key:Vector2i=cell+offset
		if not cache.has(key):cache[key]=b._get_height(key.x*step,key.y*step)
		h.append(cache[key])
	# Same top-left / bottom-right diagonal as terrain_mesh_builder's indices.
	return h[0]*(1-f.x-f.y)+h[1]*f.x+h[2]*f.y if f.x+f.y<=1 else h[1]*(1-f.y)+h[2]*(1-f.x)+h[3]*(f.x+f.y-1)
func run()->void:
	var b=make_builder(0);var sampler=b._extras[0];var records:Array=[]
	for z in range(-16,17):
		for x in range(-16,17):
			var d:Dictionary=sampler.descriptor(Vector2i(x,z),3200*sampler.settings.feature_scale)
			if d.kind%2!=0 or d.chance>sampler.settings.excavation_frequency:continue
			var radius:float=d.radius;var plan:Dictionary=sampler.ramp_plan(d)
			if plan.is_empty():continue
			var turns:int=plan.turns;var width:float=plan.half_width*2
			if b._island_mask(d.position.x,d.position.y)<.08:continue
			var points:Array[Vector3]=[];var max_grade:float=0;var max_step:float=0;var worst:Dictionary={}
			var mesh_caches:Array=[{},{}];var previous_mesh:Array[float]=[];var mesh_grades:Array[float]=[0,0]
			for i in range(turns*512+1):
				var t:float=float(i)/(turns*512);var angle:float=fposmod(t*turns,1)*TAU-PI
				var multiplier:float=1+.08*sin(angle*3+d.angle)+.05*sin(angle*7+.4)
				# r is measured in stretched local coordinates, while the original
				# ramp parameter is their unstretched angle. Solve its exact locus.
				var direction:=Vector2(cos(angle),sin(angle));var stretch:float=Vector2(direction.x,direction.y*1.25).length()
				var local:Vector2=direction*(.22+1.08*t)*radius*multiplier/stretch
				var p:Vector2=d.position+local.rotated(d.angle)
				var h:float=b._get_height(p.x,p.y);var point:=Vector3(p.x,h,p.y)
				var mesh_heights:Array[float]=[]
				for mesh_id in range(2):mesh_heights.append(mesh_height(b,p,[2.0,4.0][mesh_id],mesh_caches[mesh_id]))
				if not points.is_empty():
					var previous:Vector3=points[-1];var distance:float=Vector2(point.x-previous.x,point.z-previous.z).length()
					var grade:float=absf(point.y-previous.y)/maxf(distance,.001)
					if grade>max_grade:worst={"t":t,"point":point,"raw_height":sampler.evaluate(p,floori(sampler.region(p)))[0],"owner":sampler.nearby(p,3200*sampler.settings.feature_scale).id}
					max_grade=maxf(max_grade,grade);max_step=maxf(max_step,absf(point.y-previous.y))
					for mesh_id in range(2):mesh_grades[mesh_id]=maxf(mesh_grades[mesh_id],absf(mesh_heights[mesh_id]-previous_mesh[mesh_id])/maxf(distance,.001))
				previous_mesh=mesh_heights
				points.append(point)
			records.append({"id":d.id,"position":d.position,"turns":turns,"width":width,"max_canonical_grade":max_grade,"max_2m_mesh_grade":mesh_grades[0],"max_4m_mesh_grade":mesh_grades[1],"configured_grade":sampler.settings.ramp_grade,"max_adjacent_height":max_step,"worst":worst})
			check(max_grade<=sampler.settings.ramp_grade+.01,"Actual canonical quarry ramp grade "+d.id+": "+str(max_grade))
			for grade:float in mesh_grades:check(grade<=sampler.settings.ramp_grade+.01,"Actual triangular mesh quarry grade "+d.id+": "+str(grade))
			if records.size()>=8:break
		if records.size()>=8:break
	check(records.size()>=4,"Multiple real dry ramp descriptors")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_quarry_access.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"seed":73921,"cases":records,"scope":"Canonical and exact 2/4 m grid triangle-interpolated centreline grades; not capsule or mixed-owner certification"},"\t"))
	print("QUARRY_ACCESS ",records," ",failures);quit(0 if failures.is_empty() else 1)
