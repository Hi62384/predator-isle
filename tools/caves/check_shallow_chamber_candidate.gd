extends "res://tools/caves/check_crystal_world_cohort.gd"
const Shallow=preload("res://tools/caves/shallow_chamber_candidate.gd")
const Scope=preload("res://tools/caves/inspection_scope.gd")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/shallow_chamber_candidate.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var records:Array=[];var positives:int=0;var first:Dictionary={}
	for host:String in ["crystal_wastes","quarry"]:
		for seed_id:int in [73921,17,92881]:
			var b=owner(host,seed_id);var work=Workload.new();check(work.configure(b.settings,config,seed_id,0),"Original actual host configuration")
			for site:Vector2i in SITES_CRYSTAL:
				var region:Dictionary=work.network.region(site);var before:PackedByteArray=var_to_bytes(region);var proposal:Dictionary=Shallow.prepare(region,work.builder._get_height);check(var_to_bytes(region)==before and var_to_bytes(Shallow.prepare(region,work.builder._get_height,false))==before,"Original region immutable and complete independent OFF return exact")
				var additions:int=proposal.get("pockets",[]).size()-region.get("pockets",[]).size();check(additions in [0,1] and var_to_bytes(proposal.nodes)==var_to_bytes(region.nodes) and var_to_bytes(proposal.edges)==var_to_bytes(region.edges),"Bounded optional chamber;original graph nodes and every original route exact")
				var item:Dictionary={"host":host,"seed":seed_id,"site":[site.x,site.y],"valid":region.get("valid",false),"added":additions}
				if additions==1:
					positives+=1;var room:Dictionary=proposal.pockets[-1];var depth:float=work.builder._get_height(room.point.x,room.point.z)-room.point.y;check(depth>=24 and depth<40 and room.chamber_radius==14 and room.chamber_height==10,"Actual physical depth band one,not relabelled graph tier")
					var passage:Dictionary=proposal.pocket_passages[-1];check(passage.maximum_grade<=.2 and passage.half_width==4 and passage.headroom==8 and passage.points[0]==region.nodes[1].point and passage.points[-1]==room.point,"New branch connects original main node with unchanged protected8x8m route and ordinary grade")
					item["room"]=room;item["passage"]=passage;item["depth_m"]=depth
					if first.is_empty():first=item.duplicate(true)
				records.append(item)
	check(records.size()==36 and positives>0,"All36predeclared actual host/seed/site cases retained with positive safe shallow chambers")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private shallow candidate "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_shallow_chamber_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"positives":positives,"first_positive":first,"scope":"PRIVATE same-field shared-core shallow side-chamber proposal. Original36actual host/seed/sites,all negatives retained,complete input/OFF/old-node/old-edge equality,canonical shallow cover and old access full-width floor admission. No production adoption,Crystal occurrence,native geometry/collision/full route/FPS claim."},"  "));print("SHALLOW_CHAMBER_CANDIDATE ",checks," positives=",positives," first=",first," failures=",failures);quit(0 if failures.is_empty() else 1)
