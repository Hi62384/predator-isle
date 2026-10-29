extends CharacterBody3D
func _physics_process(delta:float)->void:
	velocity.x=36;velocity.y-=9.8*delta;move_and_slide()
