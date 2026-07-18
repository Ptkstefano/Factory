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

var shoot_count : int = 0

var shoot_distance = 25

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

var sound_area : Ids.SOUND_AREAS = Ids.SOUND_AREAS.INSIDE

func _ready() -> void:
	randomize()

	_refresh_destinations()

	# Wait one physics frame so the navigation map is ready.
	await get_tree().physics_frame
	
	$StateTimer.timeout.connect(on_state_timer_timeout)
	
	change_state(STATES.IDLE)

	player = get_tree().get_first_node_in_group('Player')
	
	%SoundArea.area_entered.connect(on_sound_area_entered)
	%SoundArea.area_exited.connect(on_sound_area_exited)
	Signals.alert_enemy.connect(on_alert_enemy)
	Signals.win.connect(on_game_ended)
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug3"):
		if !%Debug.visible:
			%Debug.show()
		else:
			%Debug.hide()

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
			shoot_count = 0
			change_state(STATES.PATROLLING)
	elif state == STATES.INVESTIGATING:
		var horizontal_speed = Vector3(velocity.x, 0.0, velocity.z).length()
		%AnimationTree.set("parameters/Chase/blend_position",horizontal_speed - 1)
		move_towards_destination(delta)
	elif state == STATES.SHOOTING:
		look_at(player.global_position)
		## Makes enemy rush the player if they shot too many times and didn't kill
		if shoot_count > 4:
			shoot_distance = 2
		else:
			shoot_distance = 25
			
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
			if !GameState.game_ended:
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
		STATES.INVESTIGATING:
			%AnimationTree.get('parameters/playback').start("Chase")
			%StateLabel.text='INVESTIGATING'
			return
		STATES.SHOOTING:
			%AnimationTree.get('parameters/playback').start("Shoot")
			%StateLabel.text='SHOOTING'
			%AnimationTree.set("parameters/Shoot/blend_position",1)
			return

func on_alert_enemy(alert_position):
	if state in [STATES.IDLE, STATES.PATROLLING]:
		print('enemy alerted')
		navigation_agent.target_position = alert_position
		change_state(STATES.INVESTIGATING)

func update_line_of_sight():
	## Esse offset faz o raycast ir de cima pra baixo em uma sinewave pra você não poder se esconder escondendo só a cabeça
	var height_offset := 1 + sin(
	Time.get_ticks_msec() / 1000.0 * TAU * 2
	) * 0.3
	
	var target_global_position = player.global_position + Vector3.UP * height_offset


	raycast.target_position = raycast.to_local(target_global_position)
	raycast.force_raycast_update()
	
func update_detection_progress(delta):
	if player.is_dead:
		detection_progress = 0
		return
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is Player:
			if player.is_dead:
				return
			set_audio_ducking(true)
			var direction_to_player := global_position.direction_to(player.global_position)
			var enemy_forward := -global_transform.basis.z.normalized()
			if enemy_forward.dot(direction_to_player) < 0.0:
				if global_position.distance_to(player.global_position) < 5:
					increase_detection_progress(delta)
				else:
					if player.is_flashlight_on:
						increase_detection_progress(delta)
					else:
						raycast.debug_shape_custom_color = Color.YELLOW
						detection_progress -= delta * 10
			else:
				increase_detection_progress(delta)
				raycast.debug_shape_custom_color = Color.RED
		else:
			#print(collider)
			set_audio_ducking(false)
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
	elif state in [STATES.CHASING, STATES.INVESTIGATING]:
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
	
	var detection_multiplier = 1
	
	
	if player.is_flashlight_on:
		detection_multiplier += 1
	else:
		if global_position.distance_to(player.global_position) > 15:
			detection_multiplier -= 1

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
	

	detection_progress += delta * detection_speed * detection_multiplier
	
	if state == STATES.PATROLLING or state == STATES.INVESTIGATING:
		if detection_progress >= 99:
			change_state(STATES.CHASING)
		elif detection_progress > 70:
			navigation_agent.target_position = player.global_position

func check_for_shot():
	if raycast.is_colliding():
		if raycast.get_collider() is Player:
			if global_position.distance_to(player.global_position) < shoot_distance:
				change_state(STATES.SHOOTING)

func shot_ended():
	change_state(STATES.CHASING)

func play_gunshot():
	%Gunshot.play()
	
	fire_shotgun()
	%GPUParticles3D.restart()
	%GPUParticles3D.emitting = true
	
	%Flash.show()
	await get_tree().create_timer(0.1).timeout
	%Flash.hide()

func play_footstep():
	if state == STATES.PATROLLING:
		if sound_area == Ids.SOUND_AREAS.INSIDE:
			%Footstep_Concrete.play()
		elif sound_area == Ids.SOUND_AREAS.COURTYARD:
			%Footstep_Grass.play()
	elif state == STATES.CHASING:
		if sound_area == Ids.SOUND_AREAS.INSIDE:
			%FootstepRun_Concrete.play()
		elif sound_area == Ids.SOUND_AREAS.COURTYARD:
			%FootstepRun_Grass.play()

