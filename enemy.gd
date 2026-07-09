extends CharacterBody3D

@export var move_speed: float = 2.0
@export var acceleration: float = 2.0

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
	PATROLLING,
	INVESTIGATING,
	CHASING,
	SHOOTING
}

var state : STATES = STATES.IDLE

var walk_blend = 0

func _ready() -> void:
	randomize()

	_refresh_destinations()

	# Wait one physics frame so the navigation map is ready.
	await get_tree().physics_frame
	
	$StateTimer.timeout.connect(on_state_timer_timeout)
	
	## TODO - Do this when player seems him first time
	$StateTimer.start(5)
	
	%AnimationTree.get('parameters/playback').start("WalkAnim")

func _physics_process(delta: float) -> void:
	
	var horizontal_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	%AnimationTree.set("parameters/WalkAnim/blend_position", horizontal_speed - 1)
	
	if state == STATES.PATROLLING:
		move_towards_destination(delta)

	else:
		stop_moving(delta)

func change_state(new_state : STATES):
	match new_state:
		STATES.IDLE:
			$StateTimer.start()
			return
		


func on_state_timer_timeout():
	if state == STATES.IDLE:
		_choose_new_destination()

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

	direction.y = 0.0

	direction = direction.normalized()
	

	var desired_velocity: Vector3 = direction * move_speed

	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	
	#velocity = direction * 20


	if rotate_towards_movement:
		_face_direction(direction, delta)

	_apply_gravity(delta)
	move_and_slide()
	
func stop_moving(delta):
	velocity.x = move_toward(velocity.x, 0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0, acceleration * delta)
	
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
	
	change_state(STATES.PATROLLING)



func _arrive_at_destination() -> void:
	#print('arrived at waypoint')
	#velocity.x = 0.0
	#velocity.z = 0.0

	change_state(STATES.IDLE)
	#_choose_new_destination()


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


func _face_direction(direction: Vector3, delta: float) -> void:
	
	var turn_speed: float = 2.0
	var flat_direction := Vector3(direction.x, 0.0, direction.z)

	if flat_direction.length_squared() < 0.001:
		return

	flat_direction = flat_direction.normalized()

	var target_y_rotation := atan2(-flat_direction.x, -flat_direction.z)
	var weight := 1.0 - exp(-turn_speed * delta)

	rotation.y = lerp_angle(rotation.y, target_y_rotation, weight)
