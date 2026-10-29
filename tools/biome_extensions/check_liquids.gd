extends "res://tools/biome_extensions/check_all.gd"
const Features=preload("res://scripts/terrain_feature_meshes.gd")
func run()->void:
	var cases:Array=[]
	for family_id:int in [2,7]:
		var b=make_builder(family_id);b.chunk_size=8192;b.settings.get(TerrainSettings.EXTENSION_KEYS[family_id]).caves_enabled=false
		b._configure_noise();var count:int=0
		for i in range(4096):
			var cell:=Vector2i(i%64-32,i/64-32);var output:Dictionary=Features.new().build(b,cell)
			for liquid:Dictionary in output.liquids:cases.append(liquid);count+=1
			var surface:Array=output.surfaces[1 if family_id==2 else 2]
			if surface.is_empty():continue
			var origin:=Vector3(cell.x*8192,0,cell.y*8192)
			for v:Vector3 in surface[Mesh.ARRAY_VERTEX]:
				var p:Vector3=v+origin;check(p.y>b._get_height(p.x,p.z)-.1,"Liquid clipped against actual ground");check(p.y>b.water_level+2,"No ocean substitution")
			if count>=2:break
		check(count>0,"Actual retained liquid surfaces "+str(family_id))
	FileAccess.open("res://tools/biome_extensions/artifacts/check_liquids.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"active_lava_frequency":.04,"note":"Default production source frequency and clipping; not a fluid simulation"},"\t"));print("LIQUID_CHECKS ",checks," ",failures);quit(0 if failures.is_empty() else 1)
