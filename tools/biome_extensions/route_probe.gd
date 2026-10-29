extends CharacterBody3D
## Test-only walker: no jumping, teleporting, noclip, or vertical path correction.
var route:Array[Vector3]=[]
var waypoint:int=0
var frames:int=0
var stalled_frames:int=0
var failed:bool=false
var finished:bool=false
var paused:bool=false
var best_distance:float=INF
var max_airborne:int=0
var airborne:int=0
var max_airborne_waypoint:int=-1
var airborne_start_y:float=0
var max_unsupported_drop:float=0
var horizontal_distance_m:float=0
func _physics_process(delta:float)->void:
	if failed or finished:return
	if paused:
		velocity.x=0;velocity.z=0
		velocity.y=0 if is_on_floor() else velocity.y-9.8*delta
		move_and_slide();return
	frames+=1
	if waypoint>=route.size():finished=true;velocity=Vector3.ZERO;return
	var target:Vector3=route[waypoint]
	var offset:=Vector2(target.x-position.x,target.z-position.z)
	if offset.length()<.55 and absf(position.y-target.y)<1.5:
		waypoint+=1;best_distance=INF;stalled_frames=0;return
	var distance:float=position.distance_to(target)
	if distance<best_distance-.05:best_distance=distance;stalled_frames=0
	else:stalled_frames+=1
	if stalled_frames>600 or position.y<target.y-12:failed=true;velocity=Vector3.ZERO;return
	var direction:Vector2=offset.normalized()
	velocity.x=direction.x*5;velocity.z=direction.y*5
	if is_on_floor():velocity.y=0
	else:velocity.y-=9.8*delta
	var before_move:Vector3=position
	move_and_slide()
	horizontal_distance_m+=Vector2(position.x-before_move.x,position.z-before_move.z).length()
	if is_on_floor():airborne=0
	else:
		if airborne==0:airborne_start_y=position.y
		airborne+=1
		if airborne>max_airborne:max_airborne=airborne;max_airborne_waypoint=waypoint
		# Include the initial approach. An embedded or unsupported static spawn
		# must not hide its drop merely because waypoint zero was never reached.
		max_unsupported_drop=maxf(max_unsupported_drop,airborne_start_y-position.y)
