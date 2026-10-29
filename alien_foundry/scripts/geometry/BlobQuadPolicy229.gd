extends RefCounted
## Explicit229 extraction recipe. Never an ignored extra field on legacy DNA.
## This additive entry point does not change any existing serializer or route.
const FORMAT: String = "predator-isle-quad-recipe229"
const VERSION: int = 1
const MODE: String = "max_min_field_alignment_v1"
const PIN: String = "1acfed7a1bfbb0196783f53d7bb4a264aca84a2198a38e6e4cb98bd2e9202080"
const SOURCE_RAW_SHA: String = "6140ac5eb9b49eebc67f78f521fc60dfb6655d1e1de05766b87abf944f82e572"
const SOURCE_KEY: String = "c62a719694d5c35573b4d0b4e5154f39e3b7e7f77b744310f3d5b5a9d0c0c236"
const DEPENDENCY_KEY: String = "cf33780f55a7d8b0f8a6aa98f7eefdcc573cfe076bedd250e2ebda5cffadb464"
const ARTIFACT_KEY: String = "cbc35e769708e4b1334878a6e8027ce992c85414b30fd446abf4e48330223696"
const SOURCE_GRID: Vector3i = Vector3i(80, 76, 86)
const SOURCE_VERTICES: int = 17958
const SOURCE_FACES: int = 35912
const SOURCE_AXES_HEX: Array = ["364a14c0805d10c0ca700cc0148408c05f9704c0a9aa00c0e67bf9bf7aa2f1bf0fc9e9bfa3efe1bf3816dabfcc3cd2bf6063cabff489c2bf89b0babf1dd7b2bfb2fdaabf4624a3bfda4a9bbf6f7193bf03988bbf97be83bf58ca77bf801768bfa86458bfd2b148bf66d840bffafe38bf8e2531bf224c29bf4c9919bf74e609bf3867f4be8c01d5bedc9bb5be303696be00a16dbea0d52ebe8014e0bd80fb44bd00c7583c80c8333da0af983d007bd73d30230b3e90ee493ef85c843ea8c2a33e5028c33e008ee23ed8f9003fb0ac103f885f203f6012303f34c53f3f0c784f3fe42a5f3fbcdd6e3f94907e3fb621873f20fb8e3f8cd4963ff8ad9e3f6487a63fd060ae3f3c3ab63fa613be3f12edc53f7ec6cd3fea9fd53f5479dd3fc052e53f2c2ced3f9805f53f04dffc3f385c0240ee480640a4350a405a220e40100f1240", "7a33ccbf0e5ac4bfa380bcbf37a7b4bfcbcdacbf60f4a4bff41a9dbf884195bf1d688dbfb18e85bf8b6a7bbfb4b76bbfdc045cbf05524cbf2e9f3cbf56ec2cbf7f391dbfa8860dbfa0a7fbbef441dcbe44dcbcbe94769dbed0217cbe70563dbe2016fdbde0fe7ebd005874ba205c773dc044f93dc06d3b3e20397a3e3c829c3eece7bb3e984ddb3e48b3fa3e7c0c0d3f54bf1c3fc098243f2c722c3f00253c3fd8d74b3fb08a5b3f1c64633f883d6b3ff416733f60f07a3f9c51853f062b8d3f7204953fdedd9c3f4ab7a43fb690ac3f226ab43f8c43bc3ff81cc43f64f6cb3fd0cfd33f3ca9db3fa882e33f125ceb3f7e35f33fea0efb3f2b740140e1600540974d09404c3a0d4002271140b81315406e00194023ed1c40d9d920408fc6244045b32840fb9f2c40b18c304067793440", "a67329c0f08625c03a9a21c084ad1dc0cfc019c019d415c063e711c0adfa0dc0f70d0ac0422106c08c3402c0ac8ffcbf40b6f4bfd4dcecbf6903e5bffd29ddbf9250d5bf2677cdbfba9dc5bf4fc4bdbfe3eab5bf7711aebf0c38a6bfa05e9ebf348596bfc9ab8ebf5dd286bfe2f17dbf0c3f6ebf348c5ebf5cd94ebf86263fbfae732fbfd8c01fbf000e10bf285b00bfa050e1bef0eac1be4885a2be70d292be981f83bed07347be70a808be20ba93bd001b31bcc09fa23c80e64e3d000ae53d6050313ec01b703e9073973e40d9b63ee83ed63ec0f1e53e98a4f53eb8ab023f24850a3ffc371a3fd4ea293fac9d393f8050493f5803593f30b6683f0869783ff00d843f5ce78b3fc6c0933f329a9b3f9e73a33f0a4dab3f7426b33fe0ffba3f4cd9c23fb8b2ca3f248cd23f9065da3ffc3ee23f6818ea3fd4f1f13f40cbf93f54d200400abf0440c0ab084076980c402c851040e2711440"]
const CELL_BITS: String = "8d0a65a2ae65af3f"
const ORIGIN_BITS: String = "364a14c07a33ccbfa67329c0"
const VERTEX_CAP: int = 60000
const TRIANGLE_CAP: int = 100000
const SAMPLE_CAP: int = 560000
const MAX_ARTIFACT_BYTES: int = 32 * 1024 * 1024
const MAX_RECIPE_BYTES: int = 65536
const SOURCE_FACE_ERROR: String = "204 refined face/field-normal inconsistency; no normal or topology repair."

