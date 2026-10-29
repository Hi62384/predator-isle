extends RefCounted
## One application-owned cache. Jobs run serially; entries are copied on read so
## budget fitting and stage annotations cannot mutate a preserved intermediate.
## One recent and one displayed entry per slot bound memory independently of how many seeds are explored.
var _entries: Dictionary = {}
var _displayed_entries: Dictionary = {}
var _mutex := Mutex.new()

func lookup(slot: String, key: String) -> Dictionary:
	_mutex.lock()
	var entry: Dictionary = _entries.get(slot, {})
	if str(entry.get("key", "")) != key:
		entry = _displayed_entries.get(slot, {})
	var result: Dictionary = entry.get("value", {}).duplicate(true) if str(entry.get("key", "")) == key else {}
	_mutex.unlock()
	return result

func store_value(slot: String, key: String, value: Dictionary) -> void:
	_mutex.lock()
	_entries[slot] = {"key": key, "value": value.duplicate(true)}
	_mutex.unlock()

## Keep the displayed organism reusable if a later build is cancelled or fails.
func pin_displayed() -> void:
	_mutex.lock()
	_displayed_entries = _entries.duplicate(true)
	_mutex.unlock()

func clear() -> void:
	_mutex.lock()
	_entries.clear()
	_displayed_entries.clear()
	_mutex.unlock()
