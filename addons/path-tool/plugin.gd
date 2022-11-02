@tool
extends EditorPlugin

var dock:Control

func _enter_tree():
	dock=preload("../path-tool/dock/path_tool_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	
	var icon:Texture2D = get_editor_interface().get_base_control().get_theme_icon("Path3D", "EditorIcons")
	
	add_custom_type(
		"PathPoint3D",
		"MeshInstance3D",
		preload("path_node/path_point_3d.gd"),
		icon
	)

	add_custom_type(
		"PathPointManager",
		"Node3D",
		preload("path_node/path_point_manager.gd"),
		icon
	)
	
	if not InputMap.has_action("place_super_node"):
		InputMap.add_action("place_super_node")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_SPACE
		InputMap.action_add_event("place_super_node", event)


func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
	
	remove_custom_type("PathPoint3D")
	remove_custom_type("PathPointManager")
