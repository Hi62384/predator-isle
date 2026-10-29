extends SceneTree
func _initialize()->void:
	var hashes:Dictionary={"res://tools/biome_extensions/probe_debug_physical_pixels.gd":FileAccess.get_sha256("res://tools/biome_extensions/probe_debug_physical_pixels.gd")};var cases:Array=[]
	for mode:int in [0,7,18]:
		for light:String in ["default","alternate"]:
			var paths:Array[String]=[]
			for source:String in ["reference","production"]:
				var path:String="res://tools/biome_extensions/artifacts/debug_light_"+source+"_"+str(mode)+"_"+light+".png";paths.append(path);hashes[path]=FileAccess.get_sha256(path)
			var a:Image=Image.load_from_file(paths[0]);var b:Image=Image.load_from_file(paths[1]);var points:Array=[]
			for y in range(520,712):
				for x in range(8,1272):
					var c:Color=a.get_pixel(x,y);var d:Color=b.get_pixel(x,y);var error:float=maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))
					if error>2.0/255:points.append({"pixel":[x,y],"reference_rgb":[c.r,c.g,c.b],"production_rgb":[d.r,d.g,d.b],"maximum_channel_error":error})
			cases.append({"mode":mode,"light":light,"mismatched_pixels":points})
	FileAccess.open("res://tools/biome_extensions/artifacts/probe_debug_physical_pixels.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"source_sha256":hashes,"cases":cases,"scope":"Enumerates every >2-code mismatch in the failed physical debug-guard comparison's lower-ground rectangle. Diagnostic coordinates/values only; no acceptance, exclusion mask or tolerance change."},"  "))
	print("DEBUG_PHYSICAL_PIXELS ",cases);quit()
