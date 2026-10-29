extends RefCounted
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Growth = preload("res://alien_foundry/scripts/anatomy/TissueGrowth.gd")
func generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var g:=Graph.new(); g.initialize("Abomination",seed_value,options)
	var density:=float(g.settings["growth_density"])
	var uncanny:=float(g.settings["uncanny_features"])
	var irregularity:=float(g.settings["irregularity"])
	var verticality:=g.randf_range(0.08,0.95)
	var spread:=g.randf_range(0.75,1.45)
	var root:=g.mass("","core",Vector3(0,0.70,0),Vector3(g.randf_range(0.72,1.02),0.65,g.randf_range(0.64,0.92)),"flesh")
	g.node(root)["blend"]=0.14
	var hosts:Array=[root]; var trunks:Array=[]; var directions:Array=[]
	var count:=3+int(density*4)+g.rng.randi_range(0,2)
	var principal:=g.randf_range(-PI,PI)
	# A loosely constrained recursive volume graph spans crawling, side-heavy and
	# rising forms. Faces are optional insertions, not the topology of every branch.
	for i in range(count):
		var parent:=root if i<3 else str(hosts[g.rng.randi_range(0,mini(2,hosts.size()-1))])
		var host_size:=Graph.vec(g.node(parent)["size"])
		var angle:=principal+float(i)*2.39996+g.randf_range(-0.45,0.45)*irregularity
		var direction:=Vector3(cos(angle)*spread,g.randf_range(0.28,0.65)+verticality*1.05,sin(angle)*spread*0.72).normalized()
		var start:=g.center(parent)+direction*Graph.surface_radius(host_size,direction)*0.49
		var reach:=g.randf_range(0.62,1.40)*(0.78+verticality*0.40)
		var end:=start+direction*reach
		var width:=g.randf_range(0.23,0.43)*(1.15 if i==0 else 1.0)
		var bend:=Vector3(-sin(angle)*0.16,0.04,cos(angle)*0.12)*irregularity
		var trunk:=g.curve(parent,"trunk",[start,start.lerp(end,0.28)+bend,start.lerp(end,0.64)+bend*0.65,end],[width*1.13,width*1.22,width*0.85,width*0.70],"flesh")
		g.node(trunk)["blend"]=width*0.45
		trunks.append(trunk); directions.append(direction)
		var lobe:=g.mass(trunk,"lobe",end,Vector3(width*g.randf_range(1.0,1.40),width*g.randf_range(1.05,1.55),width*g.randf_range(0.90,1.30)),"flesh",false)
		g.node(lobe)["blend"]=width*0.36
		hosts.append(lobe)
		if i%2==0 and density>0.30: g.surface_folds(lobe,2,false,"flesh")
	var face_count:=mini(hosts.size()-1,1+int(uncanny*3.0))
	for i in range(face_count):
		var host:=str(hosts[1+(i*2)%maxi(1,hosts.size()-1)])
		g.face(host,false,Vector3(g.center(host).x*0.18,0.02,-1).normalized(),true)
	var supports:=3+int(float(g.settings["appendage_density"])*5)
	for i in range(supports):
		var angle:=principal+float(i)*TAU/float(supports)+g.randf_range(-0.19,0.19)
		var start:=g.center(root)+Vector3(cos(angle)*0.45,-0.16,sin(angle)*0.40)
		var end:=Vector3(start.x+cos(angle)*g.randf_range(0.55,1.0),0.09,start.z+sin(angle)*g.randf_range(0.50,0.95))
		var radius:=g.randf_range(0.13,0.23)
		var leg:=g.curve(root,"limb",[start,start.lerp(end,0.28)+Vector3(0,0.22,0),start.lerp(end,0.66)+Vector3(0,0.09,0),end],[radius*1.2,radius,radius*0.62,0.04],"flesh")
		g.node(leg)["blend"]=radius*0.45
		trunks.append(leg)
	var hooks:=int(round(float(g.settings["appendage_density"])*3))
	for i in range(hooks):
		var parent:=str(hosts[1+i%maxi(1,hosts.size()-1)])
		var direction: Vector3=directions[i%directions.size()]
		var start:=g.center(parent)
		var reach:=g.randf_range(0.65,1.20)
		var hook:=g.curve(parent,"tendril",[start,start+direction*reach*0.55+Vector3(0,0.20,0),start+direction*reach*0.82+Vector3(0,-0.20,0),start+direction*reach*0.56+Vector3(0,-0.50,0)],[0.12,0.08,0.05,0.025],"root")
		trunks.append(hook)
	if density>0.40:
		var cut:=g.cavity(root,g.center(root)+Vector3(-0.12,0.04,-0.56),Vector3(0.20,0.27,0.27))
		g.node(cut)["surface_opening"]=true; g.node(cut)["normal"]=[0,0,-1]
	Growth.clusters(g,hosts,density*1.20,Vector3.UP)
	for i in range(trunks.size()):
		if i%2==0: g.fiber_bundle(str(trunks[i]),1+int(float(g.settings["surface_detail"])*2),0.025)
	for i in range(mini(3,hosts.size())): g.surface_fibers(str(hosts[i]),2,"root",0.025)
	g.dna["metadata"]["body_plan"]="recursive asymmetric tissue colony / mixed rising and lateral trunks / irregular supporting appendages"
	g.dna["metadata"]["realized_anatomy"]={"verticality":verticality,"spread":spread,"principal_direction":principal,"body_branch_count":count,"face_count":face_count,"support_count":supports}
	return g.finish()
