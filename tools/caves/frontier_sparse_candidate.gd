extends RefCounted
## Same output order,only quad work containing negative lattice vertices.
const Base=preload("res://scripts/caves/stream_frontiers.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
static func build(volume,key:Vector3i,boundary_values:Array=[])->Dictionary:
	var result:Dictionary={};var origin:=Vector3(key)*64;var mesher=Mesher.new()
	if not volume.has_chunk(key):return result
	var cover:float=volume.opening_rock_cover;volume.opening_rock_cover=maxf(6,cover)
	for face in range(6):
		var direction:Vector3=Vector3(Base.DIRECTIONS[face]);var start:Vector3=origin+direction.max(Vector3.ZERO)*64;var u:Vector3=Base.AXES[face];var v:Vector3=Base.OTHER[face];var values:=PackedFloat32Array();var reuse:bool=boundary_values.size()==6
		if reuse:
			values=boundary_values[face]
			if values.is_empty():continue
			if values.size()!=1089:reuse=false
		if not reuse:
			values.clear()
			for y in range(33):
				for x in range(33):values.append(Base.sample(volume,start+u*x*2+v*y*2))
		var minimum:=Vector2i(33,33);var maximum:=Vector2i(-1,-1)
		for y in range(33):
			for x in range(33):
				if values[x+y*33]<0:minimum=minimum.min(Vector2i(x,y));maximum=maximum.max(Vector2i(x,y))
		if maximum.x<0:continue
		var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var inward:Vector3=-direction
		for y in range(maxi(0,minimum.y-1),mini(32,maximum.y+1)):
			for x in range(maxi(0,minimum.x-1),mini(32,maximum.x+1)):
				var a:int=x+y*33
				if values[a]>=0 and values[a+1]>=0 and values[a+33]>=0 and values[a+34]>=0:continue
				var point:Vector3=start+u*x*2+v*y*2;var corners:Array=[point,point+u*2,point+u*2+v*2,point+v*2]
				for indices:Array in [[0,1,2],[0,2,3]]:
					var ids:Array=[a,a+1,a+34] if indices[1]==1 else [a,a+34,a+33]
					if values[ids[0]]>=0 and values[ids[1]]>=0 and values[ids[2]]>=0:continue
					var polygon:Array=Base.clipped([corners[indices[0]],corners[indices[1]],corners[indices[2]]],[values[ids[0]],values[ids[1]],values[ids[2]]],mesher)
					for i in range(1,polygon.size()-1):
						var p:Vector3=polygon[0];var q:Vector3=polygon[i];var r:Vector3=polygon[i+1];var normal:Vector3=(r-p).cross(q-p)
						if normal.length_squared()==0:continue
						if normal.dot(inward)<0:var swap:Vector3=q;q=r;r=swap
						for vertex:Vector3 in [p,q,r]:vertices.append(vertex-origin);normals.append(inward);colors.append(Color(.38,.35,.3,1))
		if vertices.is_empty():continue
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;result[face]=arrays
	volume.opening_rock_cover=cover;return result
