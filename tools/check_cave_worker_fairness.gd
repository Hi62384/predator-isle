extends SceneTree
const Streamer=preload("res://scripts/caves/streamer.gd")
func _initialize()->void:
	var cave:int=4;var terrain:int=0
	# Finish existing background jobs one by one while surface work waits.
	# Every released slot must go to terrain until the reserved ratio is met.
	for completion in range(3):
		cave-=1
		var allowed:int=Streamer.dispatch_allowance(4-terrain,cave,true)
		assert(allowed==0,"Background cave work must not replenish all four slots")
		terrain+=4-terrain-cave-allowed;cave+=allowed
		assert(cave+terrain==4,"Total worker bound")
	assert(terrain==3 and cave==1,"Near terrain obtains its reserved worker slots")
	cave-=1;var refill:int=Streamer.dispatch_allowance(4-terrain,cave,true)
	assert(refill==1,"One cave job still progresses while surface work waits")
	assert(Streamer.dispatch_allowance(4,0,false)==4,"Underground work retains all four slots when terrain has no queued work")
	assert(Streamer.dispatch_allowance(1,2,true)==0,"No negative allowance or total-budget overcommit")
	assert(Streamer.dispatch_allowance(1,0,true,1)==0,"A single configured worker must serve queued terrain first")
	assert(Streamer.dispatch_allowance(1,0,false,1)==1,"A single worker still serves caves when terrain has no queued work")
	print("CAVE_WORKER_FAIRNESS passed:queued near terrain cannot be starved by per-frame cave replenishment");quit()
