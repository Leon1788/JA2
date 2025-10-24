extends Node3D
class_name FOVVisualizer

var mesh_instance: MeshInstance3D
var is_visible: bool = false

func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	print("[FOVVis] _ready() called - mesh_instance created")

func update_fov_display(merc: Merc, grid_manager: GridManager) -> void:
	"""Visualisiert FOV des Players für viewing_floor"""
	print("\n[FOVVis] === UPDATE_FOV_DISPLAY CALLED ===")
	print("[FOVVis] is_visible: ", is_visible)
	print("[FOVVis] merc: ", merc.merc_data.merc_name if merc else "NULL")
	print("[FOVVis] grid_manager: ", "OK" if grid_manager else "NULL")
	
	if not is_visible:
		print("[FOVVis] is_visible=false - skipping render")
		mesh_instance.visible = false
		return
	
	print("[FOVVis] Rendering FOV...")
	
	for child in get_children():
		child.queue_free()
	
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	var immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	const BLOCKED = 0
	const PARTIAL = 1
	const CLEAR = 2
	
	# Nutze viewing_floor für Visualisierung (TAB wechselt viewing_floor)
	var viewing_floor = merc.viewing_floor
	var fov_to_display = merc.get_fov_for_viewing_floor()
	
	print("[FOVVis] Viewing floor: ", viewing_floor)
	print("[FOVVis] FOV grid size: ", fov_to_display.size())
	
	var clear_count = 0
	var partial_count = 0
	var blocked_count = 0
	
	for pos in fov_to_display:
		var visibility = fov_to_display[pos]
		var color: Color
		
		match visibility:
			BLOCKED:
				blocked_count += 1
				continue
			PARTIAL:
				partial_count += 1
				color = Color(1.0, 1.0, 0.0, 0.4)
			CLEAR:
				clear_count += 1
				color = Color(0.0, 1.0, 0.0, 0.4)
		
		_draw_tile(immediate_mesh, pos, color, grid_manager, viewing_floor)
	
	print("[FOVVis] Stats - CLEAR: %d, PARTIAL: %d, BLOCKED: %d" % [clear_count, partial_count, blocked_count])
	
	immediate_mesh.surface_end()
	mesh_instance.visible = true
	
	print("[FOVVis] Render complete - mesh visible set to true")
	print("[FOVVis] === END UPDATE_FOV_DISPLAY ===\n")

func _draw_tile(mesh: ImmediateMesh, grid_pos: Vector2i, color: Color, grid_manager: GridManager, viewing_floor: int) -> void:
	"""Zeichnet ein einzelnes Tile als 2 Dreiecke mit Y-Clipping an Floor-Grenzen"""
	var world_pos = grid_manager.grid_to_world(grid_pos)
	var tile_size = grid_manager.TILE_SIZE
	var height = viewing_floor * grid_manager.FLOOR_HEIGHT + 0.01
	
	# Y-Clipping: Tile stopp bei Floor-Grenzen
	var floor_bottom = viewing_floor * grid_manager.FLOOR_HEIGHT
	var floor_top = (viewing_floor + 1) * grid_manager.FLOOR_HEIGHT
	
	# Clamp height zwischen Floor-Grenzen
	height = clamp(height, floor_bottom + 0.01, floor_top - 0.01)
	
	var tl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var tr = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var bl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	var br = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tl)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)
	
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(br)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)

func toggle_visibility() -> void:
	is_visible = not is_visible
	mesh_instance.visible = is_visible
	print("[FOVVis] toggle_visibility() - is_visible now: ", is_visible)

func set_visibility(visible: bool) -> void:
	is_visible = visible
	mesh_instance.visible = visible
	print("[FOVVis] set_visibility(%s) - is_visible now: %s" % [visible, is_visible])
