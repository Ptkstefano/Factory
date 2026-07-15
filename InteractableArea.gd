extends Node3D

class_name InteractableArea


@export var id : Ids.INTERACTABLE_AREAS
@export var pre_requisites : Array[Ids.OBJECTS] = []

var activated : bool = false

func has_pre_requisites(inventory: Array[Ids.OBJECTS]) -> bool:
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
		await %CrowbarDoorAnimation.animation_finished
		%CrowbarDoorCollision.queue_free()
		Signals.bake_navmesh.emit()
		call_deferred('alert_enemy')
		

func alert_enemy():
	Signals.alert_enemy.emit(global_position)
