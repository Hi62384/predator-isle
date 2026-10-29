extends RefCounted
## Fixed 201b certificate only. Arrays retain binary64 endpoints; Vector2 would
## silently round them to binary32. Every primitive endpoint is rounded outward.
const U32 := 0.000000059604644775390625
const TINY32 := 1.401298464324817e-45
const SUBDIVISIONS := 256
static func next64(x: float, direction: int) -> float:
	if not is_finite(x): return x
	var bytes := PackedByteArray(); bytes.resize(8)
	if x == 0.0:
		bytes.encode_s64(0,1 if direction > 0 else -9223372036854775807)
		return bytes.decode_double(0)
	bytes.encode_double(0,x)
	bytes.encode_s64(0,bytes.decode_s64(0)+(direction if x>0.0 else -direction))
	return bytes.decode_double(0)
static func point(x: float) -> Array: return [x,x]
static func add(a: Array,b: Array) -> Array: return [next64(a[0]+b[0],-1),next64(a[1]+b[1],1)]
static func neg(a: Array) -> Array: return [-a[1],-a[0]]
static func sub(a: Array,b: Array) -> Array: return add(a,neg(b))
static func mul(a: Array,b: Array) -> Array:
	var values := [a[0]*b[0],a[0]*b[1],a[1]*b[0],a[1]*b[1]]
	return [next64(values.min(),-1),next64(values.max(),1)]
static func div(a: Array,b: Array) -> Array:
	if b[0]<=0.0 and b[1]>=0.0: return [-INF,INF]
	return mul(a,[next64(1.0/b[1],-1),next64(1.0/b[0],1)])
static func square(a: Array) -> Array:
	return [0.0 if a[0]<=0.0 and a[1]>=0.0 else next64(minf(a[0]*a[0],a[1]*a[1]),-1),next64(maxf(a[0]*a[0],a[1]*a[1]),1)]
static func round32(a: Array) -> Array:
	var values := PackedFloat32Array([a[0],a[1]])
	return [float(values[0]),float(values[1])]
static func poly(c: Array,t: Array,derivative: int=0) -> Array:
	var value := point(0.0)
	for i in range(c.size()-1,derivative-1,-1):
		var multiplier := 1.0
		for j in range(derivative): multiplier*=float(i-j)
		value=add(mul(value,t),mul(point(float(c[i])),point(multiplier)))
	return value
static func finite(a: Array) -> bool: return is_finite(a[0]) and is_finite(a[1]) and a[0]<=a[1]
static func maximum_abs(a: Array) -> float: return maxf(absf(a[0]),absf(a[1]))

static func boundary(f: RefCounted,low: Array,high: Array,halo: float) -> Dictionary:
	var minima := [INF,INF,INF,INF,INF,INF]
	var pieces := [[low[2],0.0],[0.0,0.5],[0.5,1.0],[1.0,high[2]]]
	for piece in range(4):
		for j in range(SUBDIVISIONS):
			# Enclose exact rational subdivision endpoints, including arithmetic.
			var za: float=pieces[piece][0]; var zb: float=pieces[piece][1]
			var z0 := add(point(za),mul(sub(point(zb),point(za)),point(float(j)/float(SUBDIVISIONS))))
			var z1 := add(point(za),mul(sub(point(zb),point(za)),point(float(j+1)/float(SUBDIVISIONS))))
			var z: Array=[z0[0],z1[1]]
			var t := div(sub(z,point(f.midpoint)),point(f.half_span))
			var px: Array; var py: Array; var cx:=point(0.0); var cy:=point(0.0)
			if piece==0 or piece==3:
				var index:=0 if piece==0 else 1
				var r: float=f.caps[index][0]
				var numerator:=sub(point(1.0+float(f.caps[1][0])),z) if piece==0 else add(z,point(float(f.caps[0][0])))
				var denominator:=sub(point(r),z) if piece==0 else add(sub(z,point(1.0)),point(r))
				# These constants are exactly the same evaluated doubles as _coefficients.
				var factor: float=r*r/(f.half_span*f.half_span)
				px=div(mul(point(factor/pow(float(f.caps[index][2]),2.0)),numerator),denominator)
				py=div(mul(point(factor/pow(float(f.caps[index][1]),2.0)),numerator),denominator)
			else:
				var span:=piece-1
				var tt:=mul(sub(z,point(float(span)*0.5)),point(2.0))
				tt=[maxf(tt[0],0.0),minf(tt[1],1.0)]
				var values: Array=[]
				for i in range(4): values.append(round32(poly(f.profiles[i][span],tt)))
				var a:=mul(add(values[0],values[1]),point(0.5)); var b:=mul(add(values[2],values[3]),point(0.5))
				cx=mul(sub(values[2],values[3]),point(0.5)); cy=mul(sub(values[0],values[1]),point(0.5))
				var q:=sub(point(1.0),mul(t,t))
				px=div(q,mul(b,b)); py=div(q,mul(a,a))
			if not finite(px) or not finite(py) or px[0]<=0.0 or py[0]<=0.0 or low[0]>=cx[0] or high[0]<=cx[1] or low[1]>=cy[0] or high[1]<=cy[1]: return {"ok":false,"reason":"fixed boundary interval inconclusive"}
			for face in range(4):
				var axis:=0 if face<2 else 1
				var coord: float=low[axis] if face%2==0 else high[axis]
				var x:=sub(point(coord),cx if axis==0 else cy)
				var term:=mul(mul(px if axis==0 else py,x),x)
				# Same expression ordering as raw_value_gradient; omitted square >=0.
				var value:=round32(mul(point(f.raw_scale*0.5),sub(add(square(t),term),point(1.0))))
				minima[face]=minf(minima[face],value[0])
	for face in [4,5]:
		var z: float=low[2] if face==4 else high[2]
		var t:=div(sub(point(z),point(f.midpoint)),point(f.half_span))
		minima[face]=round32(mul(point(f.raw_scale*0.5),sub(square(t),point(1.0))))[0]
	return {"ok":float(minima.min())>halo,"face_lower_bounds":minima,"required_halo":halo,"minimum_clearance":float(minima.min())-halo,"fixed_axial_intervals":SUBDIVISIONS*4,"includes_vector4_binary32_rounding":true,"outside_monotonicity":true}

