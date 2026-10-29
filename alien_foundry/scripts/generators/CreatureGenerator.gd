extends RefCounted
## Public, thread-safe generation entry. Each call owns its RNG and graph.
const DNA = preload("res://alien_foundry/scripts/anatomy/CreatureDNA.gd")
const Lineage = preload("res://alien_foundry/scripts/anatomy/CreatureLineage.gd")
const Blob = preload("res://alien_foundry/scripts/generators/BlobGenerator.gd")
const Crawler = preload("res://alien_foundry/scripts/generators/CrawlerGenerator.gd")
const Humanoid = preload("res://alien_foundry/scripts/generators/HumanoidGenerator.gd")
const Abomination = preload("res://alien_foundry/scripts/generators/AbominationGenerator.gd")
const Beast = preload("res://alien_foundry/scripts/generators/BeastGenerator.gd")
const Slitherer = preload("res://alien_foundry/scripts/generators/SlithererGenerator.gd")
const Combination = preload("res://alien_foundry/scripts/generators/CombinationGenerator.gd")
const BASE_TYPES := ["Blob","Crawler","Humanoid","Abomination","Beast","Slitherer"]

func generate(creature_type: String, seed_value: int, options: Dictionary = {}) -> Dictionary:
	if options.get("blob_direct_surface_profile", "off") != "off" and creature_type.capitalize() != "Blob":
		return {"error": "Direct vascular surfaces are supported only in the bounded Blob iterative profile."}
	var checked := Lineage.validate_json(options)
	if not checked["ok"]:
		var rejected := DNA.create(creature_type.capitalize(),seed_value,{})
		rejected["validation"]={"valid":false,"errors":[checked["error"]]}
		return rejected
	return _generate(creature_type.capitalize(),seed_value,DNA.normalize_settings(options),0)

## Blob pipeline contract. Other families keep their existing generator path.
func generate_stages(creature_type: String, seed_value: int, options: Dictionary = {}) -> Dictionary:
	if creature_type.capitalize() != "Blob":
		return {"error": "The staged anatomy pipeline is currently implemented for Blob only."}
	var checked := Lineage.validate_json(options)
	if not bool(checked.get("ok", false)):
		return checked
	return Blob.new().generate_stages(seed_value, DNA.normalize_settings(options))

func _generate(creature_type: String, seed_value: int, settings: Dictionary, depth: int) -> Dictionary:
	match creature_type:
		"Blob": return Blob.new().generate(seed_value,settings)
		"Crawler": return Crawler.new().generate(seed_value,settings)
		"Humanoid": return Humanoid.new().generate(seed_value,settings)
		"Abomination": return Abomination.new().generate(seed_value,settings)
		"Beast": return Beast.new().generate(seed_value,settings)
		"Slitherer": return Slitherer.new().generate(seed_value,settings)
		"Combination":
			var source_options:=settings.duplicate(true)
			source_options["size"]=1.0
			source_options.erase("source_a"); source_options.erase("source_b")
			var rng:=RandomNumberGenerator.new(); rng.seed=seed_value
			var first_type:=str(settings.get("first_type","Blob")) if depth==0 else str(BASE_TYPES[rng.randi_range(0,5)])
			var second_type:=str(settings.get("second_type","Humanoid")) if depth==0 else str(BASE_TYPES[rng.randi_range(0,5)])
			if depth>=2:
				first_type=BASE_TYPES[rng.randi_range(0,5)]; second_type=BASE_TYPES[rng.randi_range(0,5)]
			var first_seed:=int(settings.get("first_seed",seed_value+101)) if depth==0 else seed_value+101
			var second_seed:=int(settings.get("second_seed",seed_value+307)) if depth==0 else seed_value+307
			var first: Dictionary=settings.get("source_a",{}) if depth==0 else {}
			var second: Dictionary=settings.get("source_b",{}) if depth==0 else {}
			if not DNA.is_dna(first): first=_generate(first_type.capitalize(),first_seed,source_options,depth+1)
			if not DNA.is_dna(second): second=_generate(second_type.capitalize(),second_seed,source_options,depth+1)
			return Combination.new().combine(first,second,str(settings.get("method","Fusion")),seed_value,settings)
	var failed:=DNA.create(creature_type,seed_value,settings)
	failed["validation"]={"valid":false,"errors":["Unknown creature type: "+creature_type]}
	return failed
