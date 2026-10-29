extends RefCounted
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Growth = preload("res://alien_foundry/scripts/anatomy/TissueGrowth.gd")
func generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var g:=Graph.new(); g.initialize("Slitherer",seed_value,options)
	var density:=float(g.settings["growth_density"])
	var irr:=float(g.settings["irregularity"])
	var thick:=g.randf_range(0.34,0.65)
	var length:=g.randf_range(3.4,6.6)
	var posture:=g.randf_range(0.0,1.0)
	var rise:=lerpf(thick*1.2,2.85,posture)
	var amplitude:=g.randf_range(0.50,1.05)*lerpf(0.75,1.25,irr)
	var curls:=g.randf_range(0.65,1.55)
	var swelling_a:=g.randf_range(0.17,0.45)
	var swelling_b:=g.randf_range(0.52,0.79)
	var swelling_power:=g.randf_range(0.12,0.44)
	var steps:=g.rng.randi_range(14,18)
	var head_pos:=Vector3(0,rise,-length*0.35)
	var head:=g.mass("","head",head_pos,Vector3(thick*0.76,thick*0.96,thick*0.73),"flesh")
	var points:Array=[]; var radii:Array=[]
	for i in range(steps):
		var t:=float(i)/float(steps-1)
		var x:=sin(t*TAU*curls)*amplitude*sin(minf(t*PI*1.8,PI*0.8))
		var y:=thick*0.67+(rise-thick*0.67)*pow(1.0-t,1.8)
		var z:=head_pos.z+length*t
		points.append(Vector3(x,y,z))
		var swelling:=exp(-pow((t-swelling_a)/0.17,2.0))*swelling_power+exp(-pow((t-swelling_b)/0.13,2.0))*swelling_power*0.72
		radii.append(maxf(0.035,thick*(0.73+swelling)*(1.0-pow(t,3.0)*0.94)))
	var body:=g.curve(head,"body_chain",points,radii,"flesh")
	g.node(body)["blend"]=thick*0.23
	g.node(body)["shape"]={"swelling":0.025,"twist":irr*0.08,"taper":0.0,"width":1.12,"depth":0.88,"width_profile":[0.95,1.08,1.0,1.12,1.0],"depth_profile":[1.0,0.94,1.06,0.92,1.0]}
	g.face(head,false,Vector3(0,0.04,-1).normalized())
	var limbs:Array=[]
	# Fine facial/neck tendrils hang with gravity; no cartoon radial crown.
	var count:=int(round(float(g.settings["appendage_density"])*g.randf_range(4.0,10.0)))
	for i in range(count):
		var phase:=float(i)*TAU/float(count)
		var side:=sin(phase)
		var start:=head_pos+Vector3(side*thick*0.48,-thick*0.25,cos(phase)*thick*0.35)
		var reach:=g.randf_range(0.65,1.35)
		var path:=[start,start+Vector3(side*reach*0.31,-reach*0.3,0.16),start+Vector3(side*reach*0.47,-reach*0.72,0.30),start+Vector3(side*reach*0.31,-reach,0.10)]
		var limb:=g.curve(head,"tendril",path,[0.085,0.062,0.042,0.025],"root")
		limbs.append(limb)
	# Longitudinal tendon sheaths follow the full S-curve and remain anchored.
	g.fiber_bundle(body,4+int(float(g.settings["surface_detail"])*6),0.027,"muscle")
	for limb in limbs: g.fiber_bundle(str(limb),1,0.021,"root")
	g.surface_fibers(head,2,"muscle",0.025)
	for i in range(2,steps-3,3):
		var c:=Graph.vec(points[i]); var r:=float(radii[i])
		var lobe:=g.mass(body,"segment",c+Vector3(0,r*0.12,0),Vector3(r*0.70,r*0.62,r*0.94),"membrane",false)
		if density>0.55: g.surface_fibers(lobe,2,"root",0.025)
	if float(g.settings["uncanny_features"])>0.72:
		var c:=Graph.vec(points[3]); var r:=float(radii[3])
		var second:=g.mass(body,"head",c+Vector3(r*0.55,0,-r*0.1),Vector3(r*0.65,r*0.8,r*0.61),"flesh")
		g.face(second,false,Vector3(0.55,0.06,-1).normalized())
	Growth.clusters(g,[body],density*0.65,Vector3.UP)
	g.dna["metadata"]["body_plan"]="variable-rise serpentine body / unequal visceral swellings / continuous tapered axial tissue"
	g.dna["metadata"]["realized_anatomy"]={"length":length,"thickness":thick,"rise":rise,"posture":posture,"curl_count":curls,"amplitude":amplitude,"swelling_centers":[swelling_a,swelling_b],"swelling_power":swelling_power}
	return g.finish()
