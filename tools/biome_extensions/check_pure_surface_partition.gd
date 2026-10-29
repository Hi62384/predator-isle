extends SceneTree
const Partition=preload("res://tools/biome_extensions/pure_surface_partition_candidate.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var settings:Resource=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for owner:String in ["badlands"]+TerrainSettings.EXTENSION_KEYS:settings.set(owner+"_coverage",12.0)
	var builder=load("res://scripts/terrain_mesh_builder.gd").new();builder.settings=settings;builder.chunk_size=16384;builder._configure_noise()
	var cases:Array=[]
	for tile:Vector2i in [Vector2i.ZERO,Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
		var arrays:Array=builder.build(tile,16);var groups:Array=Partition.partition(arrays,16384,builder.built_extension_data,builder.built_extension_rows,builder.built_extension_mask)
		var expected:Dictionary={};var count:int=arrays[Mesh.ARRAY_VERTEX].size()
		for first:int in range(0,arrays[Mesh.ARRAY_INDEX].size(),3):
			var key:String=triangle_key(arrays,arrays[Mesh.ARRAY_INDEX].slice(first,first+3),count);expected[key]=expected.get(key,0)+1
		for group:Dictionary in groups:
			var subset:Array=group.arrays;var subset_count:int=subset[Mesh.ARRAY_VERTEX].size()
			for first:int in range(0,subset[Mesh.ARRAY_INDEX].size(),3):
				var key:String=triangle_key(subset,subset[Mesh.ARRAY_INDEX].slice(first,first+3),subset_count)
				assert(expected.get(key,0)>0,"Every original triangle and packed channel copied exactly once")
				expected[key]-=1
		for amount:int in expected.values():assert(amount==0)
		cases.append({"tile":str(tile),"groups":groups.size()});print("PURE_SURFACE_PARTITION ",cases[-1])
	# The fourth bilinear corner has an owner absent from all three vertices.
	var fixture:Array=builder.build(Vector2i.ZERO,1);fixture[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
	var atlas:=PackedByteArray();atlas.resize(2*2*8*4);atlas[(1*16+1)*4]=255
	# Clear coast and all legacy ownership while retaining the original types.
	for slot:int in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
		if fixture[slot]!=null:fixture[slot].fill(0.0)
	fixture[Mesh.ARRAY_COLOR].fill(Color(1,0,0,0))
	var groups:Array=Partition.partition(fixture,16384,atlas,2,1)
	assert(groups.size()==1 and (groups[0].mask&256)!=0,"Bilinear fourth-corner owner cannot be pruned")
	print("PURE_SURFACE_PARTITION copied topology/channels and fourth-corner check passed");quit()
func triangle_key(arrays:Array,indices:PackedInt32Array,count:int)->String:
	var result:Array=[]
	for index:int in indices:
		for slot:int in range(Mesh.ARRAY_INDEX):
			if arrays[slot]==null:result.append(null);continue
			var stride:int=arrays[slot].size()/count
			for channel:int in range(stride):result.append(arrays[slot][index*stride+channel])
	return var_to_bytes(result).hex_encode()
