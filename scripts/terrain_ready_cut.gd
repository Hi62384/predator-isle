extends RefCounted
## Select a complete local replacement inside an existing aligned quadtree cut.
## Geometry readiness only; the host still gates cave/collision transactions.
static func contains(outer:Vector3i,inner:Vector3i)->bool:
	if outer.z<inner.z:return false
	var span:float=float(1<<(outer.z-inner.z))
	return floori(inner.x/span)==outer.x and floori(inner.y/span)==outer.y
static func area(key:Vector3i)->int:return 1<<(key.z*2)
static func edge_id(a:Vector3i,b:Vector3i)->String:
	var sa:String=str(a);var sb:String=str(b)
	return sa+"|"+sb if sa<sb else sb+"|"+sa
static func _profile_edge(vertices:PackedVector3Array,resolution:int,side:int)->Dictionary:
	var top:=PackedFloat32Array();var bottom0:=PackedFloat32Array();var bottom1:=PackedFloat32Array();var row:int=resolution+1;var main:int=row*row
	for i in range(row):
		var index:int=i*row if side==0 else (i*row+resolution if side==1 else (i if side==2 else resolution*row+i))
		top.append(vertices[index].y)
		if i==resolution:continue
		var segment:int=4*resolution-1-i if side==0 else (resolution+i if side==1 else (i if side==2 else 3*resolution-1-i))
		var reverse:bool=side==0 or side==3;var first:int=main+segment*2
		bottom0.append(vertices[first+(1 if reverse else 0)].y);bottom1.append(vertices[first+(0 if reverse else 1)].y)
	return {"top":top,"bottom0":bottom0,"bottom1":bottom1}
static func edge_profiles(arrays:Array,resolution:int)->Dictionary:
	if resolution<=0 or arrays.is_empty():return {}
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	if vertices.size()<(resolution+1)*(resolution+1)+8*resolution:return {}
	var result:Dictionary={"resolution":resolution}
	for side in range(4):result[side]=_profile_edge(vertices,resolution,side)
	return result
static func covered_edge(a:Vector3i,b:Vector3i,resolutions:Dictionary,profiles:Dictionary,planner)->Dictionary:
	if not planner.adjacent(a,b):return {}
	var ar:int=resolutions.get(a,0);var br:int=resolutions.get(b,0)
	if ar<=0 or br<=0 or (ar & (ar-1))!=0 or (br & (br-1))!=0:return {}
	var ap:Dictionary=profiles.get(a,{});var bp:Dictionary=profiles.get(b,{})
	if ap.get("resolution",0)!=ar or bp.get("resolution",0)!=br:return {}
	var wa:int=1<<a.z;var wb:int=1<<b.z;var ax:int=a.x*wa;var az:int=a.y*wa;var bx:int=b.x*wb;var bz:int=b.y*wb
	var vertical:bool=ax+wa==bx or bx+wb==ax
	var sa:int=(1 if ax+wa==bx else 0) if vertical else (3 if az+wa==bz else 2)
	var sb:int=(0 if sa==1 else 1) if vertical else (2 if sa==3 else 3)
	var astep:float=float(wa)/ar;var bstep:float=float(wb)/br
	var fine:Dictionary=ap[sa] if astep<=bstep else bp[sb];var coarse:Dictionary=bp[sb] if astep<=bstep else ap[sa]
	var fs:float=minf(astep,bstep);var cs:float=maxf(astep,bstep)
	# Both grids are aligned powers of two. Check the actual piecewise-linear
	# curtains below, at every fine segment, instead of using grid density as
	# a substitute for coverage. A larger ratio alone does not imply a gap.
	var ao:int=az if vertical else ax;var bo:int=bz if vertical else bx
	var fo:int=ao if astep<=bstep else bo;var co:int=bo if astep<=bstep else ao
	var low:int=maxi(ao,bo);var high:int=mini(ao+wa,bo+wb)
	var first:float=(low-fo)/fs;var last:float=(high-fo)/fs
	if first!=round(first) or last!=round(last):return {}
	for i in range(int(first),int(last)):
		var p0:float=fo+i*fs;var p1:float=p0+fs;var j:int=floori(((p0+p1)*.5-co)/cs)
		if j<0 or j>=coarse.bottom0.size():return {}
		var t0:float=(p0-co-j*cs)/cs;var t1:float=(p1-co-j*cs)/cs
		var ct0:float=lerpf(coarse.top[j],coarse.top[j+1],t0);var ct1:float=lerpf(coarse.top[j],coarse.top[j+1],t1)
		var cb0:float=lerpf(coarse.bottom0[j],coarse.bottom1[j],t0);var cb1:float=lerpf(coarse.bottom0[j],coarse.bottom1[j],t1)
		if not is_finite(ct0+ct1+cb0+cb1+fine.top[i]+fine.top[i+1]+fine.bottom0[i]+fine.bottom1[i]):return {}
		# Both linear curtain intervals overlap at both ends, hence throughout
		# this whole fine segment. These are the actual emitted skirt vertices.
		if fine.bottom0[i]>fine.top[i] or fine.bottom1[i]>fine.top[i+1] or cb0>ct0 or cb1>ct1:return {}
		if fine.bottom0[i]>ct0+.0001 or fine.bottom1[i]>ct1+.0001 or cb0>fine.top[i]+.0001 or cb1>fine.top[i+1]+.0001:return {}
	return {"a":a,"b":b,"a_resolution":ar,"b_resolution":br,"kind":"covered_skirt_edge","segments_checked":int(last-first),"maximum_grid_ratio":cs/fs}
