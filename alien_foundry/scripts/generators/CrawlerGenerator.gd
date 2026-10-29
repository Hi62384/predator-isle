extends RefCounted
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Growth = preload("res://alien_foundry/scripts/anatomy/TissueGrowth.gd")
func generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var g:=Graph.new(); g.initialize("Crawler",seed_value,options)
	var elongation:=g.randf_range(0.0,1.0)
	var bulk:=g.randf_range(0.75,1.30)
	var layout:=0 if elongation<0.35 else (1 if elongation<0.65 else 2)
	var density:=float(g.settings["growth_density"])
	var uncanny:=float(g.settings["uncanny_features"])
	var segments:=2+int(round(elongation*4.0))
	var width:=lerpf(0.92,0.46,elongation)*g.randf_range(0.90,1.12)*sqrt(bulk)
	var body_y:=g.randf_range(0.68,1.25)*(1.15-elongation*0.25)
	var spacing:=g.randf_range(0.46,0.64)
	var hosts:Array=[]; var limbs:Array=[]; var previous:=""
	for i in range(segments):
		var taper:=1.0-float(i)/float(segments)*0.24
		var pos:=Vector3(g.randf_range(-0.08,0.08)*float(g.settings["irregularity"]),body_y,float(segments-1)*spacing*0.5-float(i)*spacing)
		previous=g.mass(previous,"abdomen" if i==0 else "segment",pos,Vector3(width*taper,g.randf_range(0.32,0.46)*bulk,spacing*g.randf_range(0.96,1.12)),"flesh")
		hosts.append(previous)
		g.node(previous)["blend"]=0.10+bulk*0.04
		if density>0.25: g.surface_folds(previous,1+int(density*3),true,"flesh")
		if i%2==0:
			g.mass(previous,"growth",pos+Vector3(width*0.42,0.23,0.06),Vector3(width*0.43,0.28,0.31),"membrane",false)
	var pairs:=3+int(round(float(g.settings["appendage_density"])*3.0))
	if layout==2: pairs=maxi(pairs,segments)
	var reach:=lerpf(1.85,1.12,elongation)*g.randf_range(0.87,1.13)
	for pair in range(pairs):
		var host_index:=int(round(float(pair)*float(segments-1)/maxf(1,float(pairs-1))))
		var parent:=str(hosts[host_index]); var c:=g.center(parent)
		var station:=float(pair)*float(segments-1)/maxf(1.0,float(pairs-1))
		c.z-=(station-float(host_index))*spacing*0.70
		for side in [-1.0,1.0]:
			var asym:=1.0+g.randf_range(-0.25,0.25)*float(g.settings["irregularity"])
			var reach_scale:=1.0+sin(float(pair)*1.71+float(seed_value%31))*0.13*float(g.settings["irregularity"])
			var start:=c+Vector3(side*width*0.58,-0.02,0)
			var fan:=(0.5-float(pair)/maxf(float(pairs-1),1.0))*1.8
			var joint:=c+Vector3(side*reach*0.77*asym*reach_scale,g.randf_range(0.35,0.63),fan*0.7)
			var knee:=c+Vector3(side*reach*1.05*asym*reach_scale,-body_y*0.28,fan)
			var foot:=c+Vector3(side*reach*1.3*asym*reach_scale,-body_y+0.11,fan*1.18)
			var radius:=g.randf_range(0.14,0.19)*sqrt(bulk)
			var leg:=g.curve(parent,"limb",[start,start.lerp(joint,0.42),joint,knee,foot],[radius*1.30,radius*1.10,radius*0.70,radius*0.52,0.045],"flesh")
			g.node(leg)["blend"]=radius*0.48
			g.node(leg)["shape"].merge({"width":1.08,"depth":0.90,"width_profile":[1.10,1.25,0.96,0.88,1.0],"depth_profile":[1.0,1.08,1.0,0.95,1.0]},true)
			var coxa:=g.mass(parent,"shoulder",start,Vector3(radius*1.45,radius*1.20,radius*1.35),"flesh",false)
			g.node(coxa)["blend"]=radius*0.55
			limbs.append(leg)
			g.mass(leg,"joint",joint,Vector3(radius*0.85,radius*1.02,radius*0.80),"flesh",false)
			g.curve(leg,"digit",[foot,foot+Vector3(side*0.12,-0.035,-0.12),foot+Vector3(side*0.18,-0.02,-0.29)],[0.062,0.045,0.025],"bone",true)
	var head_parent:=str(hosts[-1]); var head_pos:=g.center(head_parent)+Vector3(0,-0.18,-spacing*0.67)
	var head:=g.mass(head_parent,"head",head_pos,Vector3(width*0.54,0.36,0.34),"flesh")
	g.face(head,false,Vector3(0,-0.20,-1).normalized())
	g.aperture(str(hosts[0]),g.center(str(hosts[0]))+Vector3(-width*0.23,0.05,-spacing*0.65),Vector3(width*0.20,0.17,0.22))
	if uncanny>0.56: g.face(str(hosts[0]),false,Vector3(0.75,0.18,-0.65).normalized())
	for side in [-1.0,1.0]:
		var start:=head_pos+Vector3(side*width*0.30,-0.05,-0.15)
		var claw:=g.curve(head,"antenna",[start,start+Vector3(side*0.32,-0.20,-0.27),start+Vector3(side*0.19,-0.42,-0.51)],[0.08,0.055,0.025],"root")
		limbs.append(claw)
	Growth.clusters(g,hosts,density*0.8,Vector3.UP)
	for host in hosts: g.surface_fibers(str(host),1+int(density*2),"root",0.025)
	for limb in limbs:
		if g.node(str(limb))["role"]=="antenna": g.fiber_bundle(str(limb),1,0.022,"root")
	g.dna["metadata"]["body_plan"]=["sinewy arachnid","broad jointed crab","ribbed many-legged crawler"][layout]
	g.dna["metadata"]["supporting_limb_count"]=pairs*2
	g.dna["metadata"]["realized_anatomy"]={"elongation":elongation,"bulk":bulk,"body_width":width,"body_height":body_y,"segment_count":segments,"limb_reach":reach,"leg_pairs":pairs}
	return g.finish()
