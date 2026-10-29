extends "res://tools/biome_extensions/check_all.gd"
const Mask=preload("res://tools/biome_extensions/tile_owner_mask_candidate.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var cases:Array=[]
	var synthetic:Array=[];synthetic.resize(Mesh.ARRAY_MAX)
	synthetic[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO]);synthetic[Mesh.ARRAY_COLOR]=PackedColorArray([Color(1,0,0,0)]);synthetic[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO])
	for bit:int in range(8):
		for channel:int in range(4):synthetic[Mesh.ARRAY_CUSTOM0+channel]=PackedFloat32Array([0,0,0,0])
		synthetic[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO])
		match bit:
			0:synthetic[Mesh.ARRAY_CUSTOM0][3]=65536
			1:synthetic[Mesh.ARRAY_CUSTOM1][0]=65536
			2:synthetic[Mesh.ARRAY_CUSTOM2][0]=65536
			3:synthetic[Mesh.ARRAY_CUSTOM3][0]=65536
			4:synthetic[Mesh.ARRAY_CUSTOM0][0]=-1;synthetic[Mesh.ARRAY_CUSTOM0][1]=65536
			5:synthetic[Mesh.ARRAY_CUSTOM2][0]=-65537
			6:synthetic[Mesh.ARRAY_CUSTOM0][3]=-1;synthetic[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,1)])
			7:synthetic[Mesh.ARRAY_CUSTOM1][2]=-257
		check(Mask.mask(synthetic,0)==1<<bit,"Actual shader channel/sentinel retains legacy owner "+str(bit))
	for family in range(8):
		var b=make_builder(family,73921)
		for coordinate:Vector2i in [Vector2i.ZERO,Vector2i(-3,7),Vector2i(31,-19)]:
			var arrays:Array=b.build(coordinate,8);var mask:int=Mask.mask(arrays,b.built_extension_mask)
			check(mask>=0 and mask<=65535,"Bounded exact uploaded owner union")
			check((mask>>8)==b.built_extension_mask,"All extension owners retained")
			check((mask & (1<<(family+8)))!=0 or b.built_extension_mask==0,"Present selected family retained")
			cases.append({"family":family,"coordinate":str(coordinate),"mask":mask})
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"Private mesh-mask candidate;not production or GPU parity acceptance"}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tile_owner_mask_candidate.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TILE_OWNER_MASK ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
