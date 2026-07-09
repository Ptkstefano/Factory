extends Node3D


@export var mesh : PackedScene
@export var object_name : String
#@export var id : Ids.OBJECTS


func _ready():
	var mesh_instance = mesh.instantiate()
	add_child(mesh_instance)
