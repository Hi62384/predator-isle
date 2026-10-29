extends RefCounted
## Graph surgery, not placement of two rendered meshes. Every result is extracted
## as one shared organic field; source dictionaries remain unchanged.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const DNA = preload("res://alien_foundry/scripts/anatomy/CreatureDNA.gd")
const Lineage = preload("res://alien_foundry/scripts/anatomy/CreatureLineage.gd")
const MODES := ["Attachment","Fusion","Replacement","Integration"]

func combine(first: Dictionary, second: Dictionary, method: String, seed_value: int, options: Dictionary = {}) -> Dictionary:
	var options_check := Lineage.validate_json(options)
	if not options_check["ok"]:
		var rejected := DNA.create("Combination",seed_value,{})
		rejected["validation"]={"valid":false,"errors":[options_check["error"]]}
		return rejected
	var settings:=DNA.normalize_settings(options)
	var out:=DNA.create("Combination",seed_value,settings)
	var source_lineage := Lineage.build(first,second)
	if not source_lineage["ok"]:
		out["settings"].erase("source_a"); out["settings"].erase("source_b")
		out["validation"]={"valid":false,"errors":[source_lineage["error"]]}
		return out
	if first.get("nodes",[]).is_empty() or second.get("nodes",[]).is_empty():
		out["validation"]={"valid":false,"errors":["Both combination sources must contain anatomy."]}; return out
	var mode:=method.capitalize()
	if mode not in MODES: mode="Fusion"
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value
	var a:=_prepare(first,"a_"); var b:=_prepare(second,"b_")
	var intensity:=float(settings["fusion_intensity"])
	out["nodes"]=a["nodes"]; out["modules"]=a["modules"]
	for key in ["ancestry_version","ancestry","lineage"]: out[key]=source_lineage[key]
	out["metadata"]["combination_method"]=mode
	out["metadata"]["fusion_intensity"]=intensity
	out["metadata"]["source_node_counts"]=[first["nodes"].size(),second["nodes"].size()]
	out["metadata"]["operations"]=[]
	match mode:
		"Attachment": _attachment(out,b,intensity,rng)
		"Fusion": _fusion(out,b,intensity)
		"Replacement": _replacement(out,b,intensity,rng)
		"Integration": _integration(out,b,intensity,rng)
	# Anatomical material and noise values remain coherent with the new controls.
	for n in out["nodes"]:
		n["noise"]=clampf(float(n.get("noise",0.06))*(0.45+float(settings["surface_detail"])),0.0,0.20)
		if n.get("kind","")!="cavity" and n.get("connection_kind","") in ["attachment","fusion","replacement","integration"] and n.get("role","") not in ["tendon","digit","rib","fold","aperture_rim","crest","head","palm","foot"]:
			# Only the graft junction receives extra connective blending. Distal
			# claws, joints and old tissue boundaries retain their authored rules.
			var local_radius:=float(n.get("radius",0.1))
			n["blend"]=maxf(float(n.get("blend",0.1)),local_radius*(0.25+intensity*0.35))
	out=_budget_graph(out)
	out=Graph.repair(out)
	Graph.scale_graph(out,float(settings["size"]))
	Graph.ground_graph(out)
	out["settings"]["method"]=mode
	# Source DNA is already represented completely by nodes+ancestry. Never nest
	# entire source graphs inside settings, which would grow exponentially.
	out["settings"].erase("source_a"); out["settings"].erase("source_b")
	out["validation"]=Graph.validate(out)
	out["metadata"]["node_count"]=out["nodes"].size()
	out["metadata"]["module_count"]=out["modules"].size()
	return out

func _prepare(source: Dictionary, prefix: String) -> Dictionary:
	var result:=source.duplicate(true)
	var scale:=float(result.get("settings",{}).get("size",1.0))
	if scale>0.0: Graph.scale_graph(result,1.0/scale)
	var names: Dictionary={}
	for n in result["nodes"]: names[str(n["id"])]=prefix+str(n["id"])
	for n in result["nodes"]:
		n["original_id"]=n.get("original_id",n["id"])
		n["id"]=names[n["id"]]
		n["parent"]=names.get(str(n.get("parent","")),"")
		for reference_key in ["cavity_id","membrane_to"]:
			if n.has(reference_key): n[reference_key]=names.get(str(n[reference_key]),"")
	for m in result.get("modules",[]):
		m["id"]=prefix+str(m["id"]); m["parent"]=names.get(str(m["parent"]),"")
	return result

