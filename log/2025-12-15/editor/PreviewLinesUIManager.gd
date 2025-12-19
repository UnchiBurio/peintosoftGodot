class_name PreviewLinesUIManager
extends Control

var tab_container: TabContainer
var points_container: VBoxContainer
var connections_container: VBoxContainer
var ratio_container: VBoxContainer
var intersection_ratio_container: VBoxContainer
var angle_ratio_container: VBoxContainer

func _ready():
	setup_base_layout()

func setup_base_layout():
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.custom_minimum_size = Vector2(480, 580)
	add_child(tab_container)
	
	# Points タブ
	var points_scroll = ScrollContainer.new()
	points_scroll.custom_minimum_size = Vector2(460, 560)
	tab_container.add_child(points_scroll)
	tab_container.set_tab_title(0, "Points")
	
	points_container = VBoxContainer.new()
	points_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_scroll.add_child(points_container)
	
	# Connections タブ
	var connections_scroll = ScrollContainer.new()
	connections_scroll.custom_minimum_size = Vector2(460, 560)
	tab_container.add_child(connections_scroll)
	tab_container.set_tab_title(1, "Connections")
	
	connections_container = VBoxContainer.new()
	connections_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connections_scroll.add_child(connections_container)
	
	# Ratio タブ
	var ratio_scroll = ScrollContainer.new()
	ratio_scroll.custom_minimum_size = Vector2(460, 560)
	tab_container.add_child(ratio_scroll)
	tab_container.set_tab_title(2, "Ratio")
	
	ratio_container = VBoxContainer.new()
	ratio_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratio_scroll.add_child(ratio_container)

	# Intersection Ratio タブ
	var intersection_ratio_scroll = ScrollContainer.new()
	intersection_ratio_scroll.custom_minimum_size = Vector2(460, 560)
	tab_container.add_child(intersection_ratio_scroll)
	tab_container.set_tab_title(3, "Intersection Ratio")
	
	intersection_ratio_container = VBoxContainer.new()
	intersection_ratio_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intersection_ratio_scroll.add_child(intersection_ratio_container)

	# Angle Ratio タブ
	var angle_ratio_scroll = ScrollContainer.new()
	angle_ratio_scroll.custom_minimum_size = Vector2(460, 560)
	tab_container.add_child(angle_ratio_scroll)
	tab_container.set_tab_title(4, "Angle Ratio")
	
	angle_ratio_container = VBoxContainer.new()
	angle_ratio_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	angle_ratio_scroll.add_child(angle_ratio_container)

func setup_ui(point_editor: PointEditor, connection_editor: ConnectionEditor, 
			  ratio_editor: RatioEditorUI, intersection_ratio_editor: IntersectionRatioEditorUI,
			  angle_ratio_editor: AngleRatioEditorUI):
	point_editor.setup_container(points_container)
	connection_editor.setup_container(connections_container)
	ratio_container.add_child(ratio_editor)
	intersection_ratio_container.add_child(intersection_ratio_editor)
	angle_ratio_container.add_child(angle_ratio_editor)
