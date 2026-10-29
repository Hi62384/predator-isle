extends "res://tools/caves/check_crystal_world_cohort.gd"
const Previous:String="res://tools/biome_extensions/artifacts/revisions/experiment_render_cave_crystal_first_normal_geode_sediment_e8743ddc3e72/sources/scripts/caves/crystal_features.gd.txt"
const Exposure=preload("res://scripts/caves/crystal_vein_exposure.gd")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,Previous,"res://tools/caves/check_crystal_world_cohort.gd","res://shaders/cave_crystal_surface.gdshaderinc","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var previous:=GDScript.new();previous.source_code=FileAccess.get_file_as_string(Previous);check(previous.reload()==OK,"Independent frozen pre-localization complete worker generator compiles")
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var b=owner("crystal_wastes",73921);var work=Workload.new();work.configure(b.settings,config,73921,0);var records:Array=[]
		for target:Dictionary in [{"profile":"geode","site":Vector2i(6,-2),"id":"6:-2:2:0:crystal:geode:1"},{"profile":"ravine","site":Vector2i(8,-4),"id":"8:-4:2:2:crystal:ravine:0"}]:
			var bundle:Dictionary=work.discover(target.site);var room:Dictionary={}
			for region:Dictionary in bundle.get("regions",[]):
				for item:Dictionary in region.get("pockets",[]):
					if item.id==target.id:room=item
			var record:Dictionary={"profile":target.profile,"found":not room.is_empty(),"cells":0,"off_mismatches":0,"old_veins":0,"localized_veins":0,"invalid_exposures":0,"invalid_payloads":0,"invalid_roots":0,"blocked_routes":0,"old_majors":0,"lost_or_changed_old_majors":0,"maximum_cell_vertices":0}
			if not room.is_empty():
				var center:Vector3i=work.field.cell(room.point+Vector3.UP*2);var off:Dictionary=definition.feature_configuration.duplicate();off.localized_veins=false;off.corridor_growth=false;off.luminous_minerals=false;off.shallow_chambers=false;off.lake_chambers=false
				for dz in range(-1,2):
					for dy in range(-1,2):
						for dx in range(-1,2):
							var key:Vector3i=center+Vector3i(dx,dy,dz);var legacy:Dictionary=previous.new().build(work.field,key,73921,bundle.regions,off,{});var disabled:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,off,{});var current:Dictionary=Crystal.new().build(work.field,key,73921,bundle.regions,definition.feature_configuration,{});record.cells+=1;record.off_mismatches+=int(var_to_bytes(legacy)!=var_to_bytes(disabled));record.invalid_payloads+=int(not current.valid);var by_id:Dictionary={};var vertices:int=0
							for item:Dictionary in current.placements:
								by_id[item.id]=item
								if item.kind=="mineral_vein":record.localized_veins+=1;record.invalid_exposures+=int(Exposure.amount(item.root)<.2)
								for foot:Vector3 in item.attachments:record.invalid_roots+=int(work.field.sample(foot)<.15)
								var bounds:AABB=item.bounds;record.blocked_routes+=int(Crystal.new().shapes.protected(work.field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,bounds.position.y,bounds.end.y))
							for item:Dictionary in legacy.placements:
								if item.kind=="mineral_vein":record.old_veins+=1
								if item.kind!="crystal":continue
								record.old_majors+=1
								if not by_id.has(item.id):record.lost_or_changed_old_majors+=1;continue
								for property:String in ["root","axis","height","width","family","broken","age","importance","thin_transmission","collider","attachments","bounds"]:record.lost_or_changed_old_majors+=int(var_to_bytes(by_id[item.id][property])!=var_to_bytes(item[property]))
							for batch:Dictionary in current.batches:vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
							record.maximum_cell_vertices=maxi(record.maximum_cell_vertices,vertices)
			records.append(record)
		output.append(records)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var records:Array=output[0] if not output.is_empty() else [];check(records.size()==2,"Both original normal profile neighborhoods retained");var old_veins:int=0;var new_veins:int=0
	for record:Dictionary in records:
		check(record.found and record.cells==27 and record.off_mismatches==0,"Complete54cell frozen pre-localization payloads restored byte-for-byte by feature switch OFF")
		check(record.invalid_payloads==0 and record.maximum_cell_vertices<=60000 and record.invalid_exposures==0 and record.invalid_roots==0 and record.blocked_routes==0,"Localized positive veins have actual global exposure,buried feet and original route/vertex bounds")
		check(record.old_majors>0 and record.lost_or_changed_old_majors==0,"No existing major crystal/root/shape/collider lost or altered when unexposed vein segments are removed")
		old_veins+=record.old_veins;new_veins+=record.localized_veins
	check(new_veins>0 and new_veins<old_veins,"Actual original54cells retain positive localized real veins and reduce wrapped band geometry")
	for point:Vector3 in [Vector3(13,27,41),Vector3(-46279,-381,-52941),Vector3(9871,-240,-2308)]:
		for offset:Vector3 in [Vector3(3840,0,0),Vector3(0,-3840,0),Vector3(0,0,3840)]:check(absf(Exposure.amount(point)-Exposure.amount(point+offset))<.000001,"Same physical exposure across positive/negative macro origins")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable localization source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_vein_localization.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"old_veins":old_veins,"localized_veins":new_veins,"scope":"Original normal geode/ravine54cells,complete independently frozen OFF equality,retained existing major roots/dimensions/contacts/colliders,localized positive real veins,whole route/root/vertex bounds and signed macro-periodic physical exposure. Removing veins may permit additional previously budget-limited major forms,not asserted byte-identical ON payloads or physical traversal/FPS/art completion."},"  "));print("CRYSTAL_VEIN_LOCALIZATION ",checks," old=",old_veins," localized=",new_veins," records=",records," failures=",failures);quit(0 if failures.is_empty() else 1)
