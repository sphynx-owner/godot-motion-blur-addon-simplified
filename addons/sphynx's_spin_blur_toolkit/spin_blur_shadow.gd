@tool
class_name SpinBlurShadow
extends Node3D

var SHADOW_MESH_INSTANCE_META: StringName = &"spin_blur_shadow_mesh_instance"

@export var spin_blur: SpinBlur

@export var target_mesh_instance: MeshInstance3D:
	get():
		if !target_mesh_instance and spin_blur and spin_blur.target is MeshInstance3D:
			return spin_blur.target
		
		return target_mesh_instance

@export var subdivisions: int = 20

@export_flags_3d_render var render_layers: int = 1

var _mesh_instances: Array[MeshInstance3D]


func _ready() -> void:
	process_priority = 2


func _process(delta: float) -> void:
	_update_meshes()


func _update_meshes() -> void:
	_clear_mesh_instances()
	
	if !spin_blur or !spin_blur.target or !target_mesh_instance:
		return
	
	var angle_interval: float = TAU / subdivisions
	
	var symmetry_mesh_count: int = floor((min(abs(spin_blur._rotation_speed_cache * spin_blur.blur_intensity), TAU) / 2.0) / angle_interval)
	
	_create_new_mesh_instance().global_transform = target_mesh_instance.global_transform
	
	for i in symmetry_mesh_count:
		var angle: float = angle_interval * (i + 1)
		
		var new_mesh_1: MeshInstance3D = _create_new_mesh_instance()
		new_mesh_1.global_position = target_mesh_instance.global_position
		new_mesh_1.global_basis = target_mesh_instance.global_basis.rotated(spin_blur._rotation_vector_cache, angle)
		
		var new_mesh_2: MeshInstance3D = _create_new_mesh_instance()
		new_mesh_2.global_position = target_mesh_instance.global_position
		new_mesh_2.global_basis = target_mesh_instance.global_basis.rotated(spin_blur._rotation_vector_cache, -angle)
	
	for mesh: MeshInstance3D in _mesh_instances:
		mesh.transparency = 1.0 - (spin_blur._fade_in_coef_cache * (1.0 - target_mesh_instance.transparency) / _mesh_instances.size())


func _create_new_mesh_instance() -> MeshInstance3D:
	var new_mesh_instance = MeshInstance3D.new()
	
	new_mesh_instance.mesh = target_mesh_instance.mesh
	
	new_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	
	for i in target_mesh_instance.get_surface_override_material_count():
		new_mesh_instance.set_surface_override_material(i, target_mesh_instance.get_surface_override_material(i))
	
	new_mesh_instance.set_meta(SHADOW_MESH_INSTANCE_META, true)
	
	new_mesh_instance.layers = render_layers
	
	add_child(new_mesh_instance)
	
	_mesh_instances.append(new_mesh_instance)
	
	return new_mesh_instance


func _clear_mesh_instances() -> void:
	for child in get_children():
		if child.has_meta(SHADOW_MESH_INSTANCE_META):
			child.get_parent().remove_child(child)
			child.queue_free()
	
	_mesh_instances.clear()
