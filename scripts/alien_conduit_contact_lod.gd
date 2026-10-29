extends RefCounted
## Worker-only distant core topology. Original full-resolution contact/apron
## cells and endpoints remain; bends use valid wide/narrow/adaptive bands.
## All newly proposed roof faces require upward projected winding. Invalid
## unit bands retain the original triangles. No terrain lower bound is assumed.
static func proposed_triangle(a:Vector3,b:Vector3,c:Vector3)->PackedVector3Array:return PackedVector3Array([a,b,c])
static func append_quad_faces(faces:Array[PackedVector3Array],a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	faces.append(proposed_triangle(a,b,c));faces.append(proposed_triangle(a,c,d))
static func winding_valid(faces:Array[PackedVector3Array])->bool:
	for face:PackedVector3Array in faces:
		if (face[2]-face[0]).cross(face[1]-face[0]).y<=.00000001:return false
	return true
static func core_proposal(rings:Array,low:int,high:int,left:int,right:int)->Array[PackedVector3Array]:
	var faces:Array[PackedVector3Array]=[]
	for column in range(left+1,right-1):append_quad_faces(faces,rings[low][column],rings[low][column+1],rings[high][column+1],rings[high][column])
	for row in range(low,high):
		faces.append(proposed_triangle(rings[row][left],rings[low][left+1],rings[row+1][left]))
		faces.append(proposed_triangle(rings[low][right-1],rings[row][right],rings[row+1][right]))
	faces.append(proposed_triangle(rings[high][left],rings[low][left+1],rings[high][left+1]))
	faces.append(proposed_triangle(rings[low][right-1],rings[high][right],rings[high][right-1]))
	return faces
static func select_core_faces(rings:Array,low:int,high:int)->Array[PackedVector3Array]:
	var faces:Array[PackedVector3Array]=[]
	if high-low==1:
		# Exact original unit band, including its original diagonal choices.
		for column in range(3,11):append_quad_faces(faces,rings[low][column],rings[low][column+1],rings[high][column+1],rings[high][column])
		return faces
	var wide:Array[PackedVector3Array]=core_proposal(rings,low,high,3,11)
	if winding_valid(wide):return wide
	var middle:int=(low+high)/2
	faces=select_core_faces(rings,low,middle);faces.append_array(select_core_faces(rings,middle,high))
	# A narrow stitch can be cheaper than many original unit bands. Its outer
	# shoulder cells are still the exact original full-resolution triangles.
	var narrow:Array[PackedVector3Array]=core_proposal(rings,low,high,5,9)
	if winding_valid(narrow):
		for row in range(low,high):
			for column:int in [3,4,9,10]:append_quad_faces(narrow,rings[row][column],rings[row][column+1],rings[row+1][column+1],rings[row+1][column])
		if narrow.size()<faces.size():return narrow
	return faces
static func triangulate(g,rings:Array,color:Color,stride:int)->void:
	var segments:int=rings.size()-1;var selected:Array[int]=[]
	for row in range(0,segments,stride):selected.append(row)
	selected.append(segments)
	for interval in range(selected.size()-1):
		var low:int=selected[interval];var high:int=selected[interval+1]
		# These are the exact original full-resolution apron AND shoulder cells.
		for row in range(low,high):
			for column:int in [0,1,2,11,12,13]:
				g.quad(rings[row][column],rings[row][column+1],rings[row+1][column+1],rings[row+1][column],color)
		var proposed:Array[PackedVector3Array]=select_core_faces(rings,low,high)
		for face:PackedVector3Array in proposed:g.triangle(face[0],face[1],face[2],color)

