extends RefCounted
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Growth = preload("res://alien_foundry/scripts/anatomy/TissueGrowth.gd")
func generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var g:=Graph.new(); g.initialize("Beast",seed_value,options)
	var heaviness:=g.randf_range(0.0,1.0)
	var stretch:=g.randf_range(0.0,1.0)
	var posture:=g.randf_range(0.0,1.0)
	var density:=float(g.settings["growth_density"])
	var bulk:=lerpf(0.52,0.98,heaviness)*g.randf_range(0.94,1.06)
	var length:=lerpf(1.85,3.1,stretch)*(1.0+heaviness*0.12)
	var leg_height:=lerpf(1.38,0.84,heaviness)*g.randf_range(0.90,1.15)
	var body_y:=leg_height+bulk*0.45
	var pelvis:=g.mass("","pelvis",Vector3(0,body_y,length*0.31),Vector3(bulk*0.64,bulk*0.65,length*0.31),"flesh")
	var thorax:=g.mass(pelvis,"torso",Vector3(0,body_y+bulk*0.16,-length*0.19),Vector3(bulk*0.85,bulk*0.90,length*0.43),"flesh")
	var abdomen:=g.mass(pelvis,"abdomen",Vector3(0,body_y-bulk*0.12,length*0.03),Vector3(bulk*0.70,bulk*0.66,length*0.34),"flesh",false)
	g.node(abdomen)["blend"]=bulk*0.18
	g.node(thorax)["blend"]=bulk*0.17
	var limbs:Array=[]; var hosts:Array=[pelvis,thorax,abdomen]
	g.surface_folds(thorax,2+int(float(g.settings["surface_detail"])*3),true,"flesh")
	var pairs:=2+(1 if float(g.settings["appendage_density"])>0.78 else 0)
	for i in range(pairs):
		var z:=lerpf(-length*0.42,length*0.47,float(i)/maxf(float(pairs-1),1.0))
		var parent:=thorax if i==0 else pelvis
		for side in [-1.0,1.0]:
			var asym:=g.randf_range(-0.15,0.15)*float(g.settings["irregularity"])
			var start:=Vector3(side*bulk*0.60,body_y-0.07,z)
			var knee:=Vector3(side*(bulk*0.88+asym),leg_height*0.58,z+(-0.28 if i==0 else 0.34))
			var hock:=Vector3(side*(bulk*0.89+asym),leg_height*0.25,z+(0.12 if i==0 else -0.03))
			var end:=Vector3(side*(bulk*0.98+asym),0.16,z-0.23)
			var leg:=g.curve(parent,"limb",[start,start.lerp(knee,0.42),knee,hock,end],[bulk*0.35,bulk*0.37,bulk*0.20,0.075+bulk*0.06,0.055+bulk*0.04],"flesh")
			g.node(leg)["blend"]=bulk*0.14
			g.node(leg)["shape"].merge({"width":1.10,"depth":0.94},true)
			limbs.append(leg)
			var shoulder:=g.mass(leg,"muscle_fan",start+Vector3(side*0.04,-0.11,0.05),Vector3(bulk*0.32,bulk*0.47,bulk*0.34),"flesh",false)
			hosts.append(shoulder)
			g.mass(leg,"joint",knee,Vector3(bulk*0.21,bulk*0.23,bulk*0.20),"flesh",false)
			var foot:=g.mass(leg,"foot",end+Vector3(0,-0.025,-0.09),Vector3(0.19,0.13,0.24),"flesh")
			g.module("foot_digitigrade",foot,g.center(foot)+Vector3(0,0.10,-0.045),Vector3.UP,Vector3(0.40,0.31,0.22),{},"flesh",Vector3.FORWARD)
			g.digits(foot,g.center(foot)+Vector3(0,0,-0.14),Vector3.FORWARD,0.30,3,true)
	var neck_start:=g.center(thorax)+Vector3(0,bulk*0.20,-length*0.31)
	var neck_length:=g.randf_range(0.52,1.40)*(1.10-heaviness*0.24)
	var neck_end:=neck_start+Vector3(g.randf_range(-0.13,0.13)*float(g.settings["irregularity"]),-neck_length*lerpf(-0.18,0.32,posture),-neck_length*0.90)
	var neck:=g.curve(thorax,"neck",[neck_start,neck_start.lerp(neck_end,0.46)+Vector3(0,bulk*0.13,0),neck_end],[bulk*0.58,bulk*0.46,bulk*0.34],"flesh")
	limbs.append(neck)
	var head:=g.mass(neck,"head",neck_end+Vector3(0,-0.06,-0.10),Vector3(bulk*0.48,bulk*0.47,bulk*0.59),"flesh")
	g.face(head,true)
	g.paired_sensory(head)
	if float(g.settings["uncanny_features"])>0.65: g.face(thorax,false,Vector3(0.9,0.05,-0.4).normalized())
	# Dorsal ridges are actual supported crests, interleaved with pale membrane.
	var spine_count:=int(round(density*g.randf_range(3.0,8.0)))
	for i in range(spine_count):
		var t:=float(i)/maxf(float(spine_count-1),1.0)
		var z:=lerpf(-length*0.47,length*0.53,t)
		var parent:=thorax if t<0.58 else pelvis
		var c:=g.center(parent); var size:=Graph.vec(g.node(parent)["size"])
		var y:=c.y+size.y*sqrt(maxf(0.16,1.0-pow((z-c.z)/size.z,2.0)))*0.86
		var start:=Vector3(g.randf_range(-0.05,0.05),y,z)
		var height:=g.randf_range(0.22,0.48)*(1.0-t*0.28)
		g.curve(parent,"crest",[start,start+Vector3(0,height*0.65,0.06),start+Vector3(0,height,0.17)],[0.125,0.075,0.025],"bone",false)
		g.mass(parent,"membrane",start+Vector3(0,height*0.20,0.04),Vector3(0.09,height*0.60,0.20),"membrane",false)
	var tail_start:=g.center(pelvis)+Vector3(0,bulk*0.18,length*0.24)
	var tail_length:=g.randf_range(1.0,1.9)
	var tail:=g.curve(pelvis,"tail",[tail_start,tail_start+Vector3(0,0.05,tail_length*0.35),tail_start+Vector3(g.randf_range(-0.4,0.4),-0.18,tail_length*0.75),tail_start+Vector3(g.randf_range(-0.6,0.6),0.10,tail_length)],[bulk*0.23,0.14,0.075,0.025],"root")
	limbs.append(tail)
	Growth.clusters(g,hosts,density*0.85,Vector3.UP)
	# The volume itself carries muscular contours. Blanket partly buried fiber
	# meshes produced disconnected colored slivers rather than attached tissue.
	if density>0.65: g.fiber_bundle(tail,2,0.024,"root")
	g.dna["metadata"]["body_plan"]="continuous lean-to-heavy quadruped / variable spine and neck posture / load-bearing tissue envelopes"
	g.dna["metadata"]["realized_anatomy"]={"heaviness":heaviness,"bulk":bulk,"stretch":stretch,"body_length":length,"leg_height":leg_height,"posture":posture,"neck_length":neck_length,"leg_pairs":pairs}
	return g.finish()
