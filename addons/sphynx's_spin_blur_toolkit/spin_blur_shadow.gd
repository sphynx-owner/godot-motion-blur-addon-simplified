@tool
class_name SpinBlurShadow
extends Node3D

@export var spin_blur: SpinBlur

@export var target_mesh_instance: MeshInstance3D

@export var angle_subdivisions: int = 20

@export var max_angle: float = 0

@export var material_override: Material

var _mesh_instances: Array[MeshInstance3D]


func _ready() -> void:
	process_priority = 2


func _process(delta: float) -> void:
	_update_meshes()


func _update_meshes() -> void:
	_clear_mesh_instances()
	
	if !spin_blur or !spin_blur.target or !target_mesh_instance:
		return
	
	var angle_interval: float = TAU / angle_subdivisions
	
	var symmetry_mesh_count: int = floor((abs(spin_blur._rotation_speed_cache) / 2.0) / angle_interval)
	
	_create_new_mesh_instance().global_transform = target_mesh_instance.global_transform
	
	for i in symmetry_mesh_count:
		_create_new_mesh_instance().global_transform = target_mesh_instance.global_transform.rotated(spin_blur._rotation_vector_cache, angle_interval * (i + 1))
		_create_new_mesh_instance().global_transform = target_mesh_instance.global_transform.rotated(spin_blur._rotation_vector_cache, -angle_interval * (i + 1))
	
	print(_mesh_instances.size())
	
	for mesh: MeshInstance3D in _mesh_instances:
		mesh.transparency = 1.0 - (1.0 / _mesh_instances.size())


func _create_new_mesh_instance() -> MeshInstance3D:
	var new_mesh_instance = MeshInstance3D.new()
	
	new_mesh_instance.mesh = target_mesh_instance.mesh
	
	#new_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	
	new_mesh_instance.set_surface_override_material(0, target_mesh_instance.get_surface_override_material(0))
	
	add_child(new_mesh_instance)
	
	_mesh_instances.append(new_mesh_instance)
	
	return new_mesh_instance


func _clear_mesh_instances() -> void:
	for mesh in _mesh_instances:
		mesh.get_parent().remove_child(mesh)
		mesh.queue_free()
	
	_mesh_instances.clear()
