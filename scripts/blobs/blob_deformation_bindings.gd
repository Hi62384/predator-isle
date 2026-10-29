extends RefCounted
## Material patches preserve local shape; appendages share endpoint skinning.
const MAX_GROUPS=32
const MAX_CHAINS=16
const JOINTS=8
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
const Curves=preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
static func finalize(data: Dictionary) -> Dictionary:
	var groups: Array[Dictionary]=[]
	var group_ids: Dictionary={}
	var chains: Array[Dictionary]=[]
	var chain_ids: Dictionary={}
	var features: Array=data.features
	var size: float=data.dna.size
	# Protected islands are allocated first; never force a face or stalk under
	# the body merely because a rolling preview was selected.
	for pass_id in 2:
		for f: Dictionary in features:
			var protected: bool=f.feature_type in ["embedded_face","sensory_stalk","sensory_sprout","muscular_limb","jointed_limb","major_vine"]
			if protected!=(pass_id==0): continue
			if not protected and f.feature_type not in ["inflated_sac","satellite_sac","growth_nodule","porous_mantle","cartilage_plate","bruise_patch"]: continue
			if groups.size()>=MAX_GROUPS: continue
			var radii: Vector3=f.radii
			if f.has("points"): radii=Vector3.ONE*maxf(f.radii.x*3.0,size*.22)
			var normal: Vector3=f.direction
			if f.has("points"): normal=(f.points[1]-f.points[0]).normalized()
			var stiffness: float={"face":.94,"cartilage":.9,"sponge":.8,"sac":.35}.get(f.tissue,.65)
			group_ids[f.id]=groups.size()
			groups.append({"feature_id":f.id,"center":f.center,"radii":radii,"direction":normal,"stiffness":stiffness,"protected":protected,"minimum_scale":.91 if stiffness>.8 else .74,"circulation_gain":0.0 if protected else 1.0,"tissue":f.tissue})
	for kind in ["muscular_limb","jointed_limb","major_vine","sensory_stalk","sensory_sprout","membrane_support"]:
		for f: Dictionary in features:
			if f.feature_type!=kind or chains.size()>=MAX_CHAINS or f.get("omitted",false): continue
			var curve: Dictionary=Curves.sample({"points":_arrays(f.points),"radii":f.radii_profile},8,true)
			var rests:PackedVector3Array=f.get("binding_curve",resample(curve.points,JOINTS))
			f["binding_curve"]=rests
			var lengths:=PackedFloat32Array()
			var length:=.0
			for i in JOINTS-1:
				var segment: float=rests[i].distance_to(rests[i+1])
				lengths.append(segment); length+=segment
			chain_ids[f.id]=chains.size()
			chains.append({"feature_id":f.id,"kind":"vine" if kind=="major_vine" else ("passive" if kind in ["sensory_stalk","sensory_sprout","membrane_support"] else "leg"),"rest":rests,"lengths":lengths,"length":length,"radius":f.radii.x,"phase":fposmod(float(f.id)*.61803398875,1.0),"stiffness":.85 if kind in ["muscular_limb","jointed_limb"] else .4,"group":int(group_ids.get(f.id,-1))})
	data.rig["material_groups"]=groups
	data.rig["chains"]=chains
	data.rig["chain_ids"]=chain_ids
	data.rig["group_ids"]=group_ids
	_bind_mesh(data.body,features,groups,group_ids,chains,chain_ids,-1)
	for item: Dictionary in data.appendages: _bind_mesh(item.mesh,features,groups,group_ids,chains,chain_ids,int(item.feature.id))
	data.rig["binding_version"]=4
	data.rig["roll_safe"]=chains.is_empty() and not features.any(func(f:Dictionary): return f.feature_type=="embedded_face") and maxf(data.dna.core_radii.y/data.dna.core_radii.z,data.dna.core_radii.z/data.dna.core_radii.y)<1.4
	data.dna["requested_locomotion"]=data.dna.locomotion
	var legs:bool=chains.any(func(c:Dictionary):return c.kind=="leg")
	var vines:bool=chains.any(func(c:Dictionary):return c.kind=="vine")
	if not data.rig.roll_safe and data.dna.locomotion in ["roll","hybrid"]:data.dna.locomotion="limb" if legs else ("vine" if vines else "contractile")
	data.dna["protected_anatomy"]=groups.any(func(g: Dictionary): return g.protected)
	data.dna["roll_compatibility"]=.28 if features.any(func(f:Dictionary): return f.feature_type=="embedded_face") else (.5 if chains.any(func(c:Dictionary): return c.kind=="leg") else 1.0)
	return {"groups":groups.size(),"chains":chains.size(),"maximum_groups":MAX_GROUPS,"maximum_chains":MAX_CHAINS,"joint_count":chains.size()*JOINTS}

