@tool
class_name PoleGenerator
extends Node3D

@export var path: Path3D:
	set(value):
		if path and path.curve_changed.is_connected(generate_poles):
			path.curve_changed.disconnect(generate_poles)
		
		path = value
		
		if path and !path.curve_changed.is_connected(generate_poles):
			path.curve_changed.connect(generate_poles)
		
		update_configuration_warnings()
		
		generate_poles()


@export var pole_scene: PackedScene:
	set(value):
		pole_scene = value
		
		update_configuration_warnings()
		
		generate_poles()


@export var distance_interval: float = 50:
	set(value):
		distance_interval = abs(value)
		generate_poles()

@export_storage var _current_poles: Array[Node]


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		generate_poles()


func _get_configuration_warnings() -> PackedStringArray:
	var ret: PackedStringArray
	
	if path == null:
		ret.append("must have path set")
	
	if pole_scene == null:
		ret.append("pole scene must be set")
	
	return ret


func clear_poles() -> void:
	for pole in _current_poles:
		pole.queue_free()
	
	_current_poles.clear()


func generate_poles() -> void:
	if path == null or pole_scene == null:
		return
	
	var curve: Curve3D = path.curve
	
	var length: float = curve.get_baked_length()
	
	var pole_amount: int = floor(length / distance_interval)
	
	for i in pole_amount:
		var current_offset: float = i * distance_interval
		
		var new_pole_transform: Transform3D = curve.sample_baked_with_rotation(current_offset)
		
		var new_pole: Node = pole_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
		
		add_child.call_deferred(new_pole)
		
		new_pole.transform = new_pole_transform
		
		_current_poles.append(new_pole)
