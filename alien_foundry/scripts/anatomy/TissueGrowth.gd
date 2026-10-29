extends RefCounted
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
## One connected growth algorithm shared by all body plans. A seeded anatomical
## anchor gives rise to correlated children, not independent scattered spheres.
static func clusters(g: RefCounted, hosts: Array, amount: float, preferred: Vector3 = Vector3.BACK) -> void:
	if hosts.is_empty(): return
	var count := mini(int(g.dna["budget"]["growths"]),int(round(amount*3.0)))
	for cluster in range(count):
		if g.dna["nodes"].size()>int(g.dna["budget"]["nodes"])-8: break
		var parent := str(hosts[g.rng.randi_range(0,hosts.size()-1)])
		var host: Dictionary=g.node(parent)
		if host.is_empty(): continue
		var center := Graph.vec(host["position"])
		var size := Graph.vec(host["size"])
		var points: Array=host.get("points",[])
		if points.size()>2:
			var sample: int=g.rng.randi_range(1,points.size()-2)
			center=Graph.vec(points[sample])
			size=Vector3.ONE*float(host["radii"][sample])
		var side := -1.0 if g.rng.randf()<0.5 else 1.0
		var direction := (preferred*0.7+Vector3(side*g.randf_range(0.35,0.85),g.randf_range(-0.15,0.48),g.randf_range(-0.20,0.30))).normalized()
		var root := center+direction*Graph.surface_radius(size,direction)*0.55
		var radius := clampf(minf(size.x,size.y)*g.randf_range(0.35,0.57),0.07,0.32)
		var behavior: float=g.rng.randf()
		var reach: float=radius*g.randf_range(1.05,2.4)*(1.45 if behavior>0.72 else 1.0)
		var end := root+direction*reach
		var material := "flesh" if behavior<0.80 else "root"
		var id: String=g.curve(parent,"growth",[root,root.lerp(end,0.33),root.lerp(end,0.72),end],[radius*0.88,radius*1.12,radius*0.82,radius*0.30],material,false)
		g.node(id)["blend"]=radius*0.65
		g.node(id)["noise"]=0.04+float(g.settings["surface_detail"])*0.025
		g.node(id)["shape"]={"swelling":0.03,"twist":0.04,"taper":0.0}
		g.node(id)["growth_origin"]=Graph.arr(root)
		g.node(id)["growth_behavior"]="elongated" if behavior>0.72 else "swelling"
		if amount>0.50 and g.rng.randf()<0.60:
			var fork := (direction+Vector3(-side*0.45,g.randf_range(-0.3,0.4),0.15)).normalized()
			var child: String=g.curve(id,"growth",[root.lerp(end,0.47),end+fork*radius*0.45,end+fork*radius*1.25],[radius*0.67,radius*0.66,radius*0.22],material,false)
			g.node(child)["blend"]=radius*0.50
			g.node(child)["growth_origin"]=Graph.arr(root)
			g.node(child)["growth_behavior"]="correlated_branch"

static func route_free_appendage(g: RefCounted, parent: String, points: Array, radii: Array, escape: Vector3 = Vector3.BACK) -> Array:
	# Free appendages may leave their carrier but must not accidentally weld to
	# independently articulated neighbours. This changes their path, never skin
	# ownership or the supplied primary anatomy. Conservative margins include the
	# smooth union and low-resolution feature floor used by the volume extractor.
	var path: Array=points.duplicate()
	var ancestors: Dictionary={}
	var current:=parent
	while not current.is_empty() and not ancestors.has(current):
		ancestors[current]=true
		current=str(g.node(current).get("parent",""))
	var obstacles: Array=[]
	for node in g.dna["nodes"]:
		if ancestors.has(str(node["id"])) or node.get("kind","")=="cavity": continue
		if node.get("role","") in ["limb","neck","head","digit","palm","foot"]: obstacles.append(node)
	var direction:=escape.normalized()
	for index in range(1,path.size()):
		for attempt in range(6):
			var deficit:=0.0
			for step in range(1,7):
				var t:=float(step)/6.0
				if index==1 and t<0.5: continue
				var sample:=Graph.vec(path[index-1]).lerp(Graph.vec(path[index]),t)
				var radius:=lerpf(float(radii[index-1]),float(radii[index]),t)
				for obstacle in obstacles:
					var margin:=radius+float(obstacle.get("blend",0.05))*0.7+0.10
					deficit=maxf(deficit,margin-Graph.distance_to_tissue(obstacle,sample))
			if deficit<=0.0: break
			path[index]=Graph.vec(path[index])+direction*minf(0.4,deficit+0.08)
	return path
