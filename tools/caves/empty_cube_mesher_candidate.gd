extends "res://scripts/caves/mesher.gd"
## Same field,lattice,tetrahedra,rounding,winding and normals. Do not allocate
## per-cube point/value arrays when all eight samples have the same sign.
func build(volume,coordinate:Vector3i,step_metres:float=2)->Array:
	vertices.clear();normals.clear();colors.clear();normal_cache.clear();field=volume;origin=Vector3(coordinate)*64
	if step_metres not in [1.0,2.0,4.0] or not field.has_chunk(coordinate):return []
	var count:int=roundi(64/step_metres);var row:int=count+1;var plane:int=row*row;var points:=PackedVector3Array();var values:=PackedFloat32Array();points.resize(row*plane);values.resize(row*plane)
	for z in range(row):
		for y in range(row):
			for x in range(row):
				var index:int=x+row*y+plane*z;var point:Vector3=origin+Vector3(x,y,z)*step_metres;points[index]=point;values[index]=field.sample(point)
	var offsets:=PackedInt32Array([0,1,1+row,row,plane,1+plane,1+row+plane,row+plane])
	for z in range(count):
		for y in range(count):
			for x in range(count):
				var base:int=x+row*y+plane*z;var any_air:bool=false;var any_rock:bool=false
				for offset:int in offsets:
					any_air=any_air or values[base+offset]<0;any_rock=any_rock or values[base+offset]>=0
					if any_air and any_rock:break
				if not any_air or not any_rock:continue
				var cube_points:=PackedVector3Array();var cube_values:=PackedFloat32Array()
				for offset:int in offsets:cube_points.append(points[base+offset]);cube_values.append(values[base+offset])
				for indices_tet:Array in TETS:tetra(cube_points,cube_values,indices_tet)
	if vertices.is_empty():return []
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;return arrays
