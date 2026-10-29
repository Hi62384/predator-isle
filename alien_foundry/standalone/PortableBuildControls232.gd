extends RefCounted
## Plain-data cooperative control. No scene tree or rendering calls on worker.
var _mutex: Mutex = Mutex.new()
var _cancelled: bool = false
var _progress: float = 0.0
var _message: String = "Starting fixed seed 22 build"
var _started: int = Time.get_ticks_msec()
const TIME_LIMIT_MS: int = 900000

func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_message = "Cancellation requested; finishing the current bounded operation"
	_mutex.unlock()

func is_cancelled() -> bool:
	_mutex.lock()
	var result: bool = _cancelled
	_mutex.unlock()
	return result or Time.get_ticks_msec() - _started >= TIME_LIMIT_MS

func set_progress(value: float, message: String) -> void:
	_mutex.lock()
	if not _cancelled and is_finite(value):
		_progress = maxf(_progress,clampf(value,0.0,1.0))
		_message = message
	_mutex.unlock()

func snapshot() -> Dictionary:
	_mutex.lock()
	var result: Dictionary = {"cancelled":_cancelled,"progress":_progress,"message":_message}
	_mutex.unlock()
	result.elapsed_ms = Time.get_ticks_msec() - _started
	result.timed_out = result.elapsed_ms >= TIME_LIMIT_MS
	return result