static func _matrix_inverse(a: Array) -> Array:
	var cof: Array=[]
	for row in range(3):
		var line: Array=[]
		for col in range(3):
			var rr: Array=[]; var cc: Array=[]
			for k in range(3):
				if k!=row: rr.append(k)
				if k!=col: cc.append(k)
			var value:=sub(mul(a[rr[0]][cc[0]],a[rr[1]][cc[1]]),mul(a[rr[0]][cc[1]],a[rr[1]][cc[0]]))
			line.append(value if (row+col)%2==0 else neg(value))
		cof.append(line)
	var determinant:=point(0.0)
	for k in range(3): determinant=add(determinant,mul(a[0][k],cof[0][k]))
	var result: Array=[]
	for row in range(3):
		var line: Array=[]
		for col in range(3): line.append(div(cof[col][row],determinant))
		result.append(line)
	return result
static func _norm(a: Array) -> float:
	var result:=0.0
	for row: Array in a:
		var total:=point(0.0)
		for v: Array in row: total=add(total,point(maximum_abs(v)))
		result=maxf(result,total[1])
	return result
static func _out32(x: float,direction: int) -> float:
	var bytes:=PackedByteArray(); bytes.resize(4); bytes.encode_float(0,x)
	var rounded:=float(bytes.decode_float(0))
	if (direction<0 and rounded<=x) or (direction>0 and rounded>=x): return rounded
	bytes.encode_s32(0,(1 if direction>0 else -2147483647) if rounded==0.0 else bytes.decode_s32(0)+(direction if rounded>0.0 else -direction))
	return float(bytes.decode_float(0))
static func preimage_box(f: RefCounted,low: Array,high: Array) -> Dictionary:
	# Actual Godot binary32 operations: subtraction, 3-product/2-add Basis
	# rows, then scalar division. Both direct division and reciprocal-multiply
	# implementations are covered by gamma2. No transpose=inverse assumption.
	var a: Array=[]
	for row in range(3):
		var line: Array=[]
		for col in range(3): line.append(point(float(f.inverse_frame[col][row])))
		a.append(line)
	var inverse:=_matrix_inverse(a); var an:=_norm(a); var invn:=_norm(inverse)
	var gamma5: float=div(point(5.0*U32),sub(point(1.0),point(5.0*U32)))[1]
	var gamma2: float=div(point(2.0*U32),sub(point(1.0),point(2.0*U32)))[1]
	var length32:=float(PackedFloat32Array([f.length_scale])[0])
	var qmax:=0.0
	for k in range(3): qmax=maxf(qmax,maxf(absf(low[k]),absf(high[k])))
	var rmax: float=div(add(mul(point(length32),point(qmax)),point(TINY32)),sub(point(1.0),point(gamma2)))[1]
	var denominator:=sub(point(1.0),mul(point(gamma5),mul(point(an),point(invn))))
	if denominator[0]<=0.0 or not is_finite(invn) or length32<=0.0: return {"ok":false}
	var smax: float=div(mul(point(invn),add(point(rmax),point(8.0*TINY32))),denominator)[1]
	var dot_error: float=add(mul(point(gamma5),mul(point(an),point(smax))),point(8.0*TINY32))[1]
	var division_error: float=add(mul(point(gamma2),point(rmax)),point(TINY32))[1]
	var subtraction_error: float=div(add(mul(point(U32),point(smax)),point(TINY32)),sub(point(1.0),point(U32)))[1]
	var r: Array=[]
	for k in range(3): r.append(add(mul([low[k],high[k]],point(length32)),[-dot_error-division_error,dot_error+division_error]))
	var world_low: Array=[]; var world_high: Array=[]
	for row in range(3):
		var value:=point(float(f.origin[row]))
		for col in range(3): value=add(value,mul(inverse[row][col],r[col]))
		value=add(value,[-subtraction_error,subtraction_error])
		if not finite(value): return {"ok":false}
		world_low.append(_out32(value[0],-1)); world_high.append(_out32(value[1],1))
	var pos:=Vector3(world_low[0],world_low[1],world_low[2]); var size:=Vector3.ZERO
	for k in range(3): size[k]=_out32(next64(world_high[k]-world_low[k],1),1)
	var box:=AABB(pos,size)
	for k in range(3):
		if box.end[k]<world_high[k]: size[k]=_out32(next64(float(size[k]),1),1)
	box=AABB(pos,size)
	return {"ok":box.position.is_finite() and box.size.is_finite(),"box":box,"dot_error":dot_error,"division_error":division_error,"subtraction_error":subtraction_error,"actual_inverse_norm":invn,"binary32_scalar_length":length32,"proof":"interval inverse of actual stored inverse Basis; gamma5 dot, gamma2 scale, binary32 subtract, directed AABB storage"}

