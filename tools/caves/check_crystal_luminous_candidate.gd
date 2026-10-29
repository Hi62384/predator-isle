extends "res://tools/caves/check_crystal_world_cohort.gd"
const Luminous=preload("res://tools/caves/crystal_luminous_candidate.gd")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/crystal_luminous_candidate.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var b=owner("crystal_wastes",73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original normal host/seed/definition for luminous mechanism");var bundle:Dictionary=work.discover(Vector2i(6,-2));check(not bundle.has("error"),"Actual normal shared discovery")
	var root:Vector3=Vector3(10095.06,-319.8502,-2163.919);var center:Vector3i=work.field.cell(root);var cells:Array=[];var selected:int=0;var total:int=0
	for offset:Vector3i in [Vector3i.ZERO,Vector3i.UP,Vector3i.RIGHT,Vector3i.FORWARD]:
		var key:Vector3i=center+offset;var payload:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,definition.feature_configuration,{});var before:PackedByteArray=var_to_bytes(payload);var controls:Dictionary={"luminous_minerals":true,"luminous_region_chance":1.0,"luminous_form_chance":1.0};var candidate:Dictionary=Luminous.apply(payload,bundle.regions,73921,controls);var off:Dictionary=controls.duplicate();off.luminous_minerals=false;var zero:Dictionary=controls.duplicate();zero.luminous_region_chance=0.0
		check(var_to_bytes(payload)==before and var_to_bytes(Luminous.apply(payload,bundle.regions,73921,off))==before and var_to_bytes(Luminous.apply(payload,bundle.regions,73921,zero))==before,"Input unchanged and complete independent OFF/zero payload exact")
		var cell_selected:int=0;var cell_total:int=0
		for index in range(payload.placements.size()):
			var original:Dictionary=payload.placements[index];var form:Dictionary=candidate.placements[index]
			if original.kind=="crystal":cell_total+=1
			if not form.get("fictional_emission",false):check(var_to_bytes(form)==var_to_bytes(original),"Every unselected original placement remains byte-exact");continue
			cell_selected+=1;check(form.kind=="crystal" and form.batch=="mineral_opaque" and not form.thin_transmission,"Only selected opaque prisms tagged;no dust/host rock/clear crystals");var stripped:Dictionary=form.duplicate(true);stripped.erase("fictional_emission");stripped.erase("fictional_region");check(var_to_bytes(stripped)==var_to_bytes(original),"Selected prism dimensions,contacts,bounds,collision and identity exact")
		check(cell_selected<=floori(cell_total*.1),"At least90percent of each cell's ordinary crystals remain untagged even in forced mechanism mode")
		for index in range(payload.batches.size()):
			var old:Dictionary=payload.batches[index];var fresh:Dictionary=candidate.batches[index];var decoded:Dictionary=fresh.duplicate(true);var uv:PackedVector2Array=decoded.arrays[Mesh.ARRAY_TEX_UV]
			for vertex in range(uv.size()):
				if uv[vertex].y<0:uv[vertex].y=-uv[vertex].y
			decoded.arrays[Mesh.ARRAY_TEX_UV]=uv;check(var_to_bytes(decoded)==var_to_bytes(old),"Complete geometry/normals/colors/growthUV/collider/LOD batches exact after decoding sole fictional flag")
		selected+=cell_selected;total+=cell_total;cells.append({"key":str(key),"crystals":cell_total,"selected":cell_selected})
	var rare_regions:int=0
	for index in range(100000):rare_regions+=int(Regions.random("distribution/"+str(index),73921,"crystal/fictional_region")<.005)
	check(rare_regions>=380 and rare_regions<=620,"Fixed100000stable region IDs retain rare.5percent admission within predeclared broad distribution bound")
	check(selected>0 and total>selected,"Actual normal-world prism payload provides positive forced mechanism and majority non-emissive crystals")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private luminous candidate "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_luminous_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cells":cells,"selected":selected,"ordinary_crystals":total,"rare_regions_per_100000":rare_regions,"scope":"PRIVATE same existing actual normal-world mineral payload;forced selection only tests mechanism,normal region chance.005/formchance.12 and hard10percent cell cap. Exact geometry/collision/LOD/off controls. No emission shader/native visual,normal-world luminous occurrence,production adoption or FPS claim."},"  "));print("CRYSTAL_LUMINOUS_CANDIDATE ",checks," selected=",selected," total=",total," distribution=",rare_regions," failures=",failures);quit(0 if failures.is_empty() else 1)
