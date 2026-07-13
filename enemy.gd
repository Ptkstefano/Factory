extends CharacterBody3D

var patrol_speed: float = 2.0
var acceleration: float = 2.0

var run_speed : float = 4.5

var wait_time_min: float = 0.5
var wait_time_max: float = 2.0

var use_gravity: bool = true
var rotate_towards_movement: bool = true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

var destinations: Array[Node3D] = []
var current_destination: Node3D = null

var detection_progress : float = 0:
	set(value):
		detection_progress = clampf(value,0, 100)

@onready var raycast = %RayCast3D
var player

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
	
	change_state(STATES.IDLE)

	player = get_tree().get_first_node_in_group('Player')

func _physics_process(delta: float) -> void:
	
	if state == STATES.IDLE:
		%AnimationTree.set("parameters/Patrol/blend_position", -1)
	elif state == STATES.PATROLLING:
		var horizontal_speed = Vector3(velocity.x, 0.0, velocity.z).length()
		%AnimationTree.set("parameters/Patrol/blend_position", horizontal_speed - 1)
		move_towards_destination(delta)
		
	elif state == STATES.CHASING:
		var horizontal_speed = Vector3(velocity.x, 0.0, velocity.z).length()
		%AnimationTree.set("parameters/Chase/blend_position",horizontal_speed - 1)
		navigation_agent.target_position = player.global_position
		move_towards_destination(delta)
		if detection_progress >= 99:
			check_for_shot()
		if detection_progress <= 1:
			change_state(STATES.PATROLLING)
	elif state == STATES.SHOOTING:
		look_at(player.global_position)
	else:
		stop_moving(delta)
		
	if not is_instance_valid(player):
		return

	update_line_of_sight()
	update_detection_progress(delta)

func change_state(new_state : STATES):
	state = new_state
	print('NEW STATE: ' + str(state))
	match new_state:
		STATES.IDLE:
			$StateTimer.start()
			%AnimationTree.get('parameters/playback').start("Patrol")
			%StateLabel.text='IDLE'
			return
		STATES.PATROLLING:
			_choose_new_patrol_destination()
			%AnimationTree.get('parameters/playback').start("Patrol")
			%StateLabel.text='PATROLLING'
			return
		STATES.CHASING:
			%AnimationTree.get('parameters/playback').start("Chase")
			%StateLabel.text='CHASING'
			return
		STATES.SHOOTING:
			%AnimationTree.get('parameters/playback').start("Shoot")
			%StateLabel.text='SHOOTING'
			%AnimationTree.set("parameters/Shoot/blend_position",1)
			return

func update_line_of_sight():
	## Esse offset faz o raycast ir de cima pra baixo em uma sinewave pra você não poder se esconder escondendo só a cabeça
	var height_offset := 1 + sin(
	Time.get_ticks_msec() / 1000.0 * TAU * 2
	) * 0.3
	
	var target_global_position = player.global_position + Vector3.UP * height_offset


	raycast.target_position = raycast.to_local(target_global_position)
	raycast.force_raycast_update()
	
func update_detection_progress(delta):
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is Player:
			var direction_to_player := global_position.direction_to(player.global_position)
			var enemy_forward := -global_transform.basis.z.normalized()
			if enemy_forward.dot(direction_to_player) < 0.0:
				raycast.debug_shape_custom_color = Color.YELLOW
				detection_progress -= delta * 10
			else:
				#detection_progress += delta * 10 * global_position.distance_to(player.global_position)
				increase_detection_progress(delta)
				raycast.debug_shape_custom_color = Color.RED
		else:
			#print(collider)
			detection_progress -= delta * 10
			raycast.debug_shape_custom_color = Color.BLUE

	%ProgressBar.value = detection_progress

func on_state_timer_timeout():
	if state == STATES.IDLE:
		change_state(STATES.PATROLLING)

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
	
	
	var desired_velocity : Vector3
	if state == STATES.PATROLLING:
		desired_velocity = direction * patrol_speed
	elif state == STATES.CHASING:
		desired_velocity = direction * run_speed

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

func _choose_new_patrol_destination() -> void:
	
	if destinations.is_empty():
		_refresh_destinations()

	if destinations.is_empty():
		return

	var chosen_destination: Node3D = destinations.pick_random()

	if destinations.size() > 1:
		while chosen_destination == current_destination:
			chosen_destination = destinations.pick_random()

	current_destination = chosen_destination
	navigation_agent.target_position = current_destination.global_position
	
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

func increase_detection_progress(delta: float) -> void:
	var minimum_detection_speed: float = 5.0
	var maximum_detection_speed: float = 100.0

	var minimum_distance: float = 1.0
	var maximum_distance: float = 30.0

	## Lower is faster
	var distance_exponent: float = 0.75
	
	
	var distance_to_player := global_position.distance_to(
		player.global_position
	)

	var clamped_distance := clampf(
		distance_to_player,
		minimum_distance,
		maximum_distance
	)

	var closeness := inverse_lerp(
		maximum_distance,
		minimum_distance,
		clamped_distance
	)

	var curved_closeness := pow(closeness, distance_exponent)

	var detection_speed := lerpf(
		minimum_detection_speed,
		maximum_detection_speed,
		curved_closeness
	)
	

	detection_progress += delta * detection_speed
	
	if state == STATES.PATROLLING:
		if detection_progress >= 99:
			change_state(STATES.CHASING)
		elif detection_progress > 70:
			navigation_agent.target_position = player.global_position

func check_for_shot():
	if raycast.is_colliding():
		if raycast.get_collider() is Player:
			if global_position.distance_to(player.global_position) < 25:
				change_state(STATES.SHOOTING)

func shot_ended():
	change_state(STATES.CHASING)

func play_gunshot():
	%Gunshot.play()
	
	%Flash.show()
	await get_tree().create_timer(0.1).timeout
	%Flash.hide()
