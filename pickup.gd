extends Node3D


const ICON_SIZE := 128

@export var mesh : PackedScene
@export var id : Ids.OBJECTS = Ids.OBJECTS.NONE

var picked_up := false
var icon : Texture2D

@onready var area: Area3D = $Area3D

var mesh_instance : Node3D


func _ready():
	mesh_instance = mesh.instantiate()
	add_child(mesh_instance)
	_generate_icon()


func pick_up() -> void:
	if picked_up:
		return
	picked_up = true
	mesh_instance.queue_free()
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)


# Renders the pickup's 3D mesh into an offscreen viewport and bakes the
# result into a still Texture2D, so the inventory can show a 2D icon
# without anyone having to hand-author sprite art for every item.
func _generate_icon() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var preview := mesh.instantiate()
	viewport.add_child(preview)

	var bounds := _world_aabb(preview)
	var center := bounds.get_center()
	var radius : float = maxf(bounds.size.length() * 0.5, 0.05)
	var distance := radius * 3.0

	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = radius * 2.2
	camera.near = 0.01
	camera.far = distance + radius * 4.0
	camera.global_position = center + Vector3(1, 1, 1).normalized() * distance
	camera.look_at(center, Vector3.UP)
	camera.current = true

	var key_light := DirectionalLight3D.new()
	viewport.add_child(key_light)
	key_light.rotation_degrees = Vector3(-45, -45, 0)

	var fill_light := DirectionalLight3D.new()
	viewport.add_child(fill_light)
	fill_light.rotation_degrees = Vector3(-45, 135, 0)
	fill_light.light_energy = 0.5

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	icon = ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()


func _world_aabb(root: Node3D) -> AABB:
	var instances : Array[VisualInstance3D] = []
	_collect_visual_instances(root, instances)

	if instances.is_empty():
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

	var result : AABB = instances[0].global_transform * instances[0].get_aabb()
	for i in range(1, instances.size()):
		var instance := instances[i]
		result = result.merge(instance.global_transform * instance.get_aabb())
	return result


func _collect_visual_instances(node: Node, out: Array[VisualInstance3D]) -> void:
	if node is VisualInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_visual_instances(child, out)
