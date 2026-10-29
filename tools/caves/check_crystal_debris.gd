extends "res://tools/caves/check_crystal_features.gd"
const Previous:String="res://tools/biome_extensions/artifacts/revisions/experiment_render_cave_crystal_first_normal_geode_07b1a9904ab5/sources/scripts/caves/crystal_features.gd.txt"
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,Previous,"res://scripts/caves/crystal_features.gd","res://scripts/caves/crystal_surface.gd","res://scripts/caves/crystal_geometry.gd","res://scripts/caves/formations.gd","res://scripts/caves/field.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://tools/caves/check_crystal_features.gd","res://tools/caves/check_frozen_features.gd"]:guards[path]=FileAccess.get_sha256(path)
	var previous:=GDScript.new();previous.source_code=FileAccess.get_file_as_string(Previous);check(previous.reload()==OK,"Frozen complete pre-debris generator compiles independently")
	var region:Dictionary=crystal_fixture();var field=Field.new();field.include_surface_air=false
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	check(field.compile([region],height,[],region.cave_biome_regions),"Same original real protected chamber")
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");check(definition.validation_errors().is_empty(),"Independent debris/dust settings validate");var settings:Dictionary=definition.feature_configuration.duplicate();settings.density=1.0;settings.localized_veins=false;settings.corridor_growth=false;settings.luminous_minerals=false;settings.shallow_chambers=false;settings.lake_chambers=false;var seeds:Array=[73921,17,92881]
	for index in range(33):seeds.append(1000+index)
	var debris:int=0;var invalid:int=0;var off_mismatches:int=0;var major_changes:int=0;var records:Array=[]
	for seed_id:int in seeds:
		for key:Vector3i in [Vector3i.ZERO,Vector3i(0,1,0)]:
			var generator=Crystal.new();var result:Dictionary=generator.build(field,key,seed_id,[region],settings,{});var off:Dictionary=settings.duplicate();off.crystal_debris=false;var legacy:Dictionary=previous.new().build(field,key,seed_id,[region],off,{});var disabled:Dictionary=Crystal.new().build(field,key,seed_id,[region],off,{});var zero:Dictionary=settings.duplicate();zero.debris_chance=0.0;off_mismatches+=int(var_to_bytes(legacy)!=var_to_bytes(disabled) or var_to_bytes(disabled)!=var_to_bytes(Crystal.new().build(field,key,seed_id,[region],zero,{})));var placed:int=0
			check(result.valid and var_to_bytes(result)==var_to_bytes(Crystal.new().build(field,key,seed_id,[region],settings,{})),"Complete clast geometry/roots/UVs/LODs/collision cold-repeat deterministic")
			for original:Dictionary in legacy.placements:
				var same:Array=result.placements.filter(func(item:Dictionary)->bool:return item.id==original.id)
				major_changes+=int(same.size()!=1 or (same.size()==1 and var_to_bytes(same[0])!=var_to_bytes(original)))
			for item:Dictionary in result.placements:
				if item.kind!="crystal_debris":continue
				placed+=1;debris+=1;var bounds:AABB=item.bounds;invalid+=int(item.collider or item.thin_transmission or item.height>.85 or item.importance!=1 or item.family>3 or field.cell(item.root)!=key or generator.shapes.protected(field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,bounds.position.y,bounds.end.y))
				for foot:Vector3 in item.attachments:invalid+=int(field.sample(foot)<.15)
			check(placed<=16 and result.placements.size()<=160,"At most16fragments inside original160form budget;all original major forms generated first")
			records.append({"seed":seed_id,"cell":str(key),"debris":placed,"forms":result.placements.size()})
	check(debris>0 and invalid==0,"Positive broken tilted short minerals have measured buried feet,no route obstruction,no extra colliders or transmission")
	check(off_mismatches==0,"Complete frozen pre-debris payload restored byte-for-byte by independent OFF AND zero-chance controls")
	check(major_changes==0,"No existing major/root/vein/collider placement displaced or changed by later loose fragments")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable debris source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_debris.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"debris":debris,"invalid":invalid,"off_mismatches":off_mismatches,"major_changes":major_changes,"records":records,"scope":"Original36seed two-cell controlled breadth with original shape/route/caps,same six shared canonical prototypes(only elongated0..3used for loose clasts). Six-family cubic/rhombohedral proportions never distorted. Existing major placement records exact,measured feet,whole bounds,16fragment subcap inside160forms,complete frozen independent off/zero equality. Not normal occurrence/native dust shader images/FPS/all-user completion."},"  "));print("CRYSTAL_DEBRIS ",checks," debris=",debris," invalid=",invalid," off_mismatches=",off_mismatches," major_changes=",major_changes," failures=",failures);quit(0 if failures.is_empty() else 1)
