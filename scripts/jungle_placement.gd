extends RefCounted
## Optional NUMERIC worker interface. No nodes/resources, automatic spawning or
## additional streaming work. Own one configured TerrainMeshBuilder per worker.
static func habitat(builder,x:float,z:float)->Dictionary:
	var h:float=builder._get_height(x,z);var packed:int=int(builder._last_jungle)
	var weight:float=float((packed>>16)&255)/255.0
	if weight<=0 or builder._jungle==null:return {"jungle":0.0,"canopy":0.0,"understory":0.0,"ground_cover":0.0,"emergent":0.0,"waterfall_candidate":false}
	var s=builder._jungle;var config:JungleSettings=s.settings;var region:int=s.region;var wet:float=s.wetness;var drainage:float=s.drainage;var water:float=maxf(s.river,s.lake)
	var dx:float=(builder._get_height(x+4,z,false)-builder._get_height(x-4,z,false))/8
	var dz:float=(builder._get_height(x,z+4,false)-builder._get_height(x,z-4,false))/8
	var slope:float=1-1/sqrt(1+dx*dx+dz*dz)
	var field:float=clampf(s._macro.get_noise_2d(x*.8,z*.8)*1.4+.5,0,1)
	var opening:float=smoothstep(1-config.clearing_frequency,.999,field) if config.clearing_frequency>0 else 0
	var suitable:float=weight*(1-smoothstep(.18,.55,slope))*(1-water)*(1-opening)
	if h<=builder.water_level+.5:suitable=0
	return {"jungle":weight,"height":h,"region":s.NAMES[region],"wetness":wet,"drainage":drainage,"slope":slope,"water":water,"clearing":opening,"canopy":suitable*config.canopy_density,"understory":suitable*config.understory_density,"ground_cover":suitable*config.ground_cover_density,"emergent":suitable*config.emergent_frequency,"downhill_direction":Vector2(-dx,-dz).normalized(),"drop_over_8m":maxf(absf(dx),absf(dz))*8,"waterfall_candidate":false,"waterfall_note":"Terrain drainage/drop data only. No elevated water or waterfall renderer."}

## Stable global jittered cells, paged at 512 probes / max 256 results per call.
## This returns placement DATA, not a completed rainforest asset pipeline.
static func candidates(builder,bounds:Rect2,spacing:float=24,max_candidates:int=128,scan_offset:int=0)->Dictionary:
	spacing=maxf(spacing,4);max_candidates=clampi(max_candidates,1,256);scan_offset=maxi(scan_offset,0)
	var first:=Vector2i(floori(bounds.position.x/spacing),floori(bounds.position.y/spacing))
	var last:=Vector2i(ceili(bounds.end.x/spacing),ceili(bounds.end.y/spacing));var width:int=maxi(last.x-first.x,0);var depth:int=maxi(last.y-first.y,0);var total:int=width*depth
	var result:Array=[];var cursor:int=scan_offset;var scanned:int=0
	while cursor<total and scanned<512 and result.size()<max_candidates:
		var cell:=first+Vector2i(cursor%width,cursor/width);cursor+=1;scanned+=1
		var x:float=(cell.x+.12+builder._region_random(cell.x,cell.y,107,31)*.76)*spacing
		var z:float=(cell.y+.12+builder._region_random(cell.x,cell.y,107,37)*.76)*spacing
		if not bounds.has_point(Vector2(x,z)):continue
		var mask:Dictionary=habitat(builder,x,z)
		if builder._region_random(cell.x,cell.y,107,41)>=float(mask.canopy):continue
		result.append({"cell":cell,"position":Vector3(x,mask.height,z),"rotation":builder._region_random(cell.x,cell.y,107,43)*TAU,"scale":lerpf(.75,1.35,builder._region_random(cell.x,cell.y,107,47)),"habitat":mask})
	return {"candidates":result,"next_offset":cursor,"complete":cursor>=total,"cells_probed":scanned}
