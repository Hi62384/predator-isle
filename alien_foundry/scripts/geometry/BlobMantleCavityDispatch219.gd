extends RefCounted
## Narrow selector routing. Both original217 helpers remain byte-exact.
## Historical container names are shared; mode/version/spec own cache identity.
const Old = preload("res://alien_foundry/scripts/geometry/BlobMantleCavityPolicy217.gd")
const Host = preload("res://alien_foundry/scripts/geometry/BlobMantleCavityPolicy219.gd")
const SETTING: String = Old.SETTING
const PIN_SETTING: String = Old.PIN_SETTING
const KEY: String = Old.KEY
const MODE: String = Old.MODE
const OFF: String = Old.OFF
const PIN: String = Old.PIN
const IDS: Array[String] = Old.IDS
const DEPENDENCY4: String = Old.DEPENDENCY4

static func policy_for_options(options: Dictionary) -> GDScript:
	return Host if Old.text_is(options.get(SETTING), Host.MODE) else Old
static func policy_for(dna: Dictionary) -> GDScript:
	var settings: Variant = dna.get("settings", {})
	return policy_for_options(settings) if settings is Dictionary else Old
static func author_for(dna: Dictionary) -> GDScript:
	return load("res://alien_foundry/scripts/anatomy/BlobMantleCavityAuthor219.gd") if Host.enabled(dna) else load("res://alien_foundry/scripts/anatomy/BlobMantleCavityAuthor217.gd")
static func qualification_method(dna: Dictionary) -> String:
	return "fixed219_actual_tiled_finite_qualification_v1" if Host.enabled(dna) else "fixed217_actual_tiled_finite_qualification_v1"
static func enabled(dna: Dictionary) -> bool:
	return Old.enabled(dna) or Host.enabled(dna)
static func selection(options: Dictionary) -> Dictionary:
	return policy_for_options(options).selection(options)
static func validate_declaration(dna: Dictionary) -> Dictionary:
	return policy_for(dna).validate_declaration(dna)
static func validate_restored(dna: Dictionary) -> Dictionary:
	return policy_for(dna).validate_restored(dna)
static func positive_projection(dna: Dictionary) -> Dictionary:
	return policy_for(dna).positive_projection(dna)
static func text_is(value: Variant, expected: String) -> bool:
	return Old.text_is(value, expected)
static func integral(value: Variant) -> bool:
	return Old.integral(value)
