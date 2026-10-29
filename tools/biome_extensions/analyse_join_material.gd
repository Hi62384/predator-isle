extends SceneTree
func _initialize()->void:
	var hashes:Dictionary={"res://tools/biome_extensions/analyse_join_material.gd":FileAccess.get_sha256("res://tools/biome_extensions/analyse_join_material.gd")};var records:Array=[]
	for kind:String in ["medium","ground","sunlit","albedo_ground"]:
		var paths:Array[String]=[]
		for label:String in ["original","candidate"]:
			var path:String="res://tools/biome_extensions/artifacts/join_tissue_"+label+"_"+kind+".png";paths.append(path);hashes[path]=FileAccess.get_sha256(path)
		var a:Image=Image.load_from_file(paths[0]);var b:Image=Image.load_from_file(paths[1]);assert(a!=null and b!=null and a.get_size()==Vector2i(1280,720) and b.get_size()==a.get_size())
		var changed:int=0;var changed_ground:int=0;var maximum:float=0;var ground_sum:float=0;var ground_pixels:int=0
		for y in range(720):
			for x in range(1280):
				var c:Color=a.get_pixel(x,y);var d:Color=b.get_pixel(x,y);var error:float=maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)));maximum=maxf(maximum,error)
				if error>2.0/255:changed+=1
				if y>=520:
					ground_pixels+=1;ground_sum+=error
					if error>2.0/255:changed_ground+=1
		var record:Dictionary={"view":kind,"changed_pixels_over_two_codes":changed,"maximum_rgb_difference":maximum,"lower_200_rows_changed_pixels":changed_ground,"lower_200_rows_pixels":ground_pixels,"lower_200_rows_mean_max_channel_difference":ground_sum/ground_pixels};records.append(record)
	FileAccess.open("res://tools/biome_extensions/artifacts/analyse_join_material.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"source_sha256":hashes,"records":records,"scope":"Exact image differences for the preserved private terrain-only blend study, full frame and lower 200 image rows. Does not identify a geometric seam or constitute improvement/acceptance; dynamic water/sky and shader/draw effects can also change pixels."},"  "))
	print("JOIN_MATERIAL_PIXELS ",records);quit()