func _attachment(out: Dictionary, donor: Dictionary, intensity: float, rng: RandomNumberGenerator) -> void:
	var host: Dictionary=out["nodes"][0]
	var candidates:=_hosts(out)
	if candidates.size()>1: host=candidates[rng.randi_range(0,mini(candidates.size()-1,2))]
	Graph.scale_graph(donor,lerpf(0.48,0.76,intensity))
	var root: Dictionary=donor["nodes"][0]
	var hsize:=Graph.vec(host["size"]); var rsize:=Graph.vec(root["size"])
	var direction:=Vector3(rng.randf_range(-0.25,0.25),0.95,0.3).normalized()
	var anchor:=Graph.vec(host["position"])+direction*(Graph.surface_radius(hsize,direction)*0.78+rsize.y*0.20)
	Graph.translate_graph(donor,anchor-Graph.vec(root["position"]))
	root["parent"]=host["id"]; root["connection_kind"]="attachment"
	_append(out,donor)
	out["metadata"]["operations"].append({"operation":"attachment","host":host["id"],"donor_root":root["id"],"tissue_bridge":true})

func _fusion(out: Dictionary, donor: Dictionary, intensity: float) -> void:
	var host: Dictionary=out["nodes"][0]
	var root: Dictionary=donor["nodes"][0]
	var host_p:=Graph.vec(host["position"])
	var donor_p:=Graph.vec(root["position"])
	var host_size:=Graph.vec(host["size"])
	var donor_size:=Graph.vec(root["size"])
	Graph.scale_graph(donor,lerpf(0.65,0.95,intensity))
	root=donor["nodes"][0]
	Graph.translate_graph(donor,host_p-Graph.vec(root["position"])+Vector3(host_size.x*0.22*(1.0-intensity),0,0))
	# Remove the redundant donor core and grow one volume-preserving shared core.
	var volume_ratio:=pow(1.0+intensity*0.75,1.0/3.0)
	host["size"]=Graph.arr(host_size.lerp(donor_size,0.25*intensity)*volume_ratio)
	host["blend"]=maxf(0.065,minf(host_size.x,minf(host_size.y,host_size.z))*(0.22+intensity*0.38))
	host["fused_sources"]=[host.get("source",""),root.get("source","")]
	var donor_root:=str(root["id"])
	var remaining: Array=[]
	for n in donor["nodes"]:
		if n["id"]==donor_root: continue
		if n.get("parent","")==donor_root:
			n["parent"]=host["id"]
			n["connection_kind"]="fusion"
		remaining.append(n)
	donor["nodes"]=remaining
	for m in donor.get("modules",[]):
		if m["parent"]==donor_root:
			m["parent"]=host["id"]
			var normal:=Graph.vec(m["normal"])
			if bool(m.get("full_shell",false)):
				# A removed donor cranium becomes an embedded shell on the shared core.
				# Do not retain its old free-head seat or overlap an existing root face.
				for existing in out.get("modules",[]):
					if existing.get("parent","")==host["id"] and bool(existing.get("full_shell",false)):
						normal=normal.rotated(Vector3.UP,0.75).normalized()
						break
				m["normal"]=Graph.arr(normal)
				m["surface_mount"]=true; m["shell_surface_offset"]=0.25
				m["mounting"]="embedded_cranial"
				m["position"]=Graph.arr(host_p+normal*(Graph.surface_radius(Graph.vec(host["size"]),normal)*0.94+Graph.vec(m["scale"]).z*0.25))
			else:
				m["position"]=Graph.arr(host_p+normal*Graph.surface_radius(Graph.vec(host["size"]),normal)*0.96)
	_append(out,donor)
	out["metadata"]["operations"].append({"operation":"fusion","shared_core":host["id"],"removed_core":donor_root,"source_centers":[Graph.arr(host_p),Graph.arr(donor_p)]})

