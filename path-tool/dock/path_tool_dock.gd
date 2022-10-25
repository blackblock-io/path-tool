@tool
extends Control

@onready var AssignSourceButton:Button=$ScrollContainer/VBoxContainer/AssignSourceButton
@onready var AssignNeighbourButton:Button=$ScrollContainer/VBoxContainer/AssignNeighbourButton
@onready var UnassignSourceButton:Button=$ScrollContainer/VBoxContainer/UnassignSourceButton
@onready var CreatePointButton:Button=$ScrollContainer/VBoxContainer/CreatePointButton
@onready var DeleteEmptyPointsButton:Button=$ScrollContainer/VBoxContainer/DeleteEmptyPointsButton
@onready var ClearNextNeighboursButton:Button=$ScrollContainer/VBoxContainer/ClearNextNeighboursButton
@onready var SuperModeButton:Button=$ScrollContainer/VBoxContainer/ToggleSuperModeButton
@onready var CreateNewIDButton:Button=$ScrollContainer/VBoxContainer/CreateNewIDButton
@onready var StraightInterpSpinBox:SpinBox=$ScrollContainer/VBoxContainer/StraightInterpStep/VBoxContainer/StraightInterpSpinBox
@onready var CurveInterpSpinBox:SpinBox=$ScrollContainer/VBoxContainer/CurveInterpStep/VBoxContainer/CurveInterpSpinBox
@onready var StepSizeRoundingOptionButton:OptionButton=$ScrollContainer/VBoxContainer/StepSizeRoundingOptionButton

var interp_debounce_timer := Timer.new()
var update_thread := Thread.new()
var check_empty_thread := Thread.new()
var editor:EditorInterface
var editor_camera:Camera3D
var file_system_dock:FileSystemDock
var full_selection:Array[Node] = []
var path_points_selection:Array[PathPoint3D] = []

var source_assigned := false
var source_path_node:PathPoint3D
var source_color:Color
var super_mode_on := false

var save_resource:SaveResource

func _init():
	set_process(false)
	if not Engine.is_editor_hint():
		queue_free()


func _ready():
	if not is_in_group("path_tool_dock"):
		add_to_group("path_tool_dock")
	
	interp_debounce_timer.wait_time = 0.1
	interp_debounce_timer.one_shot = true
	interp_debounce_timer.timeout.connect(interp_debounce_timeout)
	add_child(interp_debounce_timer)
	
	var plugin:=EditorPlugin.new()
	editor=plugin.get_editor_interface()
	set_process(true)
	
	editor_camera=get_editor_cam()
	if not editor_camera:
		SuperModeButton.disabled = true
		SuperModeButton.text = "Enable super mode\n(editor 3D camera not found)"
	
	file_system_dock=editor.get_file_system_dock()
	
	load_data()


func load_data() -> void:
	if ResourceLoader.exists(SaveResource.save_path):
		save_resource = ResourceLoader.load(SaveResource.save_path)
	else:
		save_resource = SaveResource.new(4, 1, 0)
		save_data()
	
	StraightInterpSpinBox.value = save_resource.straight_interpolation_step_size
	CurveInterpSpinBox.value = save_resource.curve_interpolation_step_size
	StepSizeRoundingOptionButton.select(save_resource.step_size_rounding)


func save_data() -> void:
	ResourceSaver.save(save_resource, SaveResource.save_path)


func get_editor_cam():
	# very inconsistent but there's no built-in way to get the editor camera :´(
	var all_nodes = []
	var cameras = []
	var c = get_tree().get_root().get_children()
	while !c.is_empty():
		var child_list = []                        
		for i in c:
			child_list += i.get_children()
		all_nodes += child_list
		c = child_list
	
	for node in all_nodes:
		if node is Camera3D:
			cameras.append(node)
	
	return cameras[1] if cameras.size()>1 else null


