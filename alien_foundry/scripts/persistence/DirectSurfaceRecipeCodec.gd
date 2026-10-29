extends RefCounted
## Direct-carrier recipes use the established v2 exact numeric transport, without
## changing the body projection or BlobIterationArtifacts' legacy codec.
const VERSION := 2
const ENCODING := "exact_i64_decimal_and_little_endian_ieee754_f64_hex"
const SHADOW := "exact_or_godot_full_precision_json_v1"
const MAX_VALUES := 100000

static func seal(recipe: Dictionary) -> Dictionary:
	if not _valid(recipe, 0, [MAX_VALUES]): return _failure("Unsupported direct-surface recipe value.")
	var entries: Array = []
	_numbers(recipe, [], entries)
	return {"ok": true, "numeric_recipe": {"version": VERSION, "encoding": ENCODING, "shadow_contract": SHADOW, "numbers": entries}, "recipe_key": typed_key(recipe)}

static func decode(recipe: Variant, numeric_recipe: Variant) -> Dictionary:
	if not recipe is Dictionary or not _valid(recipe, 0, [MAX_VALUES]): return _failure("Invalid direct-surface recipe object.")
	if not numeric_recipe is Dictionary or not _keys_are(numeric_recipe, ["version", "encoding", "shadow_contract", "numbers"]): return _failure("Invalid direct-surface numeric seal.")
	if numeric_recipe.get("version") != VERSION or numeric_recipe.get("encoding") != ENCODING or numeric_recipe.get("shadow_contract") != SHADOW or not numeric_recipe.get("numbers") is Array:
		return _failure("Missing supported exact direct-surface numeric recipe.")
	var restored: Dictionary = recipe.duplicate(true)
	var observed: Array = []
	_numbers(restored, [], observed)
	if observed.size() != numeric_recipe.numbers.size(): return _failure("Direct-surface numeric recipe has stale or missing fields.")
	for i in range(observed.size()):
		var item: Variant = numeric_recipe.numbers[i]
		if not item is Dictionary or not _keys_are(item, ["path", "kind", "value"]) or not item.get("path") is Array or not _same_path(item.path, observed[i].path) or not item.get("value") is String:
			return _failure("Invalid exact direct-surface recipe path.")
		var target: Variant = restored
		for step in observed[i].path.slice(0, -1): target = target[int(step)] if target is Array else target[step]
		var key: Variant = int(observed[i].path[-1]) if target is Array else observed[i].path[-1]
		var value: Variant = target[key]
		if item.kind == "i64":
			if not item.value.is_valid_int(): return _failure("Invalid exact direct-surface integer.")
			var exact: int = item.value.to_int()
			if str(exact) != item.value: return _failure("Non-canonical or overflowing direct-surface integer.")
			if (value is int and value != exact) or (value is float and (not is_finite(value) or value != float(exact))): return _failure("Direct-surface integer differs from its seal; reauthor explicitly.")
			target[key] = exact
		elif item.kind == "f64":
			var bytes: PackedByteArray = item.value.hex_decode()
			if bytes.size() != 8 or bytes.hex_encode() != item.value: return _failure("Non-canonical exact direct-surface floating value.")
			var exact: float = bytes.decode_double(0)
			if not is_finite(exact): return _failure("Non-finite direct-surface recipe number.")
			var actual := PackedByteArray(); actual.resize(8); actual.encode_double(0, float(value))
			var matches: bool = actual == bytes
			if not matches:
				var public_value: Variant = JSON.parse_string(JSON.stringify(exact, "", true, true))
				if public_value is int or public_value is float:
					var public_bytes := PackedByteArray(); public_bytes.resize(8); public_bytes.encode_double(0, float(public_value))
					matches = actual == public_bytes
			if not matches: return _failure("Direct-surface floating value differs from its seal; reauthor explicitly.")
			target[key] = exact
		else: return _failure("Unsupported exact direct-surface numeric kind.")
	return {"ok": true, "recipe": restored, "recipe_key": typed_key(restored)}

static func canonical_key(recipe: Variant, numeric_recipe: Variant) -> String:
	var decoded: Dictionary = decode(recipe, numeric_recipe)
	return "" if not decoded.get("ok", false) else str(decoded.recipe_key)

static func typed_key(value: Variant) -> String:
	# Sorted dictionary keys and explicit scalar kinds, not Dictionary insertion
	# order or JSON's conversion of integral values to floating point.
	if not _valid(value, 0, [MAX_VALUES]): return ""
	return JSON.stringify(_typed(value), "", true, true).sha256_text()

static func _typed(value: Variant) -> Variant:
	if value is Dictionary:
		var rows: Array = []; var keys: Array = value.keys(); keys.sort()
		for key: String in keys: rows.append([key, _typed(value[key])])
		return ["object", rows]
	if value is Array:
		var values: Array = []
		for child in value: values.append(_typed(child))
		return ["array", values]
	if value is int: return ["i64", str(value)]
	if value is float:
		var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0, value)
		return ["f64", bytes.hex_encode()]
	if value is String: return ["string", value]
	if value is bool: return ["bool", value]
	return ["null"]

static func _numbers(value: Variant, path: Array, output: Array) -> void:
	if value is Dictionary:
		var keys: Array = value.keys(); keys.sort()
		for key: String in keys: _numbers(value[key], path + [key], output)
	elif value is Array:
		for i in range(value.size()): _numbers(value[i], path + [i], output)
	elif value is int: output.append({"path": path, "kind": "i64", "value": str(value)})
	elif value is float:
		var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0, value)
		output.append({"path": path, "kind": "f64", "value": bytes.hex_encode()})

static func _same_path(authored: Array, actual: Array) -> bool:
	if authored.size() != actual.size(): return false
	for i in range(actual.size()):
		if actual[i] is int:
			if not (authored[i] is int or authored[i] is float) or not is_finite(float(authored[i])) or float(authored[i]) != float(int(authored[i])) or int(authored[i]) != actual[i]: return false
		elif not authored[i] is String or authored[i] != actual[i]: return false
	return true

static func _keys_are(value: Dictionary, names: Array) -> bool:
	var keys: Array = value.keys(); keys.sort(); names.sort()
	return keys == names

static func _valid(value: Variant, depth: int, remaining: Array) -> bool:
	remaining[0] -= 1
	if depth > 48 or remaining[0] < 0: return false
	if value == null or value is bool: return true
	if value is int or value is float: return is_finite(float(value))
	if value is String: return value.length() <= 1048576
	if value is Array:
		for child in value:
			if not _valid(child, depth + 1, remaining): return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or key.length() > 4096 or not _valid(value[key], depth + 1, remaining): return false
		return true
	return false

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
