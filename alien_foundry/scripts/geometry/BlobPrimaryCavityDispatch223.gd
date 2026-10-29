extends RefCounted
##223 explicit single-primary selector route; historical selectors stay exact.
const Previous = preload("res://alien_foundry/scripts/geometry/BlobMantleCavityDispatch221.gd")
const Single = preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityPolicy223.gd")
const SETTING: String = Previous.SETTING
const PIN_SETTING: String = Previous.PIN_SETTING
const KEY: String = Previous.KEY
const MODE: String = Previous.MODE
const OFF: String = Previous.OFF
const PIN: String = Previous.PIN
const IDS: Array[String] = Previous.IDS
const DEPENDENCY4: String = Previous.DEPENDENCY4
static func single_enabled(dna: Dictionary) -> bool: return Single.enabled(dna)
static func ids_for(dna: Dictionary) -> Array[String]:
	return Single.IDS if Single.enabled(dna) else Previous.IDS
static func policy_for_options(options: Dictionary) -> GDScript:
	return Single if Previous.text_is(options.get(SETTING),Single.MODE) else Previous.policy_for_options(options)
static func policy_for(dna: Dictionary) -> GDScript:
	var settings: Variant = dna.get("settings",{})
	return policy_for_options(settings) if settings is Dictionary else Previous.policy_for(dna)
static func author_for(dna: Dictionary) -> GDScript:
	return load("res://alien_foundry/scripts/anatomy/BlobPrimaryCavityAuthor223.gd") if Single.enabled(dna) else Previous.author_for(dna)
static func qualification_method(dna: Dictionary) -> String:
	return "fixed223_actual_tiled_single_qualification_v1" if Single.enabled(dna) else Previous.qualification_method(dna)
static func enabled(dna: Dictionary) -> bool: return Single.enabled(dna) or Previous.enabled(dna)
static func selection(options: Dictionary) -> Dictionary: return policy_for_options(options).selection(options)
static func validate_declaration(dna: Dictionary) -> Dictionary: return policy_for(dna).validate_declaration(dna)
static func validate_restored(dna: Dictionary) -> Dictionary: return policy_for(dna).validate_restored(dna)
static func positive_projection(dna: Dictionary) -> Dictionary: return policy_for(dna).positive_projection(dna)
static func text_is(value: Variant, expected: String) -> bool: return Previous.text_is(value,expected)
static func integral(value: Variant) -> bool: return Previous.integral(value)