func _physics_process(_delta):
	var frame:=get_tree().get_frame()
	#if frame%2==0:
	full_selection=get_selection()
	path_points_selection=get_selected_path_points(full_selection)
	var path_points_selection_size:int=path_points_selection.size()
	super_mode_on=SuperModeButton.button_pressed
	
	if not super_mode_on:
		AssignSourceButton.disabled=path_points_selection_size!=1
		AssignNeighbourButton.disabled=!(source_assigned and path_points_selection_size>0 and not source_path_node in path_points_selection)
		CreatePointButton.disabled=AssignSourceButton.disabled
		ClearNextNeighboursButton.disabled=!path_points_selection_size
		CreateNewIDButton.disabled=!path_points_selection_size
		for path_point in path_points_selection:
			if not path_point.next_neighbours.is_empty() or not path_point.previous_neighbours.is_empty():
				CreateNewIDButton.disabled=true
				break
	
	else:
		super_mode_loop()
	
	#if frame%6==0:
	if not check_empty_thread.is_alive() and not check_empty_thread.is_started():
		check_empty_thread.start(thread_check_empty_path_points)
	
	if path_points_selection_size>=1 and not update_thread.is_alive() and not update_thread.is_started():
		update_thread.start(thread_update_path_points.bind(path_points_selection))
	
	for node in full_selection:
		if not node is PathPointer3D:
			return
		
		node.update_interpolation()


func thread_update_path_points(nodes:Array[PathPoint3D]) -> void:
	for node in nodes:
		node.update_pointer_positions()
		node.update_prev_neighbour_pointers()
		node.update_color()
	
	call_deferred("update_thread_finish")


func update_thread_finish() -> void:
	update_thread.wait_to_finish()


func thread_check_empty_path_points() -> void:
	DeleteEmptyPointsButton.text = "Delete empty nodes"
	var empty_nodes:int = 0
	
	for node in get_tree().get_nodes_in_group("path_points"):
		if node.next_neighbours.is_empty() and node.previous_neighbours.is_empty():
			empty_nodes += 1
			DeleteEmptyPointsButton.text = "Delete empty nodes: %s" % empty_nodes
	
	DeleteEmptyPointsButton.disabled = empty_nodes==0
	call_deferred("check_empty_thread_finish")


func check_empty_thread_finish() -> void:
	check_empty_thread.wait_to_finish()


func super_mode_loop() -> void:
	var mouse_pos=get_local_mouse_position()-Vector2(file_system_dock.size.x+28, 64)
	var ray_origin=editor_camera.project_ray_origin(mouse_pos)
	var ray_end=ray_origin+editor_camera.project_ray_normal(mouse_pos)*1000
	
	var query_params=PhysicsRayQueryParameters3D.new()
	query_params.from=ray_origin
	query_params.to=ray_end
	var space_state=editor_camera.get_world_3d().get_direct_space_state()
	var hit=space_state.intersect_ray(query_params)
	
	if hit:
		var hit_pos = hit.position
		hit_pos = Vector3(
			snapped(hit_pos.x, 0.2),
			snapped(hit_pos.y, 0.2),
			snapped(hit_pos.z, 0.2)
		)
		get_tree().call_group("path_point_manager", "update_visualizer_position", hit_pos)
		
		if Input.is_action_just_pressed("place_super_node"):
			get_tree().call_group("path_point_manager", "create_path_point", hit_pos, null if path_points_selection.is_empty() else path_points_selection[0], editor)


func get_selected_path_points(nodes) -> Array[PathPoint3D]:
	var path_point_nodes:Array[PathPoint3D] = []
	
	for node in nodes:
		if node is PathPoint3D:
			path_point_nodes.append(node)
	
	return path_point_nodes


func get_selection() -> Array:
	if is_instance_valid(editor):
		return editor.get_selection().get_selected_nodes()
	
	return []


func _on_assign_source_button_pressed() -> void:
	if source_path_node:
		_on_unassign_source_button_pressed()
	
	source_path_node = path_points_selection[0]
	source_path_node.mesh.material.albedo_color = Color.CYAN
	
	source_assigned = true
	editor.get_selection().clear()
	UnassignSourceButton.disabled = false


