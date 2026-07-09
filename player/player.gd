extends CharacterBody3D

const SPEED = 5.5
const BOB_FREQ = 2.0
const BOB_AMP = 0.06

var bob_time := 0.0
var camera_base_y := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_y = %Camera3D.position.y

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * 0.3
		%Camera3D.rotation_degrees.x -= event.relative.y * 0.2
		%Camera3D.rotation_degrees.x = clamp(%Camera3D.rotation_degrees.x, -80, 80)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	var input_direction_2d = Input.get_vector(
		"move_left","move_right","move_forward","move_back"
	)
	var input_direction_3d = Vector3(input_direction_2d.x, 0, input_direction_2d.y)
	var direction = transform.basis * input_direction_3d

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	velocity.y -= 20 * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 5
	elif Input.is_action_just_released("jump") and velocity.y > 0:
		velocity.y = 0

	move_and_slide()
	_update_headbob(delta)

func _update_headbob(delta: float) -> void:
	var is_moving = is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.1
	if is_moving:
		bob_time += delta * BOB_FREQ * PI
		%Camera3D.position.y = camera_base_y + sin(bob_time * 2.0) * BOB_AMP
	else:
		bob_time = 0.0
		%Camera3D.position.y = lerpf(%Camera3D.position.y, camera_base_y, delta * 10.0)
