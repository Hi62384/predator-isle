extends "res://scripts/lod_biome_extension_structures.gd"
const Profile=preload("res://tools/biome_extensions/insect_mound_profile_candidate.gd")
func mound(builder,anchor:Vector3,width:float,height:float,archetype:int,phase:float,color:Color,vent_depth:float=0,broad_dome:bool=false)->void:
	var first:int=vertices.size();var previous:bool=nest_construction_profiles;nest_construction_profiles=false;super.mound(builder,anchor,width,height,archetype,phase,color,vent_depth,broad_dome);nest_construction_profiles=previous
	if archetype==3:return
	var shell_end:int=first+24*42*6;var shell:PackedVector3Array=Profile.sculpt(vertices.slice(first,shell_end),origin,anchor,width,height,archetype,phase)
	for i in range(shell.size()):vertices[first+i]=shell[i]
	var sums:Dictionary={}
	for i in range(first,vertices.size(),3):
		var n:Vector3=(vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3):normals[i+j]=n;sums[vertices[i+j]]=sums.get(vertices[i+j],Vector3.ZERO)+n
	for i in range(first,vertices.size()):
		var smooth:Vector3=sums[vertices[i]].normalized()
		if smooth.dot(normals[i])>.15:normals[i]=smooth
