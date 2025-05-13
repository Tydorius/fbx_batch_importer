# filename: addons/fbx_batch_importer/fbx_batch_importer_plugin.gd
@tool
extends EditorPlugin

var popup_window_scene: PackedScene
var popup_instance # To hold the instance of the popup

# Adjust this path if you place your popup scene elsewhere
const POPUP_SCENE_PATH = "res://addons/fbx_batch_importer/fbx_batch_importer_popup.tscn"


func _enter_tree() -> void:
	popup_window_scene = load(POPUP_SCENE_PATH)
	if popup_window_scene == null:
		printerr("FBX Batch Importer Plugin: Failed to load popup scene at: ", POPUP_SCENE_PATH)
		return

	# Add a menu item to the Tools menu to open the popup
	add_tool_menu_item("FBX Batch Importer...", Callable(self, "_on_tool_menu_item_pressed"))


func _exit_tree() -> void:
	remove_tool_menu_item("FBX Batch Importer...")
	if is_instance_valid(popup_instance):
		popup_instance.queue_free()


func _on_tool_menu_item_pressed() -> void:
	if popup_window_scene:
		# Create a new instance if one doesn't exist or if the previous one was freed
		if not is_instance_valid(popup_instance):
			popup_instance = popup_window_scene.instantiate()
			# Add the popup to the editor's root control so it's not part of any specific scene
			get_editor_interface().get_base_control().add_child(popup_instance)

		# Show the popup
		# The popup's own script should handle its visibility and centering
		popup_instance.popup_centered()
	else:
		printerr("FBX Batch Importer Plugin: Popup scene not loaded or invalid.")
