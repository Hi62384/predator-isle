extends RefCounted
## Private post-process: very rare fictional regions,selected opaque prisms
## only. The thickness UV sign carries the flag losslessly;geometry stays intact.
const Regions=preload("res://scripts/caves/biome_regions.gd")
static func apply(payload:Dictionary,regions:Array,seed_id:int,settings:Dictionary)->Dictionary:
	if not settings.get("luminous_minerals",false) or float(settings.get("luminous_region_chance",.005))<=0 or float(settings.get("luminous_form_chance",.12))<=0:return payload
	var themes:Dictionary={}
	for region:Dictionary in regions:
		if not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:continue
		var rare:Dictionary={}
		for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
			if str(candidate.biome_id)=="crystal" and Regions.random(str(candidate.id),seed_id,"crystal/fictional_region")<float(settings.get("luminous_region_chance",.005)):rare[str(candidate.id)]=true
		if rare.is_empty():continue
		for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
			var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(room.id),str(room.id),0,0)
			var theme:String=str(assignment.candidate_ids.get("crystal",""))
			if float(assignment.weights.get("crystal",0))>=.8 and rare.has(theme):themes[str(room.id)]=theme
	if themes.is_empty():return payload
	var choices:Array=[];var total:int=0
	for index in range(payload.get("placements",[]).size()):
		var form:Dictionary=payload.placements[index]
		if form.get("kind","")!="crystal":continue
		total+=1
		if form.get("thin_transmission",false) or form.get("batch","")!="mineral_opaque":continue
		var theme:String=""
		for room_id:String in themes:
			if str(form.id).begins_with(room_id+"/"):theme=themes[room_id];break
		if theme.is_empty() or Regions.random(str(form.id),seed_id,"crystal/fictional_prism")>=float(settings.get("luminous_form_chance",.12)):continue
		choices.append({"index":index,"theme":theme,"priority":Regions.random(str(form.id),seed_id,"crystal/fictional_priority")})
	choices.sort_custom(func(a,b):return a.priority<b.priority or (a.priority==b.priority and a.index<b.index));var maximum:int=floori(total*.1)
	if choices.size()>maximum:choices.resize(maximum)
	if choices.is_empty():return payload
	var result:Dictionary=payload.duplicate(true)
	for choice:Dictionary in choices:
		var form:Dictionary=result.placements[choice.index];form["fictional_emission"]=true;form["fictional_region"]=choice.theme
		for batch:Dictionary in result.batches:
			if str(batch.get("kind",""))!=str(form.batch):continue
			var uv:PackedVector2Array=batch.arrays[Mesh.ARRAY_TEX_UV]
			for vertex in range(form.first_vertex,form.first_vertex+form.vertex_count):uv[vertex].y=-uv[vertex].y
			batch.arrays[Mesh.ARRAY_TEX_UV]=uv
	return result
