extends RefCounted
## Versioned shared-pair routing; both original217 and219 helpers stay exact.
const Previous = preload("res://alien_foundry/scripts/geometry/BlobMantleCavityDispatch219.gd")
const Pair = preload("res://alien_foundry/scripts/geometry/BlobMantleCavityPolicy221.gd")
const SETTING: String = Previous.SETTING
const PIN_SETTING: String = Previous.PIN_SETTING
const KEY: String = Previous.KEY
const MODE: String = Previous.MODE
const OFF: String = Previous.OFF
const PIN: String = Previous.PIN
const IDS: Array[String] = Previous.IDS
const DEPENDENCY4: String = Previous.DEPENDENCY4

static func policy_for_options(options: Dictionary) -> GDScript:
	return Pair if Previous.text_is(options.get(SETTING),Pair.MODE) else Previous.policy_for_options(options)
static func policy_for(dna: Dictionary) -> GDScript:
	var settings: Variant = dna.get("settings",{})
	return policy_for_options(settings) if settings is Dictionary else Previous.policy_for(dna)
static func author_for(dna: Dictionary) -> GDScript:
	return load("res://alien_foundry/scripts/anatomy/BlobMantleCavityAuthor221.gd") if Pair.enabled(dna) else Previous.author_for(dna)
static func qualification_method(dna: Dictionary) -> String:
	return "fixed221_actual_tiled_finite_qualification_v1" if Pair.enabled(dna) else Previous.qualification_method(dna)
static func enabled(dna: Dictionary) -> bool:
	return Pair.enabled(dna) or Previous.enabled(dna)
static func selection(options: Dictionary) -> Dictionary:
	return policy_for_options(options).selection(options)
static func validate_declaration(dna: Dictionary) -> Dictionary:
	return policy_for(dna).validate_declaration(dna)
static func validate_restored(dna: Dictionary) -> Dictionary:
	return policy_for(dna).validate_restored(dna)
static func positive_projection(dna: Dictionary) -> Dictionary:
	return policy_for(dna).positive_projection(dna)
static func text_is(value: Variant,expected: String) -> bool:
	return Previous.text_is(value,expected)
static func integral(value: Variant) -> bool:
	return Previous.integral(value)
