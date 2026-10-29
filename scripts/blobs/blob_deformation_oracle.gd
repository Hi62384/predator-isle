extends RefCounted
## CPU equivalent of the production vertex shader, used for triangle QA.
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
static func mesh_pose(mesh:Dictionary,actor:Node3D)->Dictionary:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var frames:Array=[]
	for c:Dictionary in actor.contacts.chains:
		var local:=PackedVector3Array()
		for p:Vector3 in c.points:local.append(p-actor.global_position-Vector3.UP*actor.solver.height)
		var rest_normals:=Frames.normals(c.rest)
		frames.append({"rest":c.rest,"posed":local,"rest_normals":rest_normals,"normals":Frames.normals(local,c.frame_seed)})
	for i in mesh.vertices.size():
		var rest:Vector3=mesh.vertices[i];var normal:Vector3=mesh.normals[i]
		var id:int=int(mesh.chain_binds[i*4])-1;var t:float=mesh.chain_binds[i*4+1]
		if mesh.binds[i*4+2]<-.5 and id>=0:
			var other:int=int(mesh.chain_binds[i*4+2])-1;var u:float=mesh.chain_binds[i*4+3]
			var a:=Frames.point(frames[id].posed,t);var b:=Frames.point(frames[other].posed,t)
			var n:Vector3=(b-a).cross(Frames.tangent(frames[id].posed,t)+Frames.tangent(frames[other].posed,t)).normalized()
			vertices.append(a.lerp(b,u)+n*(mesh.anchors[i*4]-mesh.anchors[i*4+1]*4*u*(1-u)))
			var transform:=sheet_basis(frames[id].posed,frames[other].posed,t)*sheet_basis(frames[id].rest,frames[other].rest,t).transposed()
			normals.append((transform*normal).normalized())
		elif id>=0:
			var c:Dictionary=frames[id];var frame:=Frames.frame(c.posed,c.normals,t)
			var offset:=Vector3(mesh.anchors[i*4],mesh.anchors[i*4+1],mesh.anchors[i*4+2])
			vertices.append(Frames.point(c.posed,t)+frame*offset)
			normals.append((frame*Frames.frame(c.rest,c.rest_normals,t).transposed()*normal).normalized())
		else:
			vertices.append(actor.solver.map_point(rest))
			# An analytic orientation reference for the near-isometric field.
			var r:Vector3=actor.anatomy.dna.core_radii
			var angle:float=-actor.solver.circulation if actor.solver.roll_safe else 0
			var n:=Vector3(normal.x,normal.y*r.y,normal.z*r.z).rotated(Vector3.RIGHT,angle)
			n=Vector3(n.x,n.y/r.y,n.z/r.z)
			normals.append((actor.solver.pose_frame*n).normalized())
	var references:=PackedVector3Array()
	var matrix_cache:Dictionary={}
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		var n:Vector3=-(mesh.vertices[b]-mesh.vertices[a]).cross(mesh.vertices[c]-mesh.vertices[a]).normalized()
		var id:int=int(mesh.chain_binds[a*4])-1
		if id<0:
			var r:Vector3=actor.anatomy.dna.core_radii
			var angle:float=-actor.solver.circulation if actor.solver.roll_safe else 0
			n=Vector3(n.x,n.y*r.y,n.z*r.z).rotated(Vector3.RIGHT,angle)
			n=actor.solver.pose_frame*Vector3(n.x,n.y/r.y,n.z/r.z)
		else:
			var t:float=mesh.chain_binds[a*4+1]
			var key:=Vector2i(id,int(t*1000000))
			if not matrix_cache.has(key):
				if mesh.binds[a*4+2]<-.5:
					var other:int=int(mesh.chain_binds[a*4+2])-1
					matrix_cache[key]=sheet_basis(frames[id].posed,frames[other].posed,t)*sheet_basis(frames[id].rest,frames[other].rest,t).transposed()
				else:matrix_cache[key]=Frames.frame(frames[id].posed,frames[id].normals,t)*Frames.frame(frames[id].rest,frames[id].rest_normals,t).transposed()
			n=matrix_cache[key]*n
		references.append(n.normalized())
	return {"vertices":vertices,"normals":normals,"reference_faces":references}

static func confirmed_inversions(mesh:Dictionary,pose:Dictionary,actor:Node3D,suspects:PackedInt32Array)->int:
	var count:=0
	for face:int in suspects:
		var a:int=mesh.indices[face*3];var b:int=mesh.indices[face*3+1];var c:int=mesh.indices[face*3+2]
		var normal:Vector3=-(mesh.vertices[b]-mesh.vertices[a]).cross(mesh.vertices[c]-mesh.vertices[a]).normalized()
		var current:Vector3=(pose.vertices[b]-pose.vertices[a]).cross(pose.vertices[c]-pose.vertices[a])
		var id:int=int(mesh.chain_binds[a*4])-1
		if id<0:normal=actor.solver.map_normal((mesh.vertices[a]+mesh.vertices[b]+mesh.vertices[c])/3,normal)
		else:
			var t:float=(mesh.chain_binds[a*4+1]+mesh.chain_binds[b*4+1]+mesh.chain_binds[c*4+1])/3
			var chain:Dictionary=actor.contacts.chains[id];var points:=PackedVector3Array()
			for p:Vector3 in chain.points:points.append(p-actor.global_position-Vector3.UP*actor.solver.height)
			var rest_axes:=Frames.normals(chain.rest);var axes:=Frames.normals(points,chain.frame_seed)
			if mesh.binds[a*4+2]<-.5:
				var other:int=int(mesh.chain_binds[a*4+2])-1;var other_chain:Dictionary=actor.contacts.chains[other];var other_points:=PackedVector3Array()
				for p:Vector3 in other_chain.points:other_points.append(p-actor.global_position-Vector3.UP*actor.solver.height)
				normal=sheet_basis(points,other_points,t)*sheet_basis(chain.rest,other_chain.rest,t).transposed()*normal
			else:normal=Frames.frame(points,axes,t)*Frames.frame(chain.rest,rest_axes,t).transposed()*normal
		if current.dot(normal)>1e-10:count+=1
	return count

static func sheet_basis(a:PackedVector3Array,b:PackedVector3Array,t:float)->Basis:
	var x:Vector3=(Frames.point(b,t)-Frames.point(a,t)).normalized()
	var y:Vector3=Frames.tangent(a,t)+Frames.tangent(b,t);y=(y-x*x.dot(y)).normalized()
	return Basis(x,y,x.cross(y).normalized())
