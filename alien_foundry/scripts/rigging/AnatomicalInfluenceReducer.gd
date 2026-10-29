class_name AnatomicalInfluenceReducer
extends RefCounted
## Anatomical four-slot reduction. Rank subtraction removes ordinary 4/5
## selection jumps. Near fully balanced corners, a bounded deterministic ID
## bias avoids zero residuals. This is not a global continuity guarantee.
static func reduce(source: Dictionary) -> Dictionary:
	var values: Dictionary=source.duplicate()
	var ids: Array=values.keys();ids.sort()
	var raw_total: float=0.0
	for value: float in values.values(): raw_total+=value
	var sorted: Array=_sorted(values)
	var balanced: bool=false
	if sorted.size()>4:
		var residual: float=0.0
		for i: int in range(4): residual+=maxf(0.0,float(values[sorted[i]])-float(values[sorted[4]]))
		var band: float=maxf(raw_total*.01,.000001)
		var bias: float=(1.0-smoothstep(0.0,band,residual))*raw_total*.002
		balanced=bias>.000000001
		# A fixed anatomical ID ordering resolves the exactly balanced corner;
		# it is not a nearest-bone search and is negligible outside that corner.
		if balanced:
			for i: int in range(ids.size()): values[ids[i]]=float(values[ids[i]])+bias*(1.0-float(i)/maxf(ids.size()-1,1))
			sorted=_sorted(values)
		var cutoff: float=float(values[sorted[4]])
		for id: int in values: values[id]=maxf(0.0,float(values[id])-cutoff)
	var total: float=0.0
	for i: int in range(mini(4,sorted.size())): total+=float(values[sorted[i]])
	var output: Dictionary={}
	if total<.0000000001:
		# Explicit deterministic exception, not a claim of universal continuity.
		output[int(ids[0])]=1.0
		return {"weights":output,"balanced":balanced,"fallback":true}
	for i: int in range(mini(4,sorted.size())):
		if float(values[sorted[i]])>0.0: output[int(sorted[i])]=float(values[sorted[i]])/total
	return {"weights":output,"balanced":balanced,"fallback":false}
static func _sorted(values: Dictionary) -> Array:
	var result: Array=values.keys()
	result.sort_custom(func(a: int,b: int)->bool:
		if float(values[a])==float(values[b]): return a<b
		return float(values[a])>float(values[b]))
	return result
