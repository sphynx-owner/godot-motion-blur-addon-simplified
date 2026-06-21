@tool
extends Resource
class_name ShaderStageResource

@export var shader_file : RDShaderFile:
	set(value):
		shader_file = value
		emit_changed()

var shader : RID
var pipeline : RID
var rd: RenderingDevice


func _init(p_shader_file = null):
	if p_shader_file:
		shader_file = p_shader_file


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if !rd:
			return
		
		if rd.compute_pipeline_is_valid(pipeline):
			rd.free_rid(pipeline)
			pipeline = RID()
		if shader.is_valid():
			rd.free_rid(shader)
			shader = RID()
		
		rd = null


func is_generated() -> bool:
	return rd != null


func free_rids() -> void:
	if !rd:
		return
	
	if rd.compute_pipeline_is_valid(pipeline):
		rd.free_rid(pipeline)
		pipeline = RID()
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
	
	rd = null
