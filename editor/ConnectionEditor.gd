# ConnectionEditor.gd
class_name ConnectionEditor
extends RefCounted

var canvas: Node2D
var container: VBoxContainer
var connections: Array[CanvasPreview.ConnectionLine]

func setup_container(parent_container: VBoxContainer):
	print("ConnectionEditor-setup_container")
	container = parent_container

func update_connections():
	print("ConnectionEditor-update_connections")
	if !canvas or !container:
		return
		
	for child in container.get_children():
		child.queue_free()
		
	for i in range(canvas.preview_connections.size()):
		add_connection_editor(canvas.preview_connections[i], i)

func add_connection_editor(connection: CanvasPreview.ConnectionLine, index: int):
	print("ConnectionEditor-add_connection_editor")
	var editor = ConnectionEditorUI.new()
	container.add_child(editor)
	editor.setup(connection, index, canvas)
