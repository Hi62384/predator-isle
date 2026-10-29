extends RefCounted
## PRIVATE composition-only cache for a PURE immutable canonical height source.
## Vector2 keys are admitted only when they represent both original doubles
## exactly. Fractional/distant coordinates that would alias bypass the cache.
## This separate provider owns no field/node,avoiding Callable self-reference.
const CAPACITY:int=8192
var source:Callable
var enabled:bool=true
var values:Dictionary={}
var ring:Array[Vector2]=[]
var cursor:int=0
var hits:int=0
var misses:int=0
var bypasses:int=0
func configure(provider:Callable,active:bool=true)->void:
	source=provider;enabled=active;values.clear();ring.clear();cursor=0;hits=0;misses=0;bypasses=0
func sample(x:float,z:float)->float:
	if not is_finite(x) or not is_finite(z) or not source.is_valid():return NAN
	var key:=Vector2(x,z)
	if not enabled or not key.is_finite() or float(key.x)!=x or float(key.y)!=z:bypasses+=1;return source.call(x,z)
	if values.has(key):hits+=1;return values[key]
	misses+=1;var value:float=source.call(x,z)
	if not is_finite(value):return value
	if ring.size()<CAPACITY:ring.append(key)
	else:values.erase(ring[cursor]);ring[cursor]=key;cursor=(cursor+1)%CAPACITY
	values[key]=value;return value
func statistics()->Dictionary:
	return {"hits":hits,"misses":misses,"bypasses":bypasses,"entries":values.size(),"capacity":CAPACITY,"numeric_key_ring_value_bytes_excluding_objects":values.size()*24}