static func _bind_mesh(mesh:Dictionary,features:Array,groups:Array,group_ids:Dictionary,chains:Array,chain_ids:Dictionary,feature_id:int)->void:
	mesh["binds"]=PackedFloat32Array(); mesh["chain_binds"]=PackedFloat32Array()
	var normals_cache:Dictionary={}
	for i in chains.size(): normals_cache[i]=Frames.normals(chains[i].rest)
	for i in mesh.vertices.size():
		var point:Vector3=mesh.vertices[i]
		var owner:int=feature_id if feature_id>=0 else int(mesh.feature_ids[i])
		var f:Dictionary=features[owner]
		var group:=ancestor(owner,features,group_ids)
		mesh.binds.append_array(PackedFloat32Array([float(group+1),0,.4,0]))
		var chain:=ancestor(owner,features,chain_ids) if feature_id>=0 else -1
		if f.get("sheet",false):
			var a:int=chain_ids.get(f.support_ids[0],-1); var b:int=chain_ids.get(f.support_ids[1],-1)
			var surface_count:int=(f.sheet_rows+1)*(f.sheet_columns+1)
			var local_index:int=i%surface_count
			var row:int=local_index/(f.sheet_columns+1); var column:int=local_index%(f.sheet_columns+1)
			var t:float=mesh.sheet_params[i].x
			mesh.chain_binds.append_array(PackedFloat32Array([float(a+1),t,float(b+1),mesh.sheet_params[i].y]))
			mesh.binds[i*4+2]=-1
			mesh.anchors[i*4]=f.thickness*(1 if i<surface_count else -1)
			mesh.anchors[i*4+1]=float(f.get("sag",.01))*sin(float(row)/f.sheet_rows*PI)
		elif chain>=0:
			var t:=1.0
			if chain_ids.has(owner):
				var curve:PackedVector3Array=mesh.get("centerline",PackedVector3Array())
				var sides:int=mesh.get("sides",8)
				if i<curve.size()*sides: t=float(i/sides)/float(curve.size()-1)
				else: t=.0 if i==curve.size()*sides else 1.0
			elif f.has("parent_along"): t=f.parent_along
			elif f.feature_type not in ["gripping_digit","sensory_bulb"]: t=closest_parameter(f.center,chains[chain].rest)
			var center:=Frames.point(chains[chain].rest,t)
			var frame:=Frames.frame(chains[chain].rest,normals_cache[chain],t)
			var offset:=frame.transposed()*(point-center)
			mesh.anchors[i*4]=offset.x; mesh.anchors[i*4+1]=offset.y; mesh.anchors[i*4+2]=offset.z
			mesh.chain_binds.append_array(PackedFloat32Array([float(chain+1),t,0,0]))
		else: mesh.chain_binds.append_array(PackedFloat32Array([0,0,0,0]))

static func ancestor(id: int, features: Array, table: Dictionary) -> int:
	var current:=id
	while current>=0:
		if table.has(current): return table[current]
		current=int(features[current].parent)
	return -1

static func resample(points: PackedVector3Array, count: int) -> PackedVector3Array:
	var distances:=PackedFloat32Array([0.0])
	for i in range(1,points.size()): distances.append(distances[-1]+points[i].distance_to(points[i-1]))
	var result:=PackedVector3Array()
	for i in count:
		var desired:=float(i)/float(maxi(count-1,1))*distances[-1]
		var segment:=0
		while segment<points.size()-2 and distances[segment+1]<desired: segment+=1
		var t: float=(desired-distances[segment])/maxf(distances[segment+1]-distances[segment],.0001)
		result.append(points[segment].lerp(points[segment+1],t))
	return result

static func closest_parameter(point: Vector3, joints: PackedVector3Array) -> float:
	var best:=INF
	var result:=.0
	for i in joints.size()-1:
		var line:=joints[i+1]-joints[i]
		var t:=clampf((point-joints[i]).dot(line)/maxf(line.length_squared(),.000001),0.0,1.0)
		var distance:=point.distance_squared_to(joints[i]+line*t)
		if distance<best: best=distance; result=(float(i)+t)/float(joints.size()-1)
	return result

static func _arrays(points: Array) -> Array:
	var result: Array=[]
	for p: Vector3 in points: result.append([p.x,p.y,p.z])
	return result
