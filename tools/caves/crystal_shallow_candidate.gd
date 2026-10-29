extends RefCounted
## Private Crystal-only extension of an already admitted connected region.
## No new lottery/anchor or depth preference;existing reach must cover it.
const Shallow=preload("res://tools/caves/shallow_chamber_candidate.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
static func prepare(region:Dictionary,height:Callable,enabled:bool=true,maximum_depth:float=400,minimum_roof:float=10)->Dictionary:
	if not enabled or not region.get("valid",false) or region.get("cave_family",-1) in [6,7] or region.get("nodes",[]).size()<2:return region
	for room:Dictionary in region.get("pockets",[]):
		if room.get("shallow_chamber",false):return region
	var parent:String=str(region.nodes[1].id);var existing:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),parent,parent,0,0)
	if float(existing.weights.get("crystal",0))<.8:return region
	var proposal:Dictionary=Shallow.prepare(region,height,true,maximum_depth,minimum_roof)
	if proposal.get("pockets",[]).size()==region.get("pockets",[]).size():return region
	var topology:Dictionary=Regions.graph(proposal)
	if topology.is_empty():return region
	var assignment:Dictionary=proposal.cave_biome_regions.duplicate(true);assignment.edges=topology.edges
	for candidate:Dictionary in assignment.candidates:
		if str(candidate.biome_id)=="crystal":candidate.distances=Regions.distances(topology,str(candidate.anchor),float(candidate.reach_m))
	proposal.cave_biome_regions=assignment;var room:Dictionary=proposal.pockets[-1];var coverage:Dictionary=Regions.along_edge(assignment,str(room.id),str(room.id),0,0)
	if float(coverage.weights.get("crystal",0))<.8:return region
	return proposal
