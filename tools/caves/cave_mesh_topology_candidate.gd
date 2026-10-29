extends RefCounted
## PRIVATE incremental global edge incidence/direction audit. Only a genuine
## boundary of the explicitly selected chunk set may have a single edge.
var edges:Dictionary={}
var selected:Dictionary={}
var triangles:int=0
func add(arrays:Array,key:Vector3i)->void:
	if arrays.is_empty():return
	var origin:Vector3=Vector3(key)*64;var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in range(0,positions.size(),3):
		triangles+=1
		for j in range(3):
			var a:Vector3=positions[i+j]+origin;var b:Vector3=positions[i+(j+1)%3]+origin;var external:bool=false
			for axis in range(3):
				if a[axis]==0:a[axis]=0.0
				if b[axis]==0:b[axis]=0.0
				if a[axis]!=b[axis]:continue
				for direction:int in [-1,1]:
					if a[axis]!=origin[axis]+(64 if direction==1 else 0):continue
					var neighbor:Vector3i=key;neighbor[axis]+=direction
					if not selected.has(neighbor):external=true
			var forward:bool=a.x<b.x or (a.x==b.x and (a.y<b.y or (a.y==b.y and a.z<b.z)));var id:String=PackedVector3Array([a,b] if forward else [b,a]).to_byte_array().hex_encode();var record:Vector3i=edges.get(id,Vector3i.ZERO);edges[id]=record+Vector3i(1,1 if forward else -1,int(external))
func result()->Dictionary:
	var paired:int=0;var same_direction:int=0;var external:int=0;var interior_open:int=0;var nonmanifold:int=0
	for id:String in edges:
		var record:Vector3i=edges[id]
		if record.x==2:paired+=1;same_direction+=int(record.y!=0)
		elif record.x==1:
			if record.z>0:external+=1
			else:interior_open+=1
		else:nonmanifold+=1
	return {"triangles":triangles,"exact_global_edges":edges.size(),"paired_edges":paired,"same_direction_pairs":same_direction,"declared_chunk_set_external_edges":external,"interior_open_edges":interior_open,"nonmanifold_edges":nonmanifold}
