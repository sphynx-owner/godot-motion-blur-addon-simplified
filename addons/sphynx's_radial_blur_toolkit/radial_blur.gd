@tool
class_name RadialBlur
extends Node3D

@export var target: MeshInstance3D:
	set(value):
		if target:
			target.visible = _past_target_visible_cache
		
		target = value
		
		if target:
			_past_target_visible_cache = target.visible
			target.visible = false
		
		update_configuration_warnings()

@export var enveloping_mesh: Mesh:
	set(value):
		enveloping_mesh = value
		
		update_configuration_warnings()

var _past_target_visible_cache: bool = false

var _viewport: SubViewport

var _camera: Camera3D

var _clone: MeshInstance3D

var _enveloping_node: MeshInstance3D

var _past_global_transform: Transform3D

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	
	add_child(_viewport)
	
	_camera = Camera3D.new()
	
	_viewport.add_child(_camera)
	
	_clone = MeshInstance3D.new()
	
	_viewport.add_child(_clone)
	
	_enveloping_node = MeshInstance3D.new()
	
	add_child(_enveloping_node)


func _process(delta: float) -> void:
	_update_viewport()
	_update_camera()
	_update_clone()
	_update_enveloping_node()


func _update_viewport() -> void:
	var reference_viewport: Viewport = get_viewport()
	
	if "size" in reference_viewport:
		_viewport.size = reference_viewport.size


func _update_camera() -> void:
	var reference_camera: Camera3D = get_viewport().get_camera_3d()
	
	_camera.global_transform = reference_camera.global_transform
	_camera.fov = reference_camera.fov
	_camera.projection = reference_camera.projection


func _update_clone() -> void:
	if !target:
		return
	
	_clone.global_transform = target.global_transform
	
	_clone.mesh = target.mesh
	
	for i: int in range(target.get_surface_override_material_count()):
		_clone.set_surface_override_material(i, target.get_surface_override_material(i))
	
	_clone.material_override = target.material_override
	
	_clone.material_overlay = target.material_overlay


func _update_enveloping_node() -> void:
	if !enveloping_mesh:
		return
	
	_enveloping_node.mesh = enveloping_mesh
	
	var target_transform : Transform3D = target.global_transform
	
	var target_rotation_vector : Vector3 = target_transform.orthonormalized().basis * target_local_rotation_vector
	
	var current_mesh_basis : Basis = target_transform.basis
	
	var difference_quat : Quaternion = Quaternion(current_mesh_basis.get_rotation_quaternion() * previous_mesh_basis.get_rotation_quaternion().inverse())
	
	var centered_angle : float = difference_quat.get_angle() - PI
	
	var angle = (PI - abs(centered_angle)) * abs(target_rotation_vector.dot(difference_quat.get_axis()))
	
	if mesh_has_rotation_signal:
		angle = signal_rotation_velocity
	
	get_surface_override_material(0).set_shader_parameter("rotation_speed", clamp(angle, -TAU, TAU))
	
	previous_mesh_basis = current_mesh_basis
	
	global_position = target_transform.origin + target_rotation_vector * axis_offset
	
	var alignment_quaternion : Quaternion = Quaternion(global_basis.orthonormalized() * local_rotation_vector, target_rotation_vector)
	
	global_basis = Basis(alignment_quaternion) * global_basis;
