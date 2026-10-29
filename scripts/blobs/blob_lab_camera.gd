extends Camera3D
var angle:=.6
var pitch:=.3
var distance:=8.5
var focus:=Vector3(0,1.5,0)
var home_focus:=focus
var home_distance:=distance
var follow:Node3D
var follow_enabled:=true
var _last_follow:=Vector3.ZERO
func _ready() -> void: _update()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			angle-=event.relative.x*.008
			pitch=clampf(pitch+event.relative.y*.008,-1.48,1.48)
			_update()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			focus+=(-global_basis.x*event.relative.x+global_basis.y*event.relative.y)*distance*.0015
			_update()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(.35,distance*.9)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(100,distance/ .9)
		_update()
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F: focus=home_focus; distance=home_distance
			KEY_R: focus=home_focus; distance=home_distance; angle=.6; pitch=.3
			KEY_1: angle=.0; pitch=.0
			KEY_2: angle=PI*.5; pitch=.0
			KEY_3: pitch=1.48
			KEY_4: angle=PI; pitch=.0
			KEY_5: angle=-PI*.5; pitch=.0
			KEY_6: pitch=-1.48
		_update()
func _update() -> void:
	position=focus+Vector3(sin(angle)*cos(pitch),sin(pitch),cos(angle)*cos(pitch))*distance
	look_at(focus)
func frame_creature(data: Dictionary, body_height: float) -> void:
	var bounds:=AABB(Vector3.ZERO,Vector3.ONE*.001)
	for p: Vector3 in data.body.vertices: bounds=bounds.expand(p)
	for item: Dictionary in data.appendages:
		for p: Vector3 in item.mesh.vertices: bounds=bounds.expand(p)
	focus=bounds.get_center()+Vector3.UP*body_height
	distance=maxf(4.0,bounds.size[bounds.size.max_axis_index()]*1.5)
	home_focus=focus; home_distance=distance; h_offset=.5
	_update()
func focus_feature(actor: Node3D, id: int) -> void:
	focus=actor.attachment_position(id)
	distance=maxf(.8,actor.anatomy.features[id].radii.length()*4.0)
	_update()

func quick_view(index:int)->void:
	match index:
		0: angle=0; pitch=0
		1: angle=PI; pitch=0
		2: angle=-PI*.5; pitch=0
		3: angle=PI*.5; pitch=0
		4: pitch=1.48
		5: pitch=-1.48
		6: angle=.6; pitch=.3
	_update()

func follow_actor(actor:Node3D)->void:
	follow=actor;_last_follow=actor.global_position
func _process(_delta:float)->void:
	if not is_instance_valid(follow):return
	var delta:=follow.global_position-_last_follow;_last_follow=follow.global_position
	if follow_enabled:focus+=delta;home_focus+=delta;_update()
