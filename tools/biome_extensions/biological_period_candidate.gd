extends RefCounted
## Private correction only: full-scene compilation/resource acceptance failed.
const ORIGINAL="int period=int(round(metres*4.0));"
const CORRECTED="int period=int(round(metres*4.0))*2;"
static func apply_to(source:String)->String:
	assert(source.count(ORIGINAL)==1)
	return source.replace(ORIGINAL,CORRECTED)
