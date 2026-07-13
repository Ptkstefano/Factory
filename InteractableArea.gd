extends Node3D

class_name InteractableArea


@export var id : Ids.INTERACTABLE_AREAS

var activated : bool = false

var pre_requisites : Array[Ids.OBJECTS] = []

func activate():
	if activated:
		return
	activated = true
	if id == Ids.INTERACTABLE_AREAS.FLASHLIGHT:
		queue_free()
