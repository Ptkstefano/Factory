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
