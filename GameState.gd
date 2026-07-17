extends Node

var power_on := false
var debug : bool = false
var game_ended : bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('debug2'):
		toggle_debug()

func reset():
	await get_tree().create_timer(1).timeout
	get_tree().reload_current_scene()

func toggle_debug():
	if debug:
		debug = false
	else:
		debug = true

func on_toggle_game_ended():
	game_ended = true
	Signals.win.emit()
