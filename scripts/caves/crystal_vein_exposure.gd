extends RefCounted
## Same broad physical exposure field as cave_crystal_surface.gdshaderinc.
## All wavelengths divide3840m;no cell/camera-local or random stripe reset.
static func amount(point:Vector3)->float:
	var p:=Vector3(fposmod(point.x,3840.0),fposmod(point.y,3840.0),fposmod(point.z,3840.0))
	var patch:float=.5+.5*sin(p.x*TAU/48.0+.7*sin(p.z*TAU/32.0))*sin(p.z*TAU/60.0-p.y*TAU/48.0)
	return smoothstep(.60,.82,patch)
