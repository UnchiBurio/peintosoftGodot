class_name PointEditor
extends RefCounted

var canvas: Node2D
var container: VBoxContainer
var points: Array[CanvasPreview.PreviewPoint]

func setup_container(parent_container: VBoxContainer):
	container = parent_container

func update_points():
	print("PointEditor-update_points")
	if !canvas or !container:
		return
		
	for child in container.get_children():
		child.queue_free()
		
	for i in range(canvas.preview_points.size()):
		add_point_editor(canvas.preview_points[i], i)

func add_point_editor(point: CanvasPreview.PreviewPoint, index: int):
	print("PointEditor-add_point_editor")
	var editor = PointEditorUI.new()
	container.add_child(editor)
	editor.setup(point, index, canvas)
