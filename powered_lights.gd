extends Node3D

func _ready():
	hide()
	Signals.power_on.connect(show)
