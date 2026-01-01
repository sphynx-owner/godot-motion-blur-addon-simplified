@tool
extends Node3D

@export var element_scene: PackedScene = preload("res://benchmarks/falling_cubes/cube.tscn")

@export var cluster_size: Vector3i = Vector3i(10, 5, 10)

@export var cluster_separation: Vector3 = Vector3(1, 1, 1)

@export var cluster_padding: Vector3 = Vector3(0.1, 0.1, 0.1)

@export var spawn_at_start: bool = true

@export_tool_button("spawn") var spawn = spawn_cubes

var _all_spawned_elements: Array[Node3D]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if spawn_at_start:
		spawn_cubes.call_deferred()


func clear_cubes() -> void:
	for element in _all_spawned_elements:
		element.queue_free()
	
	_all_spawned_elements.clear()


func spawn_cubes() -> void:
	var cluster_extent: Vector3 = \
	Vector3(cluster_size) * cluster_separation + \
	Vector3(cluster_size - Vector3i(1, 1, 1)) * cluster_padding
	
	var cluster_half_extent: Vector3 = cluster_extent / 2
	var cluster_interval: Vector3 = cluster_separation + cluster_padding
	
	for x in cluster_size.x:
		for y in cluster_size.y:
			for z in cluster_size.z:
				var index_position: Vector3 = Vector3(x, y, z)
				var element_position: Vector3 = index_position * cluster_interval - cluster_half_extent
				var element_global_transform: Transform3D = \
				transform * Transform3D(Basis(), element_position)
				
				var new_element: Node3D = element_scene.instantiate()
				
				get_parent().add_child(new_element)
				
				new_element.transform = element_global_transform
				
				_all_spawned_elements.append(new_element)
