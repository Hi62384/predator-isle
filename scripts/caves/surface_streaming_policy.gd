extends RefCounted
## Preserve the complete committed outdoor cut under deep closed cover.
## This is scheduling only:never hide geometry,change LOD or move colliders.
const DEEP_COVER_METRES:float=96.0
static func can_defer(point:Vector3,ground:float,enabled:bool,required_entrance:bool)->bool:
	return enabled and point.is_finite() and is_finite(ground) and ground-point.y>DEEP_COVER_METRES and not required_entrance