static func equivalent_edge(a:Vector3i,other:Vector3i,wanted:Dictionary,resolutions:Dictionary,wanted_resolutions:Dictionary,planner)->Dictionary:
	# A retained larger leaf may already have EXACTLY the same world grid as
	# its planned replacement. Replacing its logical key is then unnecessary
	# for this edge. Never infer that from LOD alone or allow arbitrary gaps.
	if not wanted.has(a) or not planner.adjacent(a,other):return {}
	var resolution:int=resolutions.get(other,0)
	if resolution<=0 or (resolution & (resolution-1))!=0:return {}
	var step:float=float(1<<other.z)/resolution
	var wa:int=1<<a.z;var wb:int=1<<other.z
	var ax:int=a.x*wa;var az:int=a.y*wa;var bx:int=other.x*wb;var bz:int=other.y*wb
	var vertical:bool=ax+wa==bx or bx+wb==ax
	var low:int=maxi(az,bz) if vertical else maxi(ax,bx)
	var high:int=mini(az+wa,bz+wb) if vertical else mini(ax+wa,bx+wb)
	var covered:int=0;var templates:Array=[]
	for neighbor:Vector3i in wanted:
		if absi(a.z-neighbor.z)>1 or not planner.adjacent(a,neighbor):continue
		if not contains(other,neighbor) and not contains(neighbor,other):continue
		var nr:int=wanted_resolutions.get(neighbor,0)
		if nr<=0 or (nr & (nr-1))!=0 or float(1<<neighbor.z)/nr!=step:continue
		var span:int=1<<neighbor.z;var origin:int=(neighbor.y if vertical else neighbor.x)*span
		var first:int=maxi(low,origin);var last:int=mini(high,origin+span)
		if first>=last:continue
		if float(first)/step!=round(float(first)/step) or float(last)/step!=round(float(last)/step):return {}
		covered+=last-first;templates.append(neighbor)
	if covered!=high-low or templates.is_empty():return {}
	return {"a":a,"b":other,"a_resolution":resolutions.get(a,0),"b_resolution":resolution,"kind":"equivalent_final_grid","equivalent_final_neighbors":templates,"grid_step_base_units":step}
static func _group(region:Vector3i,active:Dictionary,wanted:Dictionary,ready:Dictionary)->Dictionary:
	var remove:Array[Vector3i]=[];var add:Array[Vector3i]=[];var covered:int=0
	for existing:Vector3i in active:
		if contains(region,existing):remove.append(existing)
		elif contains(existing,region):return {}
	for key:Vector3i in wanted:
		if not contains(region,key):continue
		if not ready.has(key):return {}
		add.append(key);covered+=area(key)
	return {"remove":remove,"add":add} if not add.is_empty() and covered==area(region) else {}
