extends RefCounted
## Bounded provenance DAG. Final anatomy remains the complete reconstruction data.
const VERSION := 2
const MAX_RECORDS := 256
const MAX_JSON_VALUES := 400000
const HASH_FORMAT := "sha256-json-numeric-9-significant-halfway-v1"

static func validate_json(value: Variant) -> Dictionary:
	var error := _json_error(value, [], 0, [MAX_JSON_VALUES])
	return {"ok":true} if error.is_empty() else {"ok":false,"error":error}

static func validate_source(source: Dictionary) -> Dictionary:
	var checked := validate_json(source)
	if not checked["ok"]: return checked
	if not source.get("ancestry",[]) is Array:
		return {"ok":false,"error":"Combination ancestry must be an array."}
	if not source.has("ancestry_version"):
		for root in source.get("ancestry",[]):
			if not root is Dictionary or not _valid_legacy_record(root):
				return {"ok":false,"error":"Malformed legacy combination ancestry."}
		return {"ok":true}
	if source["ancestry_version"] != VERSION:
		return {"ok":false,"error":"Unsupported combination ancestry version."}
	var lineage: Variant = source.get("lineage")
	if not lineage is Dictionary or not lineage.get("records") is Dictionary:
		return {"ok":false,"error":"Missing lineage record table."}
	var records: Dictionary = lineage["records"]
	if lineage.get("hash_format","")!=HASH_FORMAT:
		return {"ok":false,"error":"Unsupported lineage fingerprint normalization."}
	if records.size()>MAX_RECORDS or lineage.get("record_limit",0)!=MAX_RECORDS:
		return {"ok":false,"error":"Lineage exceeds its bounded record budget."}
	if not lineage.get("history_truncated") is bool:
		return {"ok":false,"error":"Lineage truncation state must be explicit."}
	var pruned: Variant = lineage.get("pruned_record_count")
	if not (pruned is int or pruned is float) or float(pruned)<0.0 or float(pruned)!=floor(float(pruned)):
		return {"ok":false,"error":"Invalid lineage pruning count."}
	var truncated: bool = lineage["history_truncated"]
	for id in records:
		var record: Variant = records[id]
		if not _valid_id(id) or not record is Dictionary or record.get("id","")!=id or not _valid_record(record):
			return {"ok":false,"error":"Invalid lineage identity record."}
		for ancestor in record["ancestors"]:
			if not records.has(ancestor) and not truncated:
				return {"ok":false,"error":"Lineage references missing history without a truncation marker."}
	if source["ancestry"].size()>2:
		return {"ok":false,"error":"A combination has at most two direct sources."}
	for root in source["ancestry"]:
		if not root is Dictionary or not records.has(root.get("id","")) or root!=records[root["id"]]:
			return {"ok":false,"error":"Direct-source identity does not match its lineage record."}
	var states: Dictionary = {}
	for id in records:
		if _has_cycle(str(id),records,states):
			return {"ok":false,"error":"Combination lineage contains a reference cycle."}
	return {"ok":true}

static func build(first: Dictionary, second: Dictionary) -> Dictionary:
	for source in [first,second]:
		var checked := validate_source(source)
		if not checked["ok"]: return checked
	var records: Dictionary = {}
	var roots: Array = []
	var inherited_truncation := false
	for source in [first,second]:
		var ancestors: Array = []
		if source.get("ancestry_version",1)==VERSION:
			var prior: Dictionary = source["lineage"]
			inherited_truncation = inherited_truncation or bool(prior["history_truncated"])
			for id in prior["records"]:
				var record: Dictionary = prior["records"][id]
				if records.has(id) and records[id]!=record:
					return {"ok":false,"error":"Conflicting lineage records share one identity hash."}
				records[id]=record.duplicate(true)
			for root in source["ancestry"]: ancestors.append(root["id"])
		else:
			for root in source.get("ancestry",[]): ancestors.append(_import_legacy(root,records))
		var id := canonical_hash(source)
		var direct := {"id":id,"source_hash":id,"identity_kind":"dna_snapshot",
			"type":str(source.get("type","Unknown")),"seed":source.get("seed",0),
			"version":int(source.get("version",1)),"render_generation":int(source.get("render_generation",1)),
			"method":str(source.get("metadata",{}).get("combination_method","")),"ancestors":ancestors}
		if records.has(id) and records[id]!=direct:
			return {"ok":false,"error":"Conflicting direct-source identity."}
		records[id]=direct
		roots.append(id)
	# Breadth-first retention keeps direct sources and the nearest shared history.
	# Dropped historical records are disclosed; their hashes remain on frontier edges.
	var retained: Dictionary = {}
	var queue: Array = roots.duplicate()
	var cursor := 0
	while cursor<queue.size() and retained.size()<MAX_RECORDS:
		var id: String = queue[cursor]; cursor+=1
		if retained.has(id) or not records.has(id): continue
		retained[id]=records[id]
		queue.append_array(records[id]["ancestors"])
	var pruned := records.size()-retained.size()
	var direct_sources: Array = []
	for id in roots: direct_sources.append(retained[id].duplicate(true))
	return {"ok":true,"ancestry_version":VERSION,"ancestry":direct_sources,
		"lineage":{"records":retained,"record_limit":MAX_RECORDS,"hash_format":HASH_FORMAT,
		"history_truncated":inherited_truncation or pruned>0,"pruned_record_count":pruned}}

