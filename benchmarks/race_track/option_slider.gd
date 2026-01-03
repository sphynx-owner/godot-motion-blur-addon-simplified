@tool
class_name OptionSlider
extends HBoxContainer

signal value_changed(value: float)

@export var option_name: String:
	set(value):
		option_name = value
		
		$Label.text = option_name
		
		name = option_name.capitalize().replace(" ", "") + "OptionSlider"
		
		update_configuration_warnings()

@export var target_node: Node:
	set(value):
		target_node = value
		
		update_configuration_warnings()

@onready var h_slider: HSlider = $HSlider

@export_storage var _custom_property_list_values: Dictionary[String, Variant]

var _custom_property_list: Dictionary[String, Dictionary]

var _reset_value: Variant


func _init() -> void:
	var temp_property_list: Array[Dictionary] = ClassDB.class_get_property_list("Range")
	var control_property_list: Array[Dictionary] = ClassDB.class_get_property_list("Control")
	
	for property in control_property_list:
		temp_property_list.erase(property)
	
	for property in temp_property_list:
		_custom_property_list[property.name] = property


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		update_configuration_warnings()


func _ready() -> void:
	h_slider.value_changed.connect(value_changed.emit)
	h_slider.value_changed.connect(func(value: float): $ValueLabel.text = "%10.1f" % value)
	h_slider.value_changed.connect(func(value: float): $ResetButton.disabled = value == _reset_value)
	
	$ResetButton.pressed.connect(func(): h_slider.value = _reset_value)
	
	if Engine.is_editor_hint():
		return
	
	for property in _custom_property_list.keys():
		h_slider.set(property, get(property))
	
	if target_node:
		h_slider.value_changed.connect(Callable(target_node, "set_" + option_name))
		_reset_value = target_node.call("get_" + option_name)
		h_slider.value = _reset_value
		h_slider.value_changed.emit(h_slider.value)


func _get_configuration_warnings() -> PackedStringArray:
	var ret: PackedStringArray = []
	
	if target_node == null:
		ret.append("target node is null")
		
		return ret
	
	if !target_node.has_method("set_" + option_name):
		ret.append("target node missing " + "set_" + option_name + " method")
	
	if !target_node.has_method("get_" + option_name):
		ret.append("target node missing " + "get_" + option_name + " method")
	
	return ret


func _get_property_list() -> Array[Dictionary]:
	return _custom_property_list.values()


func _set(property: StringName, value: Variant) -> bool:
	if !h_slider:
		return false
	
	_custom_property_list_values[property] = value
	
	h_slider.set(property, value)
	
	return true


func _get(property: StringName) -> Variant:
	if Engine.is_editor_hint():
		if !h_slider:
			return null
		
		_custom_property_list_values[property] = h_slider.get(property)
	
	return _custom_property_list_values.get(property, null)


func _property_can_revert(property: StringName) -> bool:
	return _custom_property_list.has(property)


func _property_get_revert(property: StringName) -> Variant:
	return ClassDB.class_get_property_default_value("HSlider", property)