static func recipe() -> Dictionary:
	return {"format": FORMAT, "format_version": VERSION, "experiment": "229", "mode": MODE, "policy_pin": PIN,
		"source_raw_sha256": SOURCE_RAW_SHA, "source_geometry_key": SOURCE_KEY, "artifact_geometry_key": ARTIFACT_KEY,
		"source_grid": [SOURCE_GRID.x, SOURCE_GRID.y, SOURCE_GRID.z], "source_axes_f32_le": SOURCE_AXES_HEX.duplicate(),
		"reference_cell_f64_le": CELL_BITS, "reference_origin_f32_le": ORIGIN_BITS,
		"source_vertices": SOURCE_VERTICES, "source_faces": SOURCE_FACES}

static func _integer(value: Variant, expected: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(expected)

static func validate_recipe(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "229 recipe must be a dictionary."}
	var expected: Dictionary = recipe()
	var received: Dictionary = value
	if received.size() != expected.size():
		return {"ok": false, "error": "229 recipe has missing or unknown fields."}
	for name: String in expected:
		if not received.has(name):
			return {"ok": false, "error": "229 recipe is missing " + name}
		var want: Variant = expected[name]
		var got: Variant = received[name]
		if want is String:
			if not got is String or got != want:
				return {"ok": false, "error": "229 changed string binding: " + name}
		elif want is int:
			if not _integer(got, want):
				return {"ok": false, "error": "229 changed integer binding: " + name}
		elif name == "source_grid":
			if not got is Array or got.size() != 3:
				return {"ok": false, "error": "229 source grid is malformed."}
			for axis in range(3):
				if not _integer(got[axis], want[axis]):
					return {"ok": false, "error": "229 source grid differs from224."}
		elif name == "source_axes_f32_le":
			if not got is Array or got.size() != 3:
				return {"ok": false, "error": "229 canonical axes are malformed."}
			for axis in range(3):
				if not got[axis] is String or got[axis] != want[axis]:
					return {"ok": false, "error": "229 canonical axes differ from224."}
		else:
			return {"ok": false, "error": "229 unsupported internal recipe field."}
	return {"ok": true, "error": "", "recipe": expected}

static func axes() -> Array:
	var result: Array = []
	for bits: String in SOURCE_AXES_HEX:
		result.append(bits.hex_decode().to_float32_array())
	return result

static func save_recipe(path: String, value: Variant) -> Dictionary:
	var checked: Dictionary = validate_recipe(value)
	if not checked.ok:
		return checked
	var text: String = JSON.stringify(checked.recipe, "\t", true, true)
	if text.to_utf8_buffer().size() > MAX_RECIPE_BYTES:
		return {"ok": false, "error": "229 recipe exceeds its fixed byte cap."}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "229 cannot write recipe temporary file."}
	file.store_string(text); file.flush()
	var status: Error = file.get_error(); file.close()
	if status != OK:
		return {"ok": false, "error": "229 recipe write failed."}
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return {"ok": false, "error": "229 cannot finish recipe save."}
	return {"ok": true, "error": "", "path": path}

static func load_recipe(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "229 cannot read recipe."}
	if file.get_length() > MAX_RECIPE_BYTES:
		file.close()
		return {"ok": false, "error": "229 recipe exceeds its fixed byte cap."}
	var parser: JSON = JSON.new()
	var status: Error = parser.parse(file.get_as_text()); file.close()
	if status != OK:
		return {"ok": false, "error": "229 malformed recipe JSON."}
	return validate_recipe(parser.data)