func _replacement(out: Dictionary, donor: Dictionary, intensity: float, rng: RandomNumberGenerator) -> void:
	# A humanoid's supporting lower region can become a vermiform body while
	# preserving its recognizable upper-body hierarchy: a genuine regional graft.
	if str(out.get("ancestry",[{}])[0].get("type","")) == "Humanoid":
		# A compact amorphous donor supplies a genuine supporting lower body,
		# not a whole second organism attached to a randomly selected arm.
		if str(out.get("ancestry",[{},{}])[1].get("type","")) == "Blob":
			var pelvis: Dictionary=out["nodes"][0]
			var lower_roots: Array=[]
			for n in out["nodes"]:
				if n.get("parent","")==pelvis["id"] and n.get("role","")=="limb": lower_roots.append(str(n["id"]))
			var removed: Array=[]
			for id in lower_roots: removed.append_array(_remove_subtree(out,id))
			Graph.scale_graph(donor,lerpf(0.78,1.15,intensity))
			var new_root: Dictionary=donor["nodes"][0]
			var seat:=Graph.vec(pelvis["position"])-Vector3(0,Graph.vec(new_root["size"]).y*0.56,0)
			Graph.translate_graph(donor,seat-Graph.vec(new_root["position"]))
			new_root["parent"]=pelvis["id"]; new_root["connection_kind"]="replacement"
			_append(out,donor)
			out["metadata"]["operations"].append({"operation":"replacement","region":"amorphous supporting lower body","removed_ids":removed,"recipient_parent":pelvis["id"],"donor_root":new_root["id"]})
			return
		var body_id := ""
		for n in donor["nodes"]:
			if n.get("role","") == "body_chain" and n.get("points",[]).size()>=6: body_id=str(n["id"]); break
		if not body_id.is_empty():
			var pelvis: Dictionary=out["nodes"][0]
			var lower_roots: Array=[]
			for n in out["nodes"]:
				if n.get("parent","") == pelvis["id"] and n.get("role","") == "limb": lower_roots.append(str(n["id"]))
			var removed: Array=[]
			for id in lower_roots: removed.append_array(_remove_subtree(out,id))
			var lower := _subtree(donor,body_id)
			Graph.scale_graph(lower,lerpf(0.80,1.1,intensity))
			var new_root: Dictionary=lower["nodes"][0]
			Graph.translate_graph(lower,Graph.vec(pelvis["position"])-Graph.vec(new_root["position"]))
			new_root["parent"]=pelvis["id"]; new_root["connection_kind"]="replacement"
			_append(out,lower)
			out["metadata"]["operations"].append({"operation":"replacement","region":"supporting lower body","removed_ids":removed,"recipient_parent":pelvis["id"],"donor_root":new_root["id"]})
			return
	var candidates: Array=[]
	for n in out["nodes"]:
		if n.get("role","") in ["limb","neck","body_chain","trunk"] and n.get("parent","")!="": candidates.append(n)
	var target: Dictionary
	if not candidates.is_empty(): target=candidates[rng.randi_range(0,candidates.size()-1)]
	else:
		for n in out["nodes"]:
			if n.get("role","")=="lobe": candidates.append(n)
		target=candidates[0] if not candidates.is_empty() else out["nodes"][-1]
	if target.get("parent","")=="":
		# A one-node input retains its core but replaces its surface region with a
		# donor trunk; this is a region replacement, not a type fallback.
		_attachment(out,donor,intensity,rng); out["metadata"]["operations"].append({"operation":"replacement","region":"surface"}); return
	var parent_id:=str(target["parent"])
	var target_position:=Graph.vec(target["position"])
	var donor_root: Dictionary=donor["nodes"][0]
	var selected: Dictionary=donor
	# Transfer a recognizable donor region rather than a whole second creature
	# when it has an articulated trunk; otherwise use its mass organization.
	for n in donor["nodes"]:
		if n.get("role","")=="body_chain": selected=_subtree(donor,str(n["id"])); break
	var removed:=_remove_subtree(out,str(target["id"]))
	Graph.scale_graph(selected,lerpf(0.62,0.88,intensity))
	donor_root=selected["nodes"][0]
	Graph.translate_graph(selected,target_position-Graph.vec(donor_root["position"]))
	donor_root["parent"]=parent_id; donor_root["connection_kind"]="replacement"
	_append(out,selected)
	out["metadata"]["operations"].append({"operation":"replacement","removed_ids":removed,"recipient_parent":parent_id,"donor_root":donor_root["id"]})

