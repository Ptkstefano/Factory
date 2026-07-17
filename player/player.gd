extends CharacterBody3D

class_name Player

var BOB_FREQ = 2.0
var BOB_AMP = 0.06

var current_speed = 3.0
var player_speed = 3.0
var player_run_speed = 5.0

const STAND_HEIGHT = 2.0
const CROUCH_HEIGHT = 1.2
const STAND_CAM_Y = 1.418331
const CROUCH_CAM_Y = 0.75
const CROUCH_SPEED = 10.0

var bob_time := 0.0
var camera_base_y := STAND_CAM_Y
var camera_target_y := STAND_CAM_Y

var is_crouching := false
var is_flashlight_on := false

var current_interactable : Node3D = null
var inventory : Array[Ids.OBJECTS] = []

var has_flashlight : bool = false

var times_hit : int = 0

var is_dead : bool = false

@export var set_camera_as_active : bool = true

@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var hint_prompt: Label = $PickupPrompt
@onready var inventory_box: HBoxContainer = $Inventory

var sound_area : Ids.SOUND_AREAS = Ids.SOUND_AREAS.INSIDE

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_y = %Camera3D.position.y
	camera_target_y = camera_base_y
	$InteractArea.area_entered.connect(on_interact_area_entered)
	$InteractArea.area_exited.connect(on_interact_area_exited)
	%flashlight.hide()
	%FootstepTimer.timeout.connect(play_footstep)
	%SoundArea.area_entered.connect(on_sound_area_entered)
	%SoundArea.area_exited.connect(on_sound_area_exited)
	%FlashlightHintTimer.timeout.connect(hide_flashlight_hint)
	Signals.power_on.connect(turn_off_flashlight)
	
	if set_camera_as_active:
		%Camera3D.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * 0.3
		%Camera3D.rotation_degrees.x -= event.relative.y * 0.2
		%Camera3D.rotation_degrees.x = clamp(%Camera3D.rotation_degrees.x, -80, 80)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("crouch"):
		if is_crouching:
			_try_stand()
		else:
			_crouch()
	elif event.is_action_pressed('sprint'):
		current_speed = player_run_speed
	elif event.is_action_released('sprint'):
		current_speed = player_speed
	elif event.is_action_pressed('flashlight'):
		if !has_flashlight:
			return
		if %flashlight.visible:
			turn_off_flashlight()
		else:
			turn_on_flashlight()
	elif event.is_action_pressed("interact") and current_interactable:
		_interact_with_current_interactable()
	elif event.is_action_pressed("debug1"):
		debug_add_items()
	elif event.is_action_pressed('lmb'):
		print('lmb')
		if is_dead:
			GameState.reset()

func _crouch() -> void:
	is_crouching = true
	%FootstepTimer.wait_time = 1
	BOB_FREQ = 1.0
	camera_target_y = CROUCH_CAM_Y
	col_shape.shape.height = CROUCH_HEIGHT
	col_shape.position.y = CROUCH_HEIGHT / 2.0

func _try_stand() -> void:
	if _has_space_to_stand():
		is_crouching = false
		%FootstepTimer.wait_time = 0.5
		BOB_FREQ = 2.0
		camera_target_y = STAND_CAM_Y
		col_shape.shape.height = STAND_HEIGHT
		col_shape.position.y = STAND_HEIGHT / 2.0

func _has_space_to_stand() -> bool:
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, CROUCH_HEIGHT * 0.5, 0),
		global_position + Vector3(0, STAND_HEIGHT + 0.1, 0)
	)
	params.exclude = [self]
	return space.intersect_ray(params).is_empty()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var speed = current_speed * (0.6 if is_crouching else 1.0)
	var input_direction_2d = Input.get_vector("move_left","move_right","move_forward","move_back")
	var input_direction_3d = Vector3(input_direction_2d.x, 0, input_direction_2d.y)
	var direction = transform.basis * input_direction_3d

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= 20 * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = 5
	elif Input.is_action_just_released("jump") and velocity.y > 0:
		velocity.y = 0

	if Vector2(velocity.x, velocity.z).length() > 0.1:
		if %FootstepTimer.is_stopped():
			%FootstepTimer.start()
	else:
		%FootstepTimer.stop()
		
	move_and_slide()
	_update_headbob(delta)

func _update_headbob(delta: float) -> void:
	camera_base_y = lerpf(camera_base_y, camera_target_y, delta * CROUCH_SPEED)

	var is_moving = is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.1
	if is_moving:
		bob_time += delta * BOB_FREQ * PI
		%Camera3D.position.y = camera_base_y + sin(bob_time * 2.0) * BOB_AMP
	else:
		bob_time = 0.0
		%Camera3D.position.y = lerpf(%Camera3D.position.y, camera_base_y, delta * 10.0)