static func choose(active:Dictionary,wanted:Dictionary,ready:Dictionary,planner,point:Vector2,active_resolutions:Dictionary={},ready_resolutions:Dictionary={},wanted_resolutions:Dictionary={},active_profiles:Dictionary={},ready_profiles:Dictionary={},diagnostics:Variant=null)->Dictionary:
	if diagnostics is Dictionary:diagnostics.clear()
	var regions:Dictionary={}
	for key:Vector3i in ready:
		if not wanted.has(key):continue
		var region:Vector3i=key
		for existing:Vector3i in active:
			if contains(existing,key):region=existing;break
		regions[region]=true
	var ordered:Array=regions.keys()
	ordered.sort_custom(func(a:Vector3i,b:Vector3i)->bool:return planner.distance_to(a,point)<planner.distance_to(b,point))
	var groups:Dictionary={}
	for region:Vector3i in ordered:
		var trace:bool=diagnostics is Dictionary and region==ordered[0]
		if trace:diagnostics["region"]=region
		if not groups.has(region):groups[region]=_group(region,active,wanted,ready)
		if groups[region].is_empty():
			if trace:diagnostics["reason"]="local_group_waiting"
			continue
		var selected:Dictionary={region:true}
		while selected.size()<=16:
			var remove:Array[Vector3i]=[];var add:Array[Vector3i]=[]
			for selected_region:Vector3i in selected:remove.append_array(groups[selected_region].remove);add.append_array(groups[selected_region].add)
			# A new close-detail cut inside one old distant parent can contain
			# more than64 leaves. Keep a bounded transaction, but allow that
			# complete local replacement before unrelated distant roots finish.
			if add.size()>128:
				if trace:diagnostics.merge({"reason":"transaction_leaf_limit","leaves":add.size(),"groups":selected.size()})
				break
			var proposed:Dictionary=active.duplicate();var resolutions:Dictionary=active_resolutions.duplicate();var profiles:Dictionary=active_profiles.duplicate();var certificates:Array=[]
			for key:Vector3i in remove:proposed.erase(key);resolutions.erase(key);profiles.erase(key)
			for key:Vector3i in add:proposed[key]=true;resolutions[key]=ready_resolutions.get(key,0);profiles[key]=ready_profiles.get(key,{})
			var blocked:Vector3i=Vector3i(2147483647,2147483647,2147483647);var invalid:bool=false
			for key:Vector3i in add:
				for other:Vector3i in proposed:
					if key==other:continue
					if contains(key,other) or contains(other,key):invalid=true;break
					if planner.adjacent(key,other) and absi(key.z-other.z)>1:
						var certificate:Dictionary=equivalent_edge(key,other,wanted,resolutions,wanted_resolutions,planner)
						if certificate.is_empty():certificate=covered_edge(key,other,resolutions,profiles,planner)
						if certificate.is_empty():blocked=other;break
						certificates.append(certificate)
				if invalid or blocked.z!=2147483647:break
			if invalid:
				if trace:diagnostics["reason"]="overlap"
				break
			if blocked.z==2147483647:
				if trace:diagnostics.merge({"reason":"complete","leaves":add.size(),"groups":selected.size()})
				return {"remove":remove,"add":add,"edge_certificates":certificates}
			# Two ready neighboring parents can depend on one another. Join their
			# COMPLETE replacement groups in one bounded atomic transaction.
			if not active.has(blocked) or add.has(blocked):
				if trace:diagnostics.merge({"reason":"unresolvable_edge","blocked":blocked})
				break
			var neighbor_region:Vector3i=blocked
			for leaf:Vector3i in wanted:
				if contains(leaf,blocked):neighbor_region=leaf;break
			if selected.has(neighbor_region):
				if trace:diagnostics.merge({"reason":"selected_neighbor","blocked":blocked})
				break
			if not groups.has(neighbor_region):groups[neighbor_region]=_group(neighbor_region,active,wanted,ready)
			if groups[neighbor_region].is_empty():
				if trace:diagnostics.merge({"reason":"neighbor_group_waiting","blocked":blocked,"neighbor_region":neighbor_region,"groups":selected.size()})
				break
			selected[neighbor_region]=true
	return {}
