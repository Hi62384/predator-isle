extends "res://tools/caves/check_crystal_world_cohort.gd"
func run()->void:
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=owner("crystal_wastes",17);var work=Workload.new();check(work.configure(b.settings,config,17,0),"Original same large-region host/site/seed");var bundle:Dictionary=work.discover(Vector2i(9,-3));var target:Dictionary={};var rows:Array=[];var theme:String="9:-3:2:1:lobe:0/crystal";var dominant:int=0
	for region:Dictionary in bundle.regions:
		for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
			var local:Dictionary=Regions.along_edge(region.cave_biome_regions,str(room.id),str(room.id),0,0);var combined:Dictionary=Regions.along_edge(work.field._biome_assignment,str(room.id),str(room.id),0,0);dominant+=int(str(combined.candidate_ids.get("crystal",""))==theme)
			if str(room.id)=="9:-3:2:1:lobe:0":target=room;rows.append({"room":room,"local_assignment":local,"canonical_assignment":combined})
	check(not target.is_empty(),"Same original logical room exists");var payloads:Array=[];var counts:Dictionary={};var owned:Array=[]
	if not target.is_empty():
		var low:Vector3i=work.field.cell(target.point-Vector3(target.chamber_radius+8,6,target.chamber_radius+8));var high:Vector3i=work.field.cell(target.point+Vector3(target.chamber_radius+8,target.chamber_height+8,target.chamber_radius+8))
		for z in range(low.z,high.z+1):
			for y in range(low.y,high.y+1):
				for x in range(low.x,high.x+1):
					var key:=Vector3i(x,y,z);var result:Dictionary=Crystal.new().build(work.field,key,17,bundle.regions,load("res://config/caves/biomes/crystal_cave_definition.tres").feature_configuration,{})
					for reason:String in result.rejections:counts[reason]=int(counts.get(reason,0))+int(result.rejections[reason])
					for form:Dictionary in result.placements:
						if str(form.id).begins_with(str(target.id)+"/"):owned.append(form)
					payloads.append({"cell":key,"placements":result.placements.map(func(form:Dictionary)->Dictionary:return {"id":form.id,"kind":form.kind,"family":form.family,"root":form.root}),"rejections":result.rejections})
	var path:String="res://tools/biome_extensions/artifacts/diagnose_cave_crystal_owned_room.json";FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"room_assignments":rows,"original_candidate_dominant_nodes":dominant,"owned_forms":owned,"rejections":counts,"payloads":payloads,"scope":"Read-only diagnosis of original failed near1500m descriptor;no geometry/chance/seed/site or assertion changes."},"  "));print("OWNED_ROOM_DIAGNOSTIC rows=",rows," dominant_nodes=",dominant," owned=",owned.size()," rejections=",counts);quit(0 if failures.is_empty() else 1)
