@tool
extends Resource
class_name ShaderStageResource

@export var shader_file : RDShaderFile:
	set(value):
		shader_file = value
		emit_changed()

var shader : RID
var pipeline : RID