func set_audio_ducking(has_line_of_sight):
	var bus_index = AudioServer.get_bus_index("Enemy")

	var current_volume := AudioServer.get_bus_volume_db(bus_index)
	if has_line_of_sight:
		var new_volume := lerpf(
			current_volume,
			0,
			0.1
		)
		AudioServer.set_bus_volume_db(bus_index, new_volume)
	else:
		var new_volume := lerpf(
			current_volume,
			-10,
			0.1
		)
		AudioServer.set_bus_volume_db(bus_index, new_volume)

func on_sound_area_entered(area):
	if area is SoundArea:
		sound_area = area.id

func on_sound_area_exited(area):
	if area is SoundArea:
		sound_area = Ids.SOUND_AREAS.INSIDE

func fire_shotgun() -> void:
	shoot_count += 1
	
	var fire_position = %ShotgunMuzzle.global_position
	
	
	
	var space_state := get_world_3d().direct_space_state
	var center_direction = fire_position.direction_to(player.global_position)
	

	var pellet_count = 12
	var spread_degrees = 7.5
	var shotgun_collision_mask = 1
	var shotgun_range = 100

	for pellet_index in pellet_count:
		var pellet_direction := get_scattered_direction(
			center_direction,
			spread_degrees
		)

		var ray_end = fire_position + pellet_direction * shotgun_range

		var query := PhysicsRayQueryParameters3D.create(
			fire_position,
			ray_end,
			shotgun_collision_mask
		)

		# Prevent the enemy from shooting itself.
		query.exclude = [self]

		var result := space_state.intersect_ray(query)

		if result.is_empty():
			# Red means the pellet did not hit anything.
			draw_debug_ray(
				fire_position,
				ray_end,
				Color.LIME_GREEN,
				0.75
			)

			continue
			
		var collider: Object = result["collider"]
		var hit_position: Vector3 = result["position"]
		var hit_normal: Vector3 = result["normal"]
		
		if collider is Player:
			draw_debug_ray(
				fire_position,
				hit_position,
				Color.RED,
				0.75
			)
		else:
				draw_debug_ray(
				fire_position,
				ray_end,
				Color.LIME_GREEN,
				0.75
			)

		handle_pellet_hit(
			collider,
			hit_position,
			hit_normal,
			pellet_direction
		)
		
func get_scattered_direction(
	center_direction: Vector3,
	spread_angle_degrees: float
) -> Vector3:
	var forward := center_direction.normalized()

	# Creates vectors perpendicular to the shooting direction.
	var reference_up := Vector3.UP

	# Avoid problems when firing almost directly upward or downward.
	if abs(forward.dot(reference_up)) > 0.99:
		reference_up = Vector3.RIGHT

	var right := forward.cross(reference_up).normalized()
	var up := right.cross(forward).normalized()

	# sqrt() distributes pellets evenly across the circular spread.
	# Without sqrt(), too many pellets would cluster near the center.
	var random_radius := sqrt(randf())
	var random_angle := randf_range(0.0, TAU)

	var spread_radius := tan(deg_to_rad(spread_angle_degrees))

	var horizontal_offset := (
		cos(random_angle)
		* random_radius
		* spread_radius
	)

	var vertical_offset := (
		sin(random_angle)
		* random_radius
		* spread_radius
	)

	return (
		forward
		+ right * horizontal_offset
		+ up * vertical_offset
	).normalized()

func handle_pellet_hit(
	collider: Object,
	hit_position: Vector3,
	hit_normal: Vector3,
	pellet_direction: Vector3
) -> void:
	if collider is Player:
		collider.take_damage()

	# Optional impact effect.
	#spawn_impact_effect(hit_position, hit_normal)
	
func draw_debug_ray(
	from: Vector3,
	to: Vector3,
	color: Color = Color.RED,
	duration: float = 0.5
) -> void:
	if !GameState.debug:
		return
	var immediate_mesh := ImmediateMesh.new()

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# The vertices are local to the MeshInstance3D.
	immediate_mesh.surface_add_vertex(Vector3.ZERO)
	immediate_mesh.surface_add_vertex(to - from)

	immediate_mesh.surface_end()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color

	# Makes the rays visible even when they are behind walls.
	# Remove this if you want normal depth/occlusion behavior.
	material.no_depth_test = true

	var line := MeshInstance3D.new()
	line.mesh = immediate_mesh
	line.material_override = material

	get_tree().current_scene.add_child(line)
	line.global_position = from

	# Automatically remove the debug line.
	get_tree().create_timer(duration).timeout.connect(line.queue_free)

func on_game_ended():
	change_state(STATES.IDLE)
