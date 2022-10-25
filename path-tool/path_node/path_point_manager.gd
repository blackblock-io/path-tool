@tool
extends Node3D
class_name PathPointManager

@export_global_dir var csv_export_path = "res://addons/path-tool/exports"
@export var csv_export_file_name:String = "roadnet"

@export var show_paths_run_time:bool = false

var visualizer:Node3D = null

func _enter_tree():
	if not Engine.is_editor_hint():
		if not show_paths_run_time:
			queue_free()
		
		else:
			set_process(false)


func _ready():
	if not is_in_group("path_point_manager"):
		add_to_group("path_point_manager")
	
	if not visualizer:
		visualizer = load("res://addons/path-tool/path_node/hover_visualizer.tscn").instantiate()
		visualizer.hide()
		add_child(visualizer)


func create_path_point(pos:Vector3, connect_from, editor:EditorInterface) -> void:
	var new_path_point := PathPoint3D.new()
	add_child(new_path_point)
	new_path_point.set_owner(get_tree().get_edited_scene_root())
	
	new_path_point.update_color()
	new_path_point.global_transform.origin = pos
	
	if connect_from:
		var old_path_point:PathPoint3D = connect_from
		new_path_point.add_previous_neighbour(old_path_point)
		old_path_point.add_next_neighbour(new_path_point)
		new_path_point.tag = old_path_point.tag
	
	editor.get_selection().clear()
	editor.get_selection().add_node(new_path_point)


func hide_visualizer() -> void:
	visualizer.hide()


func show_visualizer() -> void:
	visualizer.show()


func update_visualizer_position(pos:Vector3) -> void:
	visualizer.global_transform.origin=pos


func export_paths_csv() -> void:
	print("Starting CSV exporting")
	var path:String = csv_export_path + "/" + csv_export_file_name + ".csv"
	var path_points:Array = get_tree().get_nodes_in_group("path_points")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		get_tree().call_group("path_tool_dock", "_on_invalid_export_path_chosen", path)
		return
	
	file.store_csv_line(PackedStringArray(["id", "tag", "position", "neighbours"]), "\t")
	
	for path_point in path_points:
		if path_point.next_neighbours.is_empty() and path_point.previous_neighbours.is_empty():
			get_tree().call_group("path_tool_dock", "_on_export_empty_nodes_found")
			return
		
		var line:PackedStringArray
		var point_pos:Vector3 = path_point.global_transform.origin
		point_pos=Vector3(
			snapped(point_pos.x, 0.01),
			snapped(point_pos.y, 0.01),
			snapped(point_pos.z, 0.01)
		)
		line=[path_point.name, path_point.tag, str(point_pos)]
		
		var neighbours := []
		for pointer in path_point.get_children():
			if not pointer is PathPointer3D:
				continue
			
			var interp_nodes:Array[Vector3] = []
			for interp_pos in pointer.interpolation_positions:
				interp_nodes.append(Vector3(
					snapped(interp_pos.x, 0.01),
					snapped(interp_pos.y, 0.01),
					snapped(interp_pos.z, 0.01)
				))
			
			neighbours.append([pointer.target_name.to_int(), pointer.weight, interp_nodes])
		line.append_array([neighbours])
		file.store_csv_line(line, "\t")
	
	file = null
	print("Finished CSV exporting to path: %s" % path)
	get_tree().call_group("path_tool_dock", "_on_exporting_finished")
