@tool
extends MeshInstance3D
class_name PathPoint3D

const colors:Array[Color] = [
	Color.DODGER_BLUE,
	Color.MEDIUM_PURPLE,
	Color.GOLD,
	Color.DEEP_PINK,
	Color.FIREBRICK,
	Color.CYAN,
	Color.PLUM,
	Color.ORANGE_RED,
	Color.SEASHELL,
	Color.YELLOW_GREEN,
	Color.SADDLE_BROWN,
	Color.ROSY_BROWN,
	Color.PALE_VIOLET_RED,
	Color.OLIVE,
	Color.LIME_GREEN,
	Color.DARK_SLATE_BLUE
]

@export_range(0, 64, 1) var tag:int = 0
@export var next_neighbours:Array[String] = []
@export var previous_neighbours:Array[String] = []


func _ready():
	update_pointer_positions()
	
	if not mesh:
		assign_id()
		assign_mesh()
	
	if not is_in_group("path_points"):
		add_to_group("path_points")


func assign_id():
	set_name(str(generate_new_id()))


func generate_new_id() -> int:
	randomize()
	var day=str(Time.get_datetime_dict_from_system()["day"])
	var micros=str(Time.get_ticks_usec())
	var r=str(randi()%1000)
	return (day+micros+r).to_int()


func assign_mesh():
	mesh = SphereMesh.new()
	mesh.is_hemisphere = true
	mesh.height = 0.7
	mesh.radius = 0.7
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = StandardMaterial3D.new()
	mesh.material.set_shading_mode(BaseMaterial3D.SHADING_MODE_UNSHADED)
	set_cast_shadows_setting(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	transparency = 0.2
	
	update_color()


func update_color() -> void:
	var has_next_neighbours:bool=!next_neighbours.is_empty()
	var has_prev_neighbours:bool=!previous_neighbours.is_empty()
	
	if has_next_neighbours and has_prev_neighbours:
		mesh.material.albedo_color = Color.GREEN
	
	elif not has_next_neighbours and has_prev_neighbours:
		mesh.material.albedo_color = Color.YELLOW
	
	elif has_next_neighbours and not has_prev_neighbours:
		mesh.material.albedo_color = Color.PURPLE
	
	else:
		mesh.material.albedo_color = Color.RED


func update_pointers() -> void:
	for pointer in get_children():
		pointer.queue_free()
	
	if next_neighbours.is_empty():
		return
	
	for next_n_name in next_neighbours:
		var next_neighbour=get_next_neighbour(next_n_name)
		if not next_neighbour:
			continue
		
		var pointer := PathPointer3D.new()
		add_child(pointer, true)
		pointer.init(str(next_neighbour.name), colors[tag % colors.size()])
	
	update_pointer_positions()


func update_pointer_positions() -> void:
	for child in get_children():
		if child is PathPointer3D:
			var next_n_name:String=child.target_name
			var next_neighbour=get_next_neighbour(next_n_name)
			if not next_neighbour:
				child.queue_free()
				continue
			
			var own_pos:Vector3=global_transform.origin
			var target_pos:Vector3=next_neighbour.global_transform.origin
			
			child.update_position(self, next_neighbour)


func update_prev_neighbour_pointers() -> void:
	for prev_n_name in previous_neighbours:
		var prev_neighbour=get_prev_neighbour(prev_n_name)
		if not prev_neighbour:
			update_color()
			update_pointers()
			continue
		
		prev_neighbour.update_pointer_positions()


func add_previous_neighbour(prev_neighbour:PathPoint3D) -> void:
	var prev_n_name:String = str(prev_neighbour.name)
	if not prev_n_name in previous_neighbours:
		previous_neighbours.append(prev_n_name)


func add_next_neighbour(next_neighbour:PathPoint3D) -> void:
	var next_n_name:String = str(next_neighbour.name)
	if not next_n_name in next_neighbours:
		next_neighbours.append(next_n_name)
		next_neighbour.update_color()
	
	update_color()
	update_pointers()


func clear_next_neighbours() -> void:
	for next_n_name in next_neighbours:
		var next_neighbour=get_next_neighbour(next_n_name)
		if not next_neighbour:
			continue
		
		next_neighbour.previous_neighbours.erase(str(name))
		next_neighbour.update_color()
	
	next_neighbours.clear()
	update_color()
	update_pointers()


func get_next_neighbour(_name:String) -> Node:
	if not _name in next_neighbours:
		return null
	
	if not get_parent().has_node(_name):
		next_neighbours.erase(_name)
		return null
	
	return get_parent().get_node(_name)


func get_prev_neighbour(_name:String) -> Node:
	if not _name in previous_neighbours:
		return null
	
	if not get_parent().has_node(_name):
		previous_neighbours.erase(_name)
		return null
	
	return get_parent().get_node(_name)


func set_path_points_visibility(pressed:bool) -> void:
	if pressed:
		visibility_range_end=0
	else:
		visibility_range_end=0.1


func set_pointers_visibility(pressed:bool) -> void:
	for child in get_children():
		if child is PathPointer3D:
			if pressed:
				child.visibility_range_end=0
			else:
				child.visibility_range_end=0.1


func set_interpolations_visibility(pressed:bool) -> void:
	for child in get_children():
		if child is PathPointer3D:
			if pressed:
				child.get_child(0, true).show()
			else:
				child.get_child(0, true).hide()


func free_if_empty() -> void:
	if next_neighbours.is_empty() and previous_neighbours.is_empty():
		queue_free()
