extends CharacterBody3D

@export var move_speed: float = 10.0
@export var acceleration: float = 12.0

@export var wait_time_min: float = 0.5
@export var wait_time_max: float = 2.0

@export var use_gravity: bool = true
@export var rotate_towards_movement: bool = true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

var destinations: Array[Node3D] = []
var current_destination: Node3D = null

enum STATES {
	IDLE,
	WALKING
}

var state : STATES = STATES.WALKING

func _ready() -> void:
	randomize()

	_refresh_destinations()

	# Wait one physics frame so the navigation map is ready.
	await get_tree().physics_frame

	_choose_new_destination()


func _physics_process(delta: float) -> void:

	if state == STATES.WALKING:
		move_towards_destination(delta)


func move_towards_destination(delta):
	if navigation_agent.is_navigation_finished():
		_arrive_at_destination()
		return
		
	#if !navigation_agent.is_target_reachable():
		#print('Unreacheable')
	#else:
		#print('reacheable')

	var next_path_position: Vector3 = navigation_agent.get_next_path_position()


	var direction: Vector3 = next_path_position - global_position
	
	print(next_path_position)

	direction.y = 0.0

	direction = direction.normalized()
	

	var desired_velocity: Vector3 = direction * move_speed

	#velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	#velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	
	velocity = direction * 20
	

	if rotate_towards_movement:
		_face_direction(direction)

	_apply_gravity(delta)
	move_and_slide()

func _refresh_destinations() -> void:
	destinations.clear()

	for node in get_tree().get_nodes_in_group('Waypoints'):
		if node is Node3D:
			destinations.append(node)

	if destinations.is_empty():
		push_warning("No destinations")
		
	print('waypoint list: ' + str(destinations))


func _choose_new_destination() -> void:
	
	if destinations.is_empty():
		_refresh_destinations()

	if destinations.is_empty():
		return

	var chosen_destination: Node3D = destinations.pick_random()

	if destinations.size() > 1:
		while chosen_destination == current_destination:
			chosen_destination = destinations.pick_random()

	current_destination = chosen_destination
	print(current_destination)
	navigation_agent.target_position = current_destination.global_position


func _arrive_at_destination() -> void:
	#print('arrived at waypoint')
	#velocity.x = 0.0
	#velocity.z = 0.0

	_choose_new_destination()


func _apply_gravity(delta: float) -> void:
	if not use_gravity:
		velocity.y = 0.0
		return

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity *10 * delta


func _stop_horizontal_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)


func _face_direction(direction: Vector3) -> void:
	var look_target: Vector3 = global_position + Vector3(direction.x, 0.0, direction.z)

	if look_target.distance_squared_to(global_position) > 0.001:
		look_at(look_target, Vector3.UP)