func _integration(out: Dictionary, donor: Dictionary, intensity: float, rng: RandomNumberGenerator) -> void:
	if _integrate_paired_supports(out,donor,intensity): return
	var branches: Array=[]; var ancestors: Dictionary={}
	for n in donor["nodes"]:
		var parent:=str(n.get("parent",""))
		if ancestors.has(parent): ancestors[n["id"]]=true; continue
		if n.get("role","") in ["limb","neck","body_chain","trunk","head"] and parent!="":
			branches.append(str(n["id"])); ancestors[n["id"]]=true
	if branches.is_empty():
		for n in donor["nodes"]:
			if ancestors.has(str(n.get("parent",""))): ancestors[n["id"]]=true; continue
			if n.get("role","") in ["lobe","growth"]:
				branches.append(str(n["id"])); ancestors[n["id"]]=true
	var hosts:=_hosts(out)
	var limit:=mini(branches.size(),3+int(round(intensity*5)))
	# Remove a subset of old supporting appendages before distributing new ones.
	var remove: Array=[]
	for n in out["nodes"]:
		if n.get("role","")=="limb" and remove.size()<int(intensity*3): remove.append(str(n["id"]))
	for id in remove: _remove_subtree(out,id)
	for i in range(limit):
		var part:=_subtree(donor,branches[i])
		if part["nodes"].is_empty(): continue
		var host: Dictionary=hosts[i%hosts.size()]
		var yaw:=float(i)*2.39996+rng.randf_range(-0.22,0.22)
		var direction:=Vector3(cos(yaw),0.1,sin(yaw)).normalized()
		var center:=Graph.vec(host["position"])
		var anchor:=center+direction*Graph.surface_radius(Graph.vec(host["size"]),direction)*0.68
		_reorient(part,yaw*0.35)
		Graph.scale_graph(part,lerpf(0.65,0.95,intensity))
		var root: Dictionary=part["nodes"][0]
		Graph.translate_graph(part,anchor-Graph.vec(root["position"]))
		root["parent"]=host["id"]; root["connection_kind"]="integration"
		_append(out,part)
		out["metadata"]["operations"].append({"operation":"integration","graft_root":root["id"],"recipient":host["id"],"orientation":yaw*0.35})
	if limit==0:
		# The valid single-mass donor still contributes its tissue and modules.
		_fusion(out,donor,intensity)
		out["metadata"]["operations"].append({"operation":"integration","region":"single-mass tissue"})

