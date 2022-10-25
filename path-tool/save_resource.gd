extends Resource
class_name SaveResource

const save_path := "user://path_tool_save_file.tres"

@export var straight_interpolation_step_size:float
@export var curve_interpolation_step_size:float
@export var step_size_rounding:int

func _init(straight:float, curve:float, rounding:int):
	straight_interpolation_step_size = straight
	curve_interpolation_step_size = curve
	step_size_rounding = rounding