func _on_assign_neighbour_button_pressed() -> void:
	source_path_node.clear_next_neighbours()
	
	for path_point in path_points_selection:
		path_point.add_previous_neighbour(source_path_node)
		source_path_node.add_next_neighbour(path_point)
	
	source_assigned=false
	
	if path_points_selection.size()!=1:
		editor.get_selection().clear()


func _on_unassign_source_button_pressed() -> void:
	source_path_node.update_color()
	source_path_node=null
	source_assigned=false
	editor.get_selection().clear()
	UnassignSourceButton.disabled=true


func _on_create_point_button_pressed() -> void:
	get_tree().call_group("path_point_manager", "create_path_point", path_points_selection[0].global_transform.origin, path_points_selection[0], editor)


func _on_toggle_super_mode(pressed) -> void:
	if pressed:
		get_tree().call_group("path_point_manager", "show_visualizer")
		SuperModeButton.text="Disable super mode\n(the fastest way) (s)"
		
		AssignSourceButton.disabled=true
		AssignNeighbourButton.disabled=true
		UnassignSourceButton.disabled=true
		CreatePointButton.disabled=true
		ClearNextNeighboursButton.disabled=true
		CreateNewIDButton.disabled=true
		
		if source_path_node:
			source_path_node.update_color()
			source_path_node=null
			source_assigned=false
	
	else:
		get_tree().call_group("path_point_manager", "hide_visualizer")
		SuperModeButton.text="Enable super mode\n(the fastest way) (s)"


func _on_delete_empty_points_button_pressed():
	get_tree().call_group("path_points", "free_if_empty")
	get_node("DeleteEmptyNodesPopup").hide()


func _on_clear_next_neighbours_button_pressed() -> void:
	for path_point in path_points_selection:
		path_point.clear_next_neighbours()


func _on_create_new_id_button_pressed() -> void:
	for path_point in path_points_selection:
		if path_point.next_neighbours.is_empty() and path_point.previous_neighbours.is_empty():
			path_point.assign_id()
			path_point.assign_mesh()


func _on_export_csv_button_pressed() -> void:
	get_tree().call_group("path_point_manager", "export_paths_csv")


func _on_invalid_export_path_chosen(path:String) -> void:
	get_node("InvalidExportPathPopup").popup_centered()
	get_node("InvalidExportPathPopup/VBox/PathLabel").text = path


func _on_export_empty_nodes_found() -> void:
	get_node("DeleteEmptyNodesPopup").popup_centered()


func _on_exporting_finished() -> void:
	get_node("ExportingFinishedPopup").popup_centered()


func _on_path_point_visibility_button_toggled(button_pressed) -> void:
	get_tree().call_group("path_points", "set_path_points_visibility", button_pressed)


func _on_pointer_visibility_button_toggled(button_pressed) -> void:
	get_tree().call_group("path_points", "set_pointers_visibility", button_pressed)


func _on_interpolation_visibility_button_toggled(button_pressed) -> void:
	get_tree().call_group("path_points", "set_interpolations_visibility", button_pressed)


func _on_help_button_pressed() -> void:
	$HelpPopup.popup_centered()


func _on_straight_interp_step_size_changed(step_size:float):
	save_resource.straight_interpolation_step_size = step_size
	interp_debounce_timer.start()


func _on_curve_interp_step_size_changed(step_size:float):
	save_resource.curve_interpolation_step_size = step_size
	interp_debounce_timer.start()


func interp_debounce_timeout() -> void:
	save_data()
	update_path_pointer_data()


func _on_step_size_rounding_option_selected(index):
	save_resource.step_size_rounding = index
	save_data()
	update_path_pointer_data()


func request_step_size_data(path_pointer:PathPointer3D) -> void:
	path_pointer.update_step_size_data(
		save_resource.straight_interpolation_step_size,
		save_resource.curve_interpolation_step_size,
		save_resource.step_size_rounding
	)


func update_path_pointer_data() -> void:
	get_tree().call_group(
			"path_pointers",
			"update_step_size_data",
			save_resource.straight_interpolation_step_size,
			save_resource.curve_interpolation_step_size,
			save_resource.step_size_rounding
		)