func _integrate_paired_supports(out: Dictionary, donor: Dictionary, intensity: float) -> bool:
	# A bilateral axial locomotor system is an anatomical region, not a bag of
	# independently rotated branches. Transfer its paired stations coherently.
	# Vertical or irregular recipients retain the general integration grammar.
	var hosts := _hosts(out)
	if hosts.size()<2: return false
	var z_min := INF; var z_max := -INF
	var y_min := INF; var y_max := -INF
	for host in hosts:
		var p := Graph.vec(host["position"])
		z_min=minf(z_min,p.z); z_max=maxf(z_max,p.z)
		y_min=minf(y_min,p.y); y_max=maxf(y_max,p.y)
	if z_max-z_min<0.45 or z_max-z_min<(y_max-y_min)*1.25: return false
	var donor_hosts: Dictionary={}
	for host in _hosts(donor): donor_hosts[str(host["id"])]=host
	var left: Array=[]; var right: Array=[]
	for n in donor["nodes"]:
		if n.get("role","")!="limb" or n.get("kind","")!="curve" or not donor_hosts.has(str(n.get("parent",""))): continue
		var points: Array=n.get("points",[])
		if points.size()<3: continue
		var origin:=Graph.vec(points[0]); var tip:=Graph.vec(points[-1])
		var host_center:=Graph.vec(donor_hosts[n["parent"]]["position"])
		var side:=signf(origin.x-host_center.x)
		if side==0.0 or (tip.x-origin.x)*side<0.15 or origin.y-tip.y<0.20: continue
		if side<0.0: left.append(n)
		else: right.append(n)
	var pair_total:=mini(left.size(),right.size())
	if pair_total<2: return false
	left.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a["position"][2])<float(b["position"][2]))
	right.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a["position"][2])<float(b["position"][2]))
	for i in range(pair_total):
		if absf(float(left[i]["position"][2])-float(right[i]["position"][2]))>0.28: return false
	var pair_count:=mini(pair_total,clampi(2+int(round(intensity*float(pair_total-2))),2,6))
	# Replace old support pairs together, never leave a random three-legged host.
	var recipient_limbs: Array=[]
	for n in out["nodes"]:
		if n.get("role","")=="limb": recipient_limbs.append(n)
	recipient_limbs.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a["position"][2])>float(b["position"][2]))
	var remove_count:=mini(recipient_limbs.size(),int(ceil(float(recipient_limbs.size())*intensity*0.5))*2)
	var removed: Array=[]
	for i in range(remove_count): removed.append_array(_remove_subtree(out,str(recipient_limbs[i]["id"])))
	var graft_ids: Array=[]
	var selected_stations: Array=[]
	for station in range(pair_count):
		var t:=float(station)/maxf(1.0,float(pair_count-1))
		var donor_station:=int(round(t*float(pair_total-1)))
		var target_z:=lerpf(z_min,z_max,t)
		selected_stations.append(target_z)
		var nearest: Dictionary=hosts[0]
		for host in hosts:
			if absf(Graph.vec(host["position"]).z-target_z)<absf(Graph.vec(nearest["position"]).z-target_z): nearest=host
		var target_y:=Graph.vec(nearest["position"]).y-Graph.vec(nearest["size"]).y*0.32
		for side_index in range(2):
			var side: float=-1.0 if side_index==0 else 1.0
			var source_root: Dictionary=left[donor_station] if side_index==0 else right[donor_station]
			var part:=_subtree(donor,str(source_root["id"]))
			var source_points: Array=source_root["points"]
			var drop:=Graph.vec(source_points[0]).y-Graph.vec(source_points[-1]).y
			# Keep the donor's outward joint organization while matching the new
			# trunk height. No yaw can accidentally turn a right leg through its core.
			var scale_factor:=clampf((target_y-0.12)/maxf(drop,0.20),0.72,1.55)
			Graph.scale_graph(part,scale_factor)
			var root: Dictionary=part["nodes"][0]
			var radius:=float(root["radii"][0])
			var host: Dictionary=nearest
			var lateral: float=-INF
			for candidate in hosts:
				var center:=Graph.vec(candidate["position"]); var size:=Graph.vec(candidate["size"])
				var section:=1.0-pow((target_y-center.y)/size.y,2.0)-pow((target_z-center.z)/size.z,2.0)
				if section<=0.0: continue
				var extent:=side*center.x+size.x*sqrt(section)
				if extent>lateral: lateral=extent; host=candidate
			if not is_finite(lateral): lateral=Graph.vec(nearest["size"]).x*0.8
			var anchor:=Vector3(side*(lateral-radius*0.24),target_y,target_z)
			Graph.translate_graph(part,anchor-Graph.vec(root["position"]))
			root["parent"]=host["id"]; root["connection_kind"]="integration"
			root["blend"]=maxf(float(root.get("blend",0.08)),radius*0.48)
			_append(out,part)
			graft_ids.append(root["id"])
			out["metadata"]["operations"].append({"operation":"integration","region":"paired axial locomotion","graft_root":root["id"],"recipient":host["id"],"station":station,"side":side,"source_station":donor_station,"orientation":0.0})
	out["metadata"]["integration_layout"]={"organization":"bilateral axial stations","pair_count":pair_count,"source_pair_count":pair_total,"graft_roots":graft_ids,"removed_ids":removed,"stations":selected_stations}
	return true