static func profile(f: RefCounted,extent: int,span: int) -> Dictionary:
	var axis:=1 if extent<2 else 2
	var left: float=f.caps[0][axis]; var right: float=f.caps[1][axis]
	var minimum:=minf(left,right); var middle: float=f.PROGRAM[extent]*minimum
	# The intended polynomial is the exact Hermite interpolant of these fixed
	# evaluated endpoint jets. Rounded power storage is enclosed separately.
	var a:=left if span==0 else middle; var b:=middle if span==0 else right
	var ka: float=-left/pow(float(f.caps[0][0]),2.0)*0.25 if span==0 else minimum*0.25
	var kb: float=minimum*0.25 if span==0 else -right/pow(float(f.caps[1][0]),2.0)*0.25
	var delta:=sub(point(b),point(a))
	var ideal: Array=[point(a),point(0.0),mul(point(ka),point(0.5)),add(sub(mul(point(10.0),delta),mul(point(1.5),point(ka))),mul(point(0.5),point(kb))),sub(add(mul(point(-15.0),delta),mul(point(1.5),point(ka))),point(kb)),add(sub(mul(point(6.0),delta),mul(point(0.5),point(ka))),mul(point(0.5),point(kb)))]
	var sign_value: float=-1.0 if span==0 else 1.0
	var b1:=mul(point(ka),point(sign_value/4.0)); var b3:=mul(point(kb),point(-sign_value/4.0))
	var b2:=sub(sub(mul(delta,point(5.0*sign_value)),b1),b3)
	var c:=mul(point(4.0),b1)
	var bb:=add(mul(point(-8.0),b1),mul(point(6.0),b2))
	var aa:=add(sub(mul(point(4.0),b1),mul(point(6.0),b2)),mul(point(4.0),b3))
	var minimum_q:=minf(c[0],add(add(aa,bb),c)[0]); var stationary: Array=[]
	if aa[0]>0.0:
		stationary=div(neg(bb),mul(point(2.0),aa))
		if stationary[1]>0.0 and stationary[0]<1.0:
			minimum_q=minf(minimum_q,sub(c,div(square(bb),mul(point(4.0),aa)))[0])
	elif aa[1]>0.0: return {"ok":false,"reason":"quadratic curvature enclosure inconclusive"}
	var stored: Array=f.profiles[extent][span]
	var extent_error:=point(0.0); var derivative_error:=point(0.0); var norm_value:=point(0.0); var norm_derivative:=point(0.0)
	var endpoint_derivative:=point(0.0)
	for i in range(6):
		var residual:=point(maximum_abs(sub(point(float(stored[i])),ideal[i])))
		extent_error=add(extent_error,residual); derivative_error=add(derivative_error,mul(point(float(i)),residual))
		norm_value=add(norm_value,point(absf(float(stored[i])))); norm_derivative=add(norm_derivative,point(float(i)*absf(float(stored[i]))))
		endpoint_derivative=add(endpoint_derivative,mul(point(float(i)),point(float(stored[i]))))
	var u64:=0.00000000000000011102230246251565
	var gamma18: float=div(point(18.0*u64),sub(point(1.0),point(18.0*u64)))[1]
	extent_error=add(extent_error,mul(point(gamma18),norm_value))
	derivative_error=add(derivative_error,mul(point(gamma18),norm_derivative))
	var spatial_reference: float=U32*minimum*f.length_scale
	var world_error: float=extent_error[1]*f.length_scale
	var positive_floor: float=minf(a,b)-extent_error[1]-U32*maxf(left,right)
	return {"ok":minimum_q>0.0 and is_finite(world_error) and world_error<spatial_reference and positive_floor>0.0,"extent":extent,"span":span,"factored_quadratic":[c,bb,aa],"stationary_interval":stationary,"strict_intended_quadratic_lower":minimum_q,"stored_endpoint_derivative_interval":endpoint_derivative,"stored_and_horner_extent_residual":extent_error[1],"stored_and_horner_derivative_residual":derivative_error[1],"world_extent_residual":world_error,"binary32_spatial_reference":spatial_reference,"vector4_quantization_bound":U32*maxf(left,right)*f.length_scale,"positive_evaluated_extent_floor":positive_floor,"rounded_power_polynomial_strict_monotonicity_claimed":false,"no_resolved_extra_lobe":world_error<spatial_reference}