static func canonical_hash(value: Variant) -> String:
	# JSON reload changes ints to doubles and can change the last binary ULP.
	# Fingerprints normalize finite numbers to9 significant decimal digits;
	# full unquantized anatomy remains in the saved DNA, never in this fingerprint.
	return _canonical(value).sha256_text()

static func _canonical(value: Variant) -> String:
	if value==null: return "null"
	if value is bool: return "true" if value else "false"
	if value is int or value is float:
		var number := float(value)
		if number==0.0: return "0"
		if absf(number-round(number))<=maxf(1e-12,absf(number)*1e-12) and absf(number)<=9007199254740991.0: return str(int(round(number)))
		var exponent := int(floor(log(absf(number))/log(10.0)))
		var first_step := clampi(exponent,-300,300)
		var scaled := (number/pow(10.0,first_step))/pow(10.0,exponent-first_step)
		var ticks := absf(scaled)*100000000.0
		var lower := floorf(ticks)
		# Treat decimal halfway ties consistently despite one-ULP parser noise.
		var rounded_ticks: float = lower+1.0 if absf(ticks-lower-0.5)<0.00001 else floorf(ticks+0.5)
		var mantissa := String.num(signf(scaled)*rounded_ticks/100000000.0,8)
		if absf(float(mantissa))>=10.0:
			mantissa=String.num(float(mantissa)*0.1,8); exponent+=1
		return mantissa+"e"+str(exponent)
	if value is String: return JSON.stringify(value)
	var parts: PackedStringArray=[]
	if value is Array:
		for child in value: parts.append(_canonical(child))
		return "["+",".join(parts)+"]"
	var keys: Array=value.keys(); keys.sort()
	for key in keys: parts.append(JSON.stringify(key)+":"+_canonical(value[key]))
	return "{"+",".join(parts)+"}"

static func _import_legacy(record: Dictionary, records: Dictionary) -> String:
	var ancestors: Array = []
	for child in record.get("ancestors",[]): ancestors.append(_import_legacy(child,records))
	var normalized := {"type":str(record.get("type","Unknown")),"seed":record.get("seed",0),
		"version":int(record.get("version",1)),"render_generation":int(record.get("render_generation",1)),
		"method":str(record.get("method","")),"ancestors":ancestors,"identity_kind":"legacy_ancestry_summary"}
	var id := canonical_hash(normalized)
	normalized["id"]=id
	records[id]=normalized
	return id

static func _valid_legacy_record(record: Dictionary) -> bool:
	if not record.get("ancestors",[]) is Array or record.get("ancestors",[]).size()>2: return false
	for child in record.get("ancestors",[]):
		if not child is Dictionary or not _valid_legacy_record(child): return false
	return true

static func _valid_id(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true

static func _valid_record(record: Dictionary) -> bool:
	if not record.get("ancestors") is Array or record["ancestors"].size()>2: return false
	if not record.get("type") is String or not record.get("method") is String: return false
	if not (record.get("seed") is int or record.get("seed") is float): return false
	for key in ["version","render_generation"]:
		var number: Variant=record.get(key)
		if not (number is int or number is float) or float(number)<1.0 or float(number)!=floorf(float(number)): return false
	if record.get("identity_kind","") not in ["dna_snapshot","legacy_ancestry_summary"]: return false
	if record["identity_kind"]=="dna_snapshot" and record.get("source_hash","")!=record["id"]: return false
	for ancestor in record["ancestors"]:
		if not _valid_id(ancestor): return false
	return true

static func _has_cycle(id: String, records: Dictionary, states: Dictionary) -> bool:
	if int(states.get(id,0))==1: return true
	if int(states.get(id,0))==2 or not records.has(id): return false
	states[id]=1
	for parent in records[id]["ancestors"]:
		if _has_cycle(parent,records,states): return true
	states[id]=2
	return false

static func _json_error(value: Variant, active: Array, depth: int, remaining: Array) -> String:
	remaining[0]-=1
	if depth>64 or remaining[0]<0: return "Combination source exceeds safe JSON nesting or value bounds."
	if value==null or value is bool: return ""
	if value is int or value is float:
		return "" if is_finite(float(value)) else "Combination source contains non-finite values."
	if value is String:
		return "" if value.length()<=1024*1024 else "Combination source contains an oversized string."
	if not (value is Dictionary or value is Array): return "Combination source is not JSON-safe."
	for parent in active:
		if is_same(parent,value): return "Combination source contains a cyclic JSON object."
	active.append(value)
	if value is Dictionary:
		for key in value:
			if not key is String or key.length()>4096: return "Combination source contains an invalid JSON key."
			var error := _json_error(value[key],active,depth+1,remaining)
			if not error.is_empty(): return error
	else:
		for child in value:
			var error := _json_error(child,active,depth+1,remaining)
			if not error.is_empty(): return error
	active.pop_back()
	return ""
