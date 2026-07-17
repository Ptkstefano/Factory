extends Node3D

class_name InteractableArea


@export var id : Ids.INTERACTABLE_AREAS
@export var pre_requisites : Array[Ids.OBJECTS] = []

var activated : bool = false

func has_pre_requisites(inventory: Array[Ids.OBJECTS]) -> bool:
	if id == Ids.INTERACTABLE_AREAS.GATE_BUTTON and not GameState.power_on:
		return false
	for pre_requisite in pre_requisites:
		if not inventory.has(pre_requisite):
			return false
	return true

func activate():
	if activated:
		return
	activated = true
	if id == Ids.INTERACTABLE_AREAS.FLASHLIGHT:
		queue_free()
	if id == Ids.INTERACTABLE_AREAS.CROWBAR_DOOR:
		%CrowbarDoorAnimation.play('fall_down')
		%CrowbarDoorSFX.play()
		await %CrowbarDoorAnimation.animation_finished
		%CrowbarDoorCollision.queue_free()
		Signals.bake_navmesh.emit()
		await get_tree().create_timer(3).timeout
		alert_enemy(%CrowbarDoorWaypoint.global_position)
	if id == Ids.INTERACTABLE_AREAS.KEY_DOOR:
		%KeyDoorAnimation.play('open_door')
		%KeyDoorSFX.play()
		await %KeyDoorAnimation.animation_finished
		## Signals.bake_navmesh.emit()
		## call_deferred('alert_enemy')
	if id == Ids.INTERACTABLE_AREAS.POWER_GENERATOR:
		%GeneratorSFX.play()
		GameState.power_on = true
		Signals.power_on.emit()
	if id == Ids.INTERACTABLE_AREAS.GATE_BUTTON:
		%GateButtonAnimation.play('open_gate')
		%GateSFX.play()

func alert_enemy(pos):
	Signals.alert_enemy.emit(pos)
