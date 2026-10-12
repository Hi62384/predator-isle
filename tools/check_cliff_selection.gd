extends SceneTree
func weight(candidate: float,cutoff: float,coverage: float) -> float:
	return smoothstep(1.0-coverage,1.0-coverage+0.18,candidate)*smoothstep(0.0,0.065,maxf(0.0,candidate-cutoff)) if coverage>0.0 else 0.0
func _initialize() -> void:
	# Previously all these saturated to 1 before ranking, cancelling both winners.
	assert(weight(0.85,0.70,0.72)>0.99)
	assert(weight(0.79,0.70,0.72)>0.99)
	assert(is_zero_approx(weight(0.1,0.05,0.72)))
	assert(is_zero_approx(weight(0.85,0.7,0.0)))
	# An entering/leaving runner-up fades continuously to zero at the rank crossing.
	assert(is_zero_approx(weight(0.7,0.7,0.72)))
	assert(weight(0.70001,0.7,0.72)<0.00001)
	print("PASS strong overlap retained, empty coverage retained, continuous rank handoff")
	quit()
