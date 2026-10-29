extends "res://scripts/caves/portal_field.gd"
## Private adapter emulates adding bank_lobes to the existing compile's room
## list. Original graph/edges and biomes remain untouched.
func compile(regions:Array,surface:Callable,extra_edges:Array=[],biome_assignment:Dictionary={})->bool:
	var expanded:Array=[]
	for region:Dictionary in regions:
		var copy:Dictionary=region.duplicate();var rooms:Array=region.get("nodes",[]).duplicate();var pools:Array=[]
		for pool:Dictionary in region.get("pools",[]):
			rooms.append_array(pool.get("bank_lobes",[]));var retained:Dictionary=pool.duplicate();retained.erase("bank_lobes");pools.append(retained)
		copy.nodes=rooms;copy.pools=pools;expanded.append(copy)
	return super.compile(expanded,surface,extra_edges,biome_assignment)
