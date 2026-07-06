extends Camera3D

@export var move_speed: float = 8.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.12

var yaw: float = 0.0
var pitch: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	yaw = rotation_degrees.y
	pitch = rotation_degrees.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -89.0, 89.0)

		rotation_degrees = Vector3(pitch, yaw, 0.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction -= global_transform.basis.z

	if Input.is_key_pressed(KEY_S):
		direction += global_transform.basis.z

	if Input.is_key_pressed(KEY_A):
		direction -= global_transform.basis.x

	if Input.is_key_pressed(KEY_D):
		direction += global_transform.basis.x

	if Input.is_key_pressed(KEY_E):
		direction += Vector3.UP

	if Input.is_key_pressed(KEY_Q):
		direction -= Vector3.UP

	if direction != Vector3.ZERO:
		direction = direction.normalized()

	var speed := move_speed

	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier

	global_position += direction * speed * delta
