extends InteractableArea

class_name Door

@export var open_angle_degrees : float = -90.0
@export var open_duration : float = 1.0


func activate():
	if activated:
		return
	super.activate()
	var target_rotation_y = rotation.y + deg_to_rad(open_angle_degrees)
	create_tween().tween_property(self, "rotation:y", target_rotation_y, open_duration)
