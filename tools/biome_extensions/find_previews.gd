extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var manifest:Dictionary={"seed":73921,"families":{}}
	for family_id in range(8):
		var b=make_builder(family_id);var sampler=b._extras[family_id];var features:Dictionary={};var primary:Dictionary={}
		for z in range(-12,13):
			for x in range(-12,13):
				var span:float=[3200,2100,7200,1800,4400,1700,2100,4096][family_id]
				var d:Dictionary=sampler.descriptor(Vector2i(x,z),span);var p:Vector2=sampler.hive_node(Vector2i(x,z)) if family_id==7 else d.position
				if b._island_mask(p.x,p.y)<.1:continue
				var description:Dictionary=sampler.describe(p);var region:int=clampi(roundi(description.region),0,5)
				var record:Dictionary={"x":p.x,"z":p.y,"height":b._get_height(p.x,p.y),"regional_name":sampler.NAMES[region],"descriptor":description}
				if not features.has(str(region)):features[str(region)]=record
				if primary.is_empty():
					var suitable:bool=false
					match family_id:
						0:suitable=d.chance<sampler.settings.excavation_frequency and description.feature>.6 and description.height<180
						1:suitable=region==0 and description.height>350
						2:suitable=region<=2 and description.height>350
						3:suitable=region==1 and description.feature>.55
						4:suitable=region==1 and description.feature>.6
						5:suitable=d.chance<sampler.settings.structure_density and description.height>10
						6:suitable=region==0 and d.chance<sampler.settings.structure_density
						7:suitable=d.chance<sampler.settings.structure_density and description.height>10
					if suitable:primary=record
		if primary.is_empty():primary=features.values()[0]
		manifest.families[TerrainSettings.EXTENSION_KEYS[family_id]]={"primary":primary,"regions":features,"supported_regions":sampler.NAMES}
		print("EXTENSION_PREVIEW ",TerrainSettings.EXTENSION_KEYS[family_id]," ",primary.x,",",primary.z," ",primary.regional_name)
	FileAccess.open("res://tools/biome_extensions/artifacts/previews.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"));quit()