func _hosts(graph: Dictionary) -> Array:
	var result: Array=[]
	for n in graph["nodes"]:
		if n.get("kind","")=="mass" and n.get("role","") in ["core","torso","visceral_core","pelvis","abdomen","lobe","segment"]: result.append(n)
	if result.is_empty(): result.append(graph["nodes"][0])
	return result

func _append(target: Dictionary, source: Dictionary) -> void:
	target["nodes"].append_array(source["nodes"])
	target["modules"].append_array(source.get("modules",[]))

func _subtree(graph: Dictionary, root_id: String) -> Dictionary:
	var ids: Dictionary={root_id:true}; var nodes: Array=[]; var modules: Array=[]
	for n in graph["nodes"]:
		if str(n["id"])==root_id or ids.has(str(n.get("parent",""))): ids[n["id"]]=true; nodes.append(n.duplicate(true))
	for m in graph.get("modules",[]):
		if ids.has(str(m["parent"])): modules.append(m.duplicate(true))
	if not nodes.is_empty(): nodes[0]["parent"]=""
	return {"nodes":nodes,"modules":modules,"connections":[]}

func _remove_subtree(graph: Dictionary, root_id: String) -> Array:
	var ids: Dictionary={root_id:true}; var keep: Array=[]; var modules: Array=[]
	for n in graph["nodes"]:
		if ids.has(str(n["id"])) or ids.has(str(n.get("parent",""))): ids[n["id"]]=true
		else: keep.append(n)
	for m in graph.get("modules",[]):
		if not ids.has(str(m["parent"])): modules.append(m)
	graph["nodes"]=keep; graph["modules"]=modules
	return ids.keys()

func _reorient(graph: Dictionary, yaw: float) -> void:
	var basis:=Basis(Vector3.UP,yaw)
	for n in graph["nodes"]:
		n["position"]=Graph.arr(basis*Graph.vec(n["position"]))
		n["rotation"]=Graph.arr((basis*Graph.node_basis(n)).get_euler())
		if n.has("normal"): n["normal"]=Graph.arr(basis*Graph.vec(n["normal"]))
		if n.has("growth_origin"): n["growth_origin"]=Graph.arr(basis*Graph.vec(n["growth_origin"]))
		for i in range(n.get("points",[]).size()): n["points"][i]=Graph.arr(basis*Graph.vec(n["points"][i]))
	for m in graph.get("modules",[]):
		m["position"]=Graph.arr(basis*Graph.vec(m["position"]))
		m["normal"]=Graph.arr(basis*Graph.vec(m["normal"])); m["up"]=Graph.arr(basis*Graph.vec(m["up"]))

func _budget_graph(graph: Dictionary) -> Dictionary:
	var limit:=int(graph["budget"]["nodes"])-8
	# Remove optional leaf details first. This preserves both source body plans
	# under recursive combinations rather than silently discarding donor anatomy.
	while graph["nodes"].size()>limit:
		var children: Dictionary={}
		for n in graph["nodes"]: children[n.get("parent","")]=true
		var chosen:=""
		for n in graph["nodes"]:
			if not children.has(n["id"]) and n.get("role","")=="tendon": chosen=n["id"]; break
		if chosen.is_empty():
			for n in graph["nodes"]:
				if not children.has(n["id"]) and n.get("role","") in ["growth","digit","antenna","tendril","cavity","fold"]: chosen=n["id"]; break
		if chosen.is_empty():
			for n in graph["nodes"]:
				if not children.has(n["id"]) and n.get("parent","")!="": chosen=n["id"]; break
		if chosen.is_empty(): break
		_remove_subtree(graph,chosen)
	return graph