func on_interact_area_entered(area: Area3D) -> void:
	var interactable = area.get_parent()
	if interactable is Pickup:
		current_interactable = interactable
		hint_prompt.text = "Press F to pickup %s" % Ids.get_object_name(interactable.id)
		hint_prompt.visible = true
	if interactable is InteractableArea and not interactable.activated:
		current_interactable = interactable
		if interactable.id == Ids.INTERACTABLE_AREAS.FLASHLIGHT:
			hint_prompt.text = "Press F to pickup flashlight"
			hint_prompt.visible = true
		elif interactable.id == Ids.INTERACTABLE_AREAS.CROWBAR_DOOR:
			hint_prompt.text = "Press F to break open the door"
			hint_prompt.visible = true
		elif interactable.id == Ids.INTERACTABLE_AREAS.KEY_DOOR:
			hint_prompt.text = "Press F to open the door"
			hint_prompt.visible = true
		elif interactable.id == Ids.INTERACTABLE_AREAS.POWER_GENERATOR:
			hint_prompt.text = "Press F to turn on the power"
			hint_prompt.visible = true
		elif interactable.id == Ids.INTERACTABLE_AREAS.GATE_BUTTON:
			hint_prompt.text = "Press F to open the gates"
			hint_prompt.visible = true
		elif interactable.id == Ids.INTERACTABLE_AREAS.WIN:
			%WinHint.show()
			GameState.on_toggle_game_ended()
			

func on_interact_area_exited(area: Area3D) -> void:
	#var pickup = area.get_parent()
	hint_prompt.visible = false
	current_interactable = null
	#if pickup == current_interactable:

func _interact_with_current_interactable() -> void:
	var interactable = current_interactable

	if interactable is InteractableArea and not interactable.has_pre_requisites(inventory):
		if interactable.id == Ids.INTERACTABLE_AREAS.GATE_BUTTON and not GameState.power_on:
			hint_prompt.text = "You need to turn on the power first!"
		else:
			var missing_name = Ids.get_object_name(interactable.pre_requisites[0])
			hint_prompt.text = "You need the %s. Go find it first!" % missing_name
		hint_prompt.visible = true
		return

	current_interactable = null
	hint_prompt.visible = false

	if interactable is Pickup:
		inventory.append(interactable.id)
		_add_inventory_slot(interactable)
		interactable.pick_up()

	if interactable is InteractableArea:
		if interactable.id == Ids.INTERACTABLE_AREAS.FLASHLIGHT:
			has_flashlight = true
			turn_on_flashlight()
			show_flashlight_hint()
			inventory.append(Ids.OBJECTS.FLASHLIGHT)
		interactable.activate()

func turn_on_flashlight():
	%flashlight.show()
	is_flashlight_on = true
	
func turn_off_flashlight():
	%flashlight.hide()
	if GameState.power_on:
		is_flashlight_on = true
		return
	is_flashlight_on = false

func show_flashlight_hint() -> void:
	%FlashlightHint.visible = true
	%FlashlightHintTimer.start()

func hide_flashlight_hint() -> void:
	%FlashlightHint.visible = false

func _add_inventory_slot(pickup) -> void:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.tooltip_text = Ids.get_object_name(pickup.id)

	if pickup.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = pickup.icon
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon_rect)
	else:
		var label := Label.new()
		label.text = Ids.get_object_name(pickup.id)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		slot.add_child(label)

	inventory_box.add_child(slot)

func play_footstep():
	if sound_area == Ids.SOUND_AREAS.INSIDE:
		if Vector2(velocity.x, velocity.z).length() < 4.0:
			%Footstep_concrete.play()
		else:
			%Footstep_run_concrete.play()
	else:
		%Footstep_grass.play()
		
func on_sound_area_entered(area):
	if area is SoundArea:
		sound_area = area.id

func on_sound_area_exited(area):
	if area is SoundArea:
		sound_area = Ids.SOUND_AREAS.INSIDE

func take_damage():
	times_hit += 1
	start_damage_flash()
	make_hurt()
	if times_hit >= 2:
		make_dead()
		print('DEAD')

func make_hurt():
	player_speed = 2.0
	player_run_speed = 3.5

func make_dead():
	%DamageRect.color = Color(0.0, 0.0, 0.0, 0.8)
	%Camera3D.position.y = 0.2
	%flashlight.hide()
	#process_mode = Node.PROCESS_MODE_DISABLED
	is_dead = true

func start_damage_flash() -> void:
	
	var maximum_alpha: float = 0.1
	var minimum_alpha: float = 0.05
	var flash_speed: float = 0.8

	%DamageRect.visible = true
	%DamageRect.color = Color(1.0, 0.0, 0.0, minimum_alpha)

	var flash_tween = create_tween()
	flash_tween.set_loops()

	flash_tween.tween_property(
		%DamageRect,
		"color:a",
		maximum_alpha,
		flash_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	flash_tween.tween_property(
		%DamageRect,
		"color:a",
		minimum_alpha,
		flash_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func debug_add_items():
	print('adding items')
	inventory = [Ids.OBJECTS.CROWBAR, Ids.OBJECTS.KEY, Ids.OBJECTS.FUEL]
