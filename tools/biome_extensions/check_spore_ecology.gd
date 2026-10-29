extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var records:Array=[]
	for seed_id:int in [73921,17041,98123]:
		var b=make_builder(3,seed_id);var sampler=b._extras[3];var saved_frequency:float=sampler.settings.luminous_frequency
		var bright:int=0;var samples:Array=[]
		for z in range(-4,5):
			for x in range(-4,5):
				var d:Dictionary=sampler.descriptor(Vector2i(x,z),1800*sampler.settings.feature_scale);var p:Vector2=d.position
				var field:Dictionary=sampler.ecology(p).duplicate();sampler.sample(p.x,p.y)
				check(field.coverage>=0 and field.coverage<=1,"Bounded fungal union")
				check(field.luminous>=0 and field.luminous<=field.coverage+.001,"Light belongs to actual colony")
				if sampler.state[4]>.5:bright+=1
				samples.append([p,field])
		check(bright>0,"Default-frequency actual luminous colonies in seed "+str(seed_id))
		samples.reverse()
		for record:Array in samples:check(sampler.ecology(record[0])==record[1],"Order-independent colony network")
		sampler.settings.luminous_frequency=0;sampler.configure(sampler.settings,seed_id,b,3)
		for record:Array in samples:
			sampler.sample(record[0].x,record[0].y)
			check(sampler.state[4]<=.5,"Zero luminous frequency cannot publish luminous material")
			check(sampler.ecology(record[0]).luminous==0,"Zero luminous descriptor signal")
		# Mound geometry and lighting share ecology, but disabling glow must not
		# alter the physical height or turn it into a separate terrain category.
		var p:Vector2=samples[0][0];var h:float=sampler.sample(p.x,p.y)
		sampler.settings.luminous_frequency=saved_frequency;sampler.configure(sampler.settings,seed_id,b,3)
		check(h==sampler.sample(p.x,p.y),"Luminous setting does not alter geometry")
		records.append({"seed":seed_id,"centres":samples.size(),"luminous_centres":bright,"default_frequency":saved_frequency})
	FileAccess.open("res://tools/biome_extensions/artifacts/check_spore_ecology.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":records,"scope":"Colony union, deterministic overlap, bounded signals, default/disabled luminous control; not artistic acceptance"},"\t"))
	print("SPORE_ECOLOGY ",checks," ",failures);quit(0 if failures.is_empty() else 1)
