@tool
class_name PathPointer3D
extends MeshInstance3D

var interpolation_positions:Array[Vector3] = []

var straight_interpolation_step_size:float
var curve_interpolation_step_size:float
var step_size_rounding:int
var interpolation_mesh:Mesh = preload("res://addons/path-tool/path_node/path_pointer/interp_mesh.tres")


enum CURVE_MODES {
	Automatic = 0,
	Enabled = 1,
	Disabled = 2
}

enum CURVE_FLIPPINGS {
	Automatic = 0,
	CurveRight = 1,
	CurveLeft = 2
}

@export var curve_mode:CURVE_MODES = 0
@export_range(0, 65535, 1) var weight = 10
@export_range(0.001, 10.0) var curve_value = 0.5
@export var curve_flipping:CURVE_FLIPPINGS = 0
@export_range(0, 100, 0.01) var custom_straight_interp_step_size = 0
@export_range(0, 100, 0.01) var custom_curve_interp_step_size = 0
@export var target_name:String

var from_node:MeshInstance3D
var from:Vector3
var to:Vector3

var curve_left := false
var is_curve := false
var helper_pos:Vector3

var multi_mesh_instance := MultiMeshInstance3D.new()
var multi_mesh := MultiMesh.new()


func _enter_tree():
	if get_child_count(true) == 0:
		add_child(multi_mesh_instance, true, 1)
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.mesh = interpolation_mesh
		multi_mesh_instance.multimesh = multi_mesh
		multi_mesh_instance.cast_shadow = SHADOW_CASTING_SETTING_OFF


func _ready():
	if not is_in_group("path_pointers"):
		add_to_group("path_pointers")
	
	get_tree().call_group("path_tool_dock", "request_step_size_data", self)


func init(_target_name:String, color:Color) -> void:
	set_owner(get_tree().get_edited_scene_root())
	set_name("PathPointer3D")
	mesh = CylinderMesh.new()
	mesh.resource_local_to_scene = true
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.6
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.material = StandardMaterial3D.new()
	mesh.material.set_shading_mode(BaseMaterial3D.SHADING_MODE_UNSHADED)
	mesh.material.resource_local_to_scene = true
	mesh.material.albedo_color = color
	target_name = _target_name
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	transparency = 0.2


func update_step_size_data(straight_step, curve_step, step_rounding) -> void:
	straight_interpolation_step_size = straight_step
	curve_interpolation_step_size = curve_step
	step_size_rounding = step_rounding
	update_interpolation()


func update_position(_from_node:MeshInstance3D, _to_node:MeshInstance3D) -> void:
	if _from_node.global_transform.origin == _to_node.global_transform.origin:
		return
	
	from_node = _from_node
	from = _from_node.global_transform.origin
	to = _to_node.global_transform.origin
	global_transform = get_parent().global_transform
	mesh.height = from.distance_to(to)
	look_at(to)
	rotate_object_local(Vector3.LEFT, PI/2)
	translate_object_local(Vector3.UP * (mesh.height/2))
	
	update_interpolation()


func update_interpolation():
	if not is_instance_valid(from_node):
		return
	
	interpolation_positions.clear()
	
	match curve_mode:
		CURVE_MODES.Automatic:
			is_curve = !(absf(from.x - to.x) <= 0.5 or absf(from.z - to.z) <= 0.5)
		
		CURVE_MODES.Enabled:
			is_curve = true
		
		CURVE_MODES.Disabled:
			is_curve = false
	
	var step_size:float
	
	if is_curve:
		match curve_flipping:
			CURVE_FLIPPINGS.Automatic:
				curve_left = get_auto_curvature()
			
			CURVE_FLIPPINGS.CurveLeft:
				curve_left = true
			
			CURVE_FLIPPINGS.CurveRight:
				curve_left = false
		
		if custom_curve_interp_step_size > 0.0:
			step_size = custom_curve_interp_step_size
		else:
			step_size = curve_interpolation_step_size
	
	else:
		if custom_straight_interp_step_size > 0.0:
			step_size = custom_straight_interp_step_size
		else:
			step_size = straight_interpolation_step_size
	
	var full_distance:float = from.distance_to(to)
	if full_distance < step_size:
		multi_mesh_instance.hide()
		return
	
	var lerp_nodes_amount:int= ceili(full_distance/step_size)
	if step_size_rounding == 0:
		lerp_nodes_amount = floori(full_distance/step_size)
	else:
		lerp_nodes_amount = ceili(full_distance/step_size)
	
	if lerp_nodes_amount == 0:
		multi_mesh_instance.hide()
		return
	else:
		multi_mesh_instance.show()
	
	multi_mesh.instance_count = lerp_nodes_amount
	
	var relative_from:Vector3
	var relative_to:Vector3
	var interval_weight:float = 1.0/(lerp_nodes_amount)
	var current_weight:float = 0.0
	
	for i in lerp_nodes_amount:
		var mesh_pos:Vector3
		if is_curve:
			helper_pos = global_transform.translated_local(Vector3(curve_value * (-1 if curve_left else 1) * full_distance, 0, 0)).origin
			relative_from = from - helper_pos
			relative_to = to - helper_pos
			mesh_pos = relative_from.slerp(relative_to, current_weight) + helper_pos
		else:
			mesh_pos = from.lerp(to, current_weight)
		
		interpolation_positions.append(mesh_pos)
		current_weight += interval_weight
	
	for i in range(lerp_nodes_amount):
		var tform := Transform3D.IDENTITY
		var pos:Vector3 = interpolation_positions[i] + Vector3.UP * 0.6
		tform.origin = multi_mesh_instance.to_local(pos)
		
		var look_at_pos:Vector3
		if i < lerp_nodes_amount-1:
			look_at_pos = interpolation_positions[i+1] + Vector3.UP * 0.6
		else:
			look_at_pos = to + Vector3.UP * 0.6
		
		# weird thing where the middle interp node fails the lookint_at()
		if not is_curve or (lerp_nodes_amount % 2 == 1 and i == (lerp_nodes_amount-1)/2):
			tform = tform.rotated_local(Vector3.RIGHT, PI/2)
		else:
			tform = tform.looking_at(multi_mesh_instance.to_local(look_at_pos))
			tform = tform.rotated_local(Vector3.FORWARD, PI/2)
		
		multi_mesh.set_instance_transform(i, tform)


func get_auto_curvature() -> bool:
	if from_node.previous_neighbours.is_empty():
		return curve_flipping == CURVE_FLIPPINGS.CurveLeft
	
	var prev_neighbour = from_node.get_prev_neighbour(from_node.previous_neighbours[0])
	
	if not prev_neighbour:
		return curve_flipping == CURVE_FLIPPINGS.CurveLeft
	
	prev_neighbour.look_at(to, Vector3.UP)
	var result:bool = prev_neighbour.to_local(from).x > 0
	prev_neighbour.rotation = Vector3.ZERO
	return result
