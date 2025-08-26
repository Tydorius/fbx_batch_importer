# filename: addons/fbx_batch_importer/fbx_batch_importer_popup.gd
@tool
extends Window

# --- UI Element NodePath Getters (using %UniqueName syntax is best) ---
@onready var verbosity_option_button: OptionButton = $CenterContainer/VBoxContainer/SettingsGrid/VerbosityOptionButton
@onready var albedo_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/AlbedoLineEdit
@onready var albedo_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/AlbedoBrowseButton
@onready var auto_fill_check_box: CheckBox = $CenterContainer/VBoxContainer/SettingsGrid/AutoFillCheckBox
@onready var normal_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/NormalLineEdit
@onready var normal_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/NormalBrowseButton
@onready var metal_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/MetalLineEdit
@onready var metal_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/MetalBrowseButton
@onready var emission_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/EmissionLineEdit
@onready var emission_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/EmissionBrowseButton
@onready var roughness_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/RoughnessLineEdit
@onready var roughness_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/RoughnessBrowseButton
@onready var fbx_dir_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/FBXDirLineEdit
@onready var fbx_dir_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/FBXDirBrowseButton
@onready var material_dir_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/MaterialDirLineEdit
@onready var material_dir_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/MaterialDirBrowseButton
@onready var output_scene_dir_line_edit: LineEdit = $CenterContainer/VBoxContainer/SettingsGrid/OutputSceneDirLineEdit
@onready var output_scene_dir_browse_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/OutputSceneDirBrowseButton
@onready var mesh_only_checkbox: CheckBox = $CenterContainer/VBoxContainer/SettingsGrid/MeshOnlyToggle
@onready var collision_shape_option_button: OptionButton = $CenterContainer/VBoxContainer/SettingsGrid/CollisionShapeTypeOptionButton

@onready var prep_material_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/PrepMaterialbutton
@onready var process_fbx_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/ProcessFBXButton
@onready var close_button: Button = $CenterContainer/VBoxContainer/SettingsGrid/Close

# File Dialogs - Type hint changed to FileDialog
@onready var albedo_file_dialog: FileDialog = $AlbedoFileDialog
@onready var normal_file_dialog: FileDialog = $NormalFileDialog
@onready var metal_file_dialog: FileDialog = $MetalFileDialog
@onready var emission_file_dialog: FileDialog = $EmissionFileDialog
@onready var roughness_file_dialog: FileDialog = $RoughnessFileDialog
@onready var fbx_dir_dialog: FileDialog = $FBXDirDialog
@onready var material_dir_dialog: FileDialog = $MaterialDirDialog
@onready var output_scene_dir_dialog: FileDialog = $OutputSceneDirDialog
# --- End UI Element NodePaths ---

# --- Variables to hold the settings (mirroring your original @export vars) ---
var current_file : String
var original_path : String # Used internally for albedo/material base name resolution
var mesh_only : bool # Flag for mesh only toggle, so that changing it during execution doesn't break anything

enum Verbosity {
	NONE,
	ERRORS,
	WARNINGS,
	INFO,
	DEBUG
}
enum CollisionShapes {
	TRIMESH_COLLISION,
	SINGLE_CONVEX_COLLISION,
	SIMPLIFIED_CONVEX_COLLISION,
	MULTIPLE_CONVEX_COLLISION
}
var current_verbosity: int = Verbosity.INFO # Internal variable
var current_shape: int = CollisionShapes.SINGLE_CONVEX_COLLISION # Initial selection

# These will be populated from LineEdits
var albedo_or_material_path_internal: String = ""
var auto_fill_textures_internal: bool = false
var normal_map_path_internal: String = ""
var metal_map_path_internal: String = ""
var emission_map_path_internal: String = ""
var roughness_map_path_internal: String = ""
var fbx_directory_internal: String = ""
var material_directory_internal: String = ""
var output_scene_directory_internal: String = ""
# --- End Variables ---


func _ready() -> void:
	# Configure Window
	title = "FBX Batch Importer"
	close_requested.connect(hide)
	if is_instance_valid(close_button):
		close_button.pressed.connect(hide)

	# Populate Verbosity OptionButton
	verbosity_option_button.clear()
	for verbosity_name in Verbosity.keys():
		verbosity_option_button.add_item(verbosity_name)
	verbosity_option_button.selected = current_verbosity
	verbosity_option_button.item_selected.connect(_on_verbosity_selected)
	_update_verbosity_debug_print()

	# Populate Collision OptionButton
	collision_shape_option_button.clear()
	for collision_shape in CollisionShapes.keys():
		collision_shape_option_button.add_item(collision_shape)
	collision_shape_option_button.selected = current_shape
	collision_shape_option_button.item_selected.connect(_on_collision_shape_selected)

	# Connect the mesh only checkbox
	mesh_only_checkbox.toggled.connect(_on_mesh_only_toggled)

	# Connect signals for UI elements
	albedo_line_edit.text_changed.connect(_on_albedo_path_changed)
	albedo_browse_button.pressed.connect(func(): _show_file_dialog(albedo_file_dialog, ["*.png","*.jpg","*.jpeg","*.tga","*.bmp","*.exr","*.hdr","*.tres", "*.material"], albedo_line_edit))

	auto_fill_check_box.toggled.connect(_on_auto_fill_toggled)

	normal_line_edit.text_changed.connect(func(text): normal_map_path_internal = text; _print_debug("Normal map path set to: {p}".format({"p": text})))
	normal_browse_button.pressed.connect(func(): _show_file_dialog(normal_file_dialog, ["*.png","*.jpg","*.jpeg","*.tga","*.bmp","*.exr","*.hdr"], normal_line_edit))

	metal_line_edit.text_changed.connect(func(text): metal_map_path_internal = text; _print_debug("Metal map path set to: {p}".format({"p": text})))
	metal_browse_button.pressed.connect(func(): _show_file_dialog(metal_file_dialog, ["*.png","*.jpg","*.jpeg","*.tga","*.bmp","*.exr","*.hdr"], metal_line_edit))

	emission_line_edit.text_changed.connect(func(text): emission_map_path_internal = text; _print_debug("Emission map path set to: {p}".format({"p": text})))
	emission_browse_button.pressed.connect(func(): _show_file_dialog(emission_file_dialog, ["*.png","*.jpg","*.jpeg","*.tga","*.bmp","*.exr","*.hdr"], emission_line_edit))

	roughness_line_edit.text_changed.connect(func(text): roughness_map_path_internal = text; _print_debug("Roughness map path set to: {p}".format({"p": text})))
	roughness_browse_button.pressed.connect(func(): _show_file_dialog(roughness_file_dialog, ["*.png","*.jpg","*.jpeg","*.tga","*.bmp","*.exr","*.hdr"], roughness_line_edit))

	fbx_dir_line_edit.text_changed.connect(func(text): fbx_directory_internal = text; _print_debug("FBX directory set to: {d}".format({"d": text})))
	fbx_dir_browse_button.pressed.connect(func(): _show_dir_dialog(fbx_dir_dialog, fbx_dir_line_edit))

	material_dir_line_edit.text_changed.connect(func(text): material_directory_internal = text; _print_debug("Material directory set to: {d}".format({"d": text})))
	material_dir_browse_button.pressed.connect(func(): _show_dir_dialog(material_dir_dialog, material_dir_line_edit))

	output_scene_dir_line_edit.text_changed.connect(func(text): output_scene_directory_internal = text; _print_debug("Output scene directory set to: {d}".format({"d": text})))
	output_scene_dir_browse_button.pressed.connect(func(): _show_dir_dialog(output_scene_dir_dialog, output_scene_dir_line_edit))

	prep_material_button.pressed.connect(_on_prep_material_button_pressed)
	process_fbx_button.pressed.connect(_on_process_fbx_button_pressed)

	# Initialize internal variables from LineEdits if they have default text
	_on_albedo_path_changed(albedo_line_edit.text)
	auto_fill_textures_internal = auto_fill_check_box.button_pressed
	normal_map_path_internal = normal_line_edit.text
	metal_map_path_internal = metal_line_edit.text
	emission_map_path_internal = emission_line_edit.text
	roughness_map_path_internal = roughness_line_edit.text
	fbx_directory_internal = fbx_dir_line_edit.text
	material_directory_internal = material_dir_line_edit.text
	output_scene_directory_internal = output_scene_dir_line_edit.text
	
	if Engine.is_editor_hint():
		_print_debug("Auto-fill textures initial state: {b}".format({"b": auto_fill_textures_internal}))

# --- Helper for File/Dir Dialogs ---
func _show_file_dialog(dialog: FileDialog, filters: PackedStringArray, target_line_edit: LineEdit) -> void:
	dialog.clear_filters()
	for f in filters:
		dialog.add_filter(f)
	# Ensure dialog.access and dialog.file_mode are set in the Inspector for the FileDialog node.
	dialog.file_selected.connect(func(path): target_line_edit.text = path, CONNECT_ONE_SHOT)
	dialog.popup_centered_ratio()

func _show_dir_dialog(dialog: FileDialog, target_line_edit: LineEdit) -> void:
	# Ensure dialog.access and dialog.file_mode are set in the Inspector for the FileDialog node.
	dialog.dir_selected.connect(func(path): target_line_edit.text = path, CONNECT_ONE_SHOT)
	dialog.popup_centered_ratio()

# --- Signal Handlers for UI ---
func _on_collision_shape_selected(index: int) -> void:
	current_shape = index
	_print_debug("Collision shape type set to {v}".format({"v": CollisionShapes.keys()[current_shape]}))

func _on_mesh_only_toggled(button_pressed: bool) -> void:
	mesh_only = button_pressed
	_print_debug("Mesh only mode set to: {b}".format({"b": mesh_only}))

func _on_verbosity_selected(index: int) -> void:
	current_verbosity = index
	_update_verbosity_debug_print()

func _update_verbosity_debug_print():
	if Engine.is_editor_hint():
		_print_debug("Verbosity set to {v}".format({"v": Verbosity.keys()[current_verbosity]}))

func _on_albedo_path_changed(new_path: String) -> void:
	albedo_or_material_path_internal = new_path
	if Engine.is_editor_hint():
		_print_debug("Albedo/Material path set to: {p}".format({"p": albedo_or_material_path_internal}))
	
	self.original_path = convert_uid(albedo_or_material_path_internal)
	
	if auto_fill_textures_internal and not self.original_path.is_empty():
		_auto_fill_texture_paths()

func _on_auto_fill_toggled(button_pressed: bool) -> void:
	auto_fill_textures_internal = button_pressed
	if Engine.is_editor_hint():
		_print_debug("Auto-fill textures set to: {b}".format({"b": auto_fill_textures_internal}))
	if auto_fill_textures_internal and not albedo_or_material_path_internal.is_empty():
		self.original_path = convert_uid(albedo_or_material_path_internal)
		if not self.original_path.is_empty():
			_auto_fill_texture_paths()

# --- Get Methods for each input field ---
func get_albedo_or_material_path() -> String:
	if albedo_line_edit != null:
		return albedo_line_edit.text
	return ""

func get_normal_map_path() -> String:
	if normal_line_edit != null:
		return normal_line_edit.text
	return ""

func get_metal_map_path() -> String:
	if metal_line_edit != null:
		return metal_line_edit.text
	return ""

func get_emission_map_path() -> String:
	if emission_line_edit != null:
		return emission_line_edit.text
	return ""

func get_roughness_map_path() -> String:
	if roughness_line_edit != null:
		return roughness_line_edit.text
	return ""

func get_fbx_directory() -> String:
	if fbx_dir_line_edit != null:
		return fbx_dir_line_edit.text
	return ""

func get_material_directory() -> String:
	if material_dir_line_edit != null:
		return material_dir_line_edit.text
	return ""

func get_output_scene_directory() -> String:
	if output_scene_dir_line_edit != null:
		return output_scene_dir_line_edit.text
	return ""

# --- Action Button Handlers ---
func _on_prep_material_button_pressed() -> void:	
	self.original_path = convert_uid(get_albedo_or_material_path())
	if self.original_path.is_empty() and not albedo_or_material_path_internal.is_empty():
		_print_error("Albedo/Material path '{path}' could not be resolved. Cannot prepare material.".format({"path": albedo_or_material_path_internal}))
		return
	if self.original_path.is_empty():
		_print_error("Albedo/Material path is empty. Cannot prepare material.")
		return

	var mat: StandardMaterial3D = _prep_material()
	if mat != null:
		albedo_line_edit.text = albedo_or_material_path_internal
		_print_info("Material processing complete. Current material path: " + albedo_or_material_path_internal)
	else:
		_print_error("Material processing failed or material not saved.")

func _on_process_fbx_button_pressed() -> void:
	self.mesh_only = mesh_only_checkbox.button_pressed
	self.original_path = convert_uid(get_albedo_or_material_path())
	if self.original_path.is_empty() and not albedo_or_material_path_internal.is_empty():
		_print_error("Albedo/Material path '{path}' could not be resolved. Cannot process FBX files.".format({"path": albedo_or_material_path_internal}))
		return
	if self.original_path.is_empty():
		_print_error("Albedo/Material path is empty. Cannot process FBX files.")
		return

	process_fbx_files()

# --- UID Conversion ---
func convert_uid(item_path: String) -> String:
	_print_debug("Attempting to convert UID for: " + item_path)
	if item_path.begins_with("uid://"):
		_print_debug("Path begins with 'uid://'")
		var uid_val = ResourceUID.text_to_id(item_path)
		_print_debug("UID integer = " + str(uid_val))
		if uid_val != ResourceUID.INVALID_ID:
			var resolved_path = ResourceUID.get_id_path(uid_val)
			if resolved_path.is_empty():
				_print_error("ResourceUID could not resolve UID {uid} to a path.".format({"uid": item_path}))
				return ""
			_print_debug("Resolved UID {uid} to path: {p}".format({"uid": item_path, "p": resolved_path}))
			return resolved_path
		else:
			_print_error("Invalid UID string format: {uid}".format({"uid": item_path}))
			return ""
	else:
		return item_path

# --- Material Prep Section ---
func _prep_material() -> StandardMaterial3D:
	_print_info("--- Preparing Material ---")
	if self.original_path.is_empty():
		_print_error("Resolved Albedo/Material path is empty. Cannot prepare material.")
		return null

	var loaded_resource = ResourceLoader.load(self.original_path)
	if loaded_resource == null:
		_print_error("Failed to load resource at resolved path: {p}".format({"p": self.original_path}))
		return null

	if loaded_resource is StandardMaterial3D:
		_print_info("Provided resource is a StandardMaterial3D. Using it directly.")
		albedo_or_material_path_internal = self.original_path
		return loaded_resource
	elif loaded_resource is Texture2D or loaded_resource is CompressedTexture2D:
		_print_info("Provided resource is a Texture. Creating a new StandardMaterial3D.")
		return _create_material_from_textures(loaded_resource)
	else:
		_print_warning("Provided resource at '{p}' is not a Material or Texture. Assuming it's an albedo texture path for new material creation.".format({"p": self.original_path}))
		return _create_material_from_textures(null)

func _create_material_from_textures(albedo_texture_resource: Texture2D = null) -> StandardMaterial3D:
	var new_material = StandardMaterial3D.new()
	_print_debug("Created new StandardMaterial3D.")

	var albedo_tex_to_use: Texture2D = albedo_texture_resource
	if albedo_tex_to_use == null and not self.original_path.is_empty() and not (self.original_path.ends_with(".tres") or self.original_path.ends_with(".material")):
		var loaded_albedo = ResourceLoader.load(self.original_path)
		if loaded_albedo is Texture2D or loaded_albedo is CompressedTexture2D:
			albedo_tex_to_use = loaded_albedo
			_print_debug("Loaded albedo texture from path: {p}".format({"p": self.original_path}))
		else:
			_print_warning("Could not load albedo texture from path: {p}".format({"p": self.original_path}))
	
	if albedo_tex_to_use != null:
		new_material.albedo_texture = albedo_tex_to_use
		_print_info("Albedo texture set.")
	elif self.original_path.is_empty() or self.original_path.ends_with(".tres") or self.original_path.ends_with(".material"):
		_print_warning("No albedo texture provided or resolved from albedo/material path.")

	var resolved_normal_path = convert_uid(get_normal_map_path())
	if not resolved_normal_path.is_empty():
		var normal_tex = ResourceLoader.load(resolved_normal_path)
		if normal_tex is Texture2D or normal_tex is CompressedTexture2D:
			new_material.normal_enabled = true
			new_material.normal_texture = normal_tex
			_print_info("Normal map texture set from: " + resolved_normal_path)
		else:
			_print_warning("Could not load normal map texture from path: {p}".format({"p": resolved_normal_path}))

	var resolved_metal_path = convert_uid(get_metal_map_path())
	if not resolved_metal_path.is_empty():
		var metal_tex = ResourceLoader.load(resolved_metal_path)
		if metal_tex is Texture2D or metal_tex is CompressedTexture2D:
			new_material.metallic_texture = metal_tex
			new_material.metallic_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_RED
			new_material.metallic = 1.0
			_print_info("Metal map texture set from: " + resolved_metal_path)
		else:
			_print_warning("Could not load metal map texture from path: {p}".format({"p": resolved_metal_path}))

	var resolved_emission_path = convert_uid(get_emission_map_path())
	if not resolved_emission_path.is_empty():
		var emission_tex = ResourceLoader.load(resolved_emission_path)
		if emission_tex is Texture2D or emission_tex is CompressedTexture2D:
			new_material.emission_enabled = true
			new_material.emission_texture = emission_tex
			new_material.emission_strength = 1.0
			_print_info("Emission map texture set from: " + resolved_emission_path)
		else:
			_print_warning("Could not load emission map texture from path: {p}".format({"p": resolved_emission_path}))

	var resolved_roughness_path = convert_uid(get_roughness_map_path())
	if not resolved_roughness_path.is_empty():
		var roughness_tex = ResourceLoader.load(resolved_roughness_path)
		if roughness_tex is Texture2D or roughness_tex is CompressedTexture2D:
			new_material.roughness_texture = roughness_tex
			new_material.roughness_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_GREEN
			new_material.roughness = 1.0
			_print_info("Roughness map texture set from: " + resolved_roughness_path)
		else:
			_print_warning("Could not load roughness map texture from path: {p}".format({"p": resolved_roughness_path}))

	var resolved_material_dir = convert_uid(get_material_directory())
	if resolved_material_dir.is_empty():
		_print_warning("Material output directory is not set. New material will not be saved to disk.")
		return new_material

	var base_filename_for_mat: String
	if not self.original_path.is_empty() and not (self.original_path.ends_with(".tres") or self.original_path.ends_with(".material")):
		base_filename_for_mat = self.original_path.get_file().get_basename()
	elif albedo_tex_to_use != null and not albedo_tex_to_use.resource_path.is_empty():
		base_filename_for_mat = albedo_tex_to_use.resource_path.get_file().get_basename()
	else:
		_print_warning("Could not determine a base filename for the new material from '{orig}'. It will not be saved.".format({"orig": self.original_path}))
		return new_material

	if base_filename_for_mat.is_empty():
		_print_warning("Base filename for material is empty. Material will not be saved.")
		return new_material
		
	var material_save_path = resolved_material_dir.path_join(base_filename_for_mat + ".material")

	var save_error = ResourceSaver.save(new_material, material_save_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if save_error != OK:
		_print_error("Failed to save new material to: {p} Error: {e}".format({"p": material_save_path, "e": error_string(save_error)}))
	else:
		_print_info("Saved new material to: {p}".format({"p": material_save_path}))
		albedo_or_material_path_internal = material_save_path
	return new_material

func _auto_fill_texture_paths():
	if self.original_path.is_empty() or self.original_path.ends_with(".tres") or self.original_path.ends_with(".material"):
		_print_debug("Albedo/Material path '{p}' is empty, a .tres, or .material file, skipping auto-fill.".format({"p": self.original_path}))
		return

	var base_dir = self.original_path.get_base_dir()
	var file_name_no_ext = self.original_path.get_file().get_basename()
	var original_ext = self.original_path.get_extension()

	var common_image_extensions = ["png", "jpg", "jpeg", "tga", "bmp", "exr", "hdr"]
	if not original_ext.to_lower() in common_image_extensions:
		_print_debug("Original path '{p}' extension is not a common image type, skipping auto-fill.".format({"p": self.original_path}))
		return

	var suffixes_map = {
		"normal": ["_normal", "_nrm", "_n", "_Normal", "_N"],
		"metal": ["_metal", "_metallic", "_m", "_Metallic", "_M"],
		"emission": ["_emission", "_emissive", "_e", "_emit", "_Emission", "_E"],
		"roughness": ["_roughness", "_rough", "_r", "_Roughness", "_R", "_Gloss", "_gloss"]
	}

	var found_normal = ""
	for suffix in suffixes_map.normal:
		var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + original_ext)
		if FileAccess.file_exists(potential_path):
			found_normal = potential_path
			break
	if found_normal.is_empty():
		for suffix in suffixes_map.normal:
			for alt_ext in common_image_extensions:
				if alt_ext == original_ext: continue
				var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + alt_ext)
				if FileAccess.file_exists(potential_path):
					found_normal = potential_path
					break
			if not found_normal.is_empty(): break
	if not found_normal.is_empty() and normal_line_edit.text.is_empty(): normal_line_edit.text = found_normal

	var found_metal = ""
	for suffix in suffixes_map.metal:
		var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + original_ext)
		if FileAccess.file_exists(potential_path):
			found_metal = potential_path
			break
	if found_metal.is_empty():
		for suffix in suffixes_map.metal:
			for alt_ext in common_image_extensions:
				if alt_ext == original_ext: continue
				var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + alt_ext)
				if FileAccess.file_exists(potential_path):
					found_metal = potential_path
					break
			if not found_metal.is_empty(): break
	if not found_metal.is_empty() and metal_line_edit.text.is_empty(): metal_line_edit.text = found_metal
	
	var found_emission = ""
	for suffix in suffixes_map.emission:
		var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + original_ext)
		if FileAccess.file_exists(potential_path):
			found_emission = potential_path
			break
	if found_emission.is_empty():
		for suffix in suffixes_map.emission:
			for alt_ext in common_image_extensions:
				if alt_ext == original_ext: continue
				var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + alt_ext)
				if FileAccess.file_exists(potential_path):
					found_emission = potential_path
					break
			if not found_emission.is_empty(): break
	if not found_emission.is_empty() and emission_line_edit.text.is_empty(): emission_line_edit.text = found_emission

	var found_roughness = ""
	for suffix in suffixes_map.roughness:
		var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + original_ext)
		if FileAccess.file_exists(potential_path):
			found_roughness = potential_path
			break
	if found_roughness.is_empty():
		for suffix in suffixes_map.roughness:
			for alt_ext in common_image_extensions:
				if alt_ext == original_ext: continue
				var potential_path = base_dir.path_join(file_name_no_ext + suffix + "." + alt_ext)
				if FileAccess.file_exists(potential_path):
					found_roughness = potential_path
					break
			if not found_roughness.is_empty(): break
	if not found_roughness.is_empty() and roughness_line_edit.text.is_empty(): roughness_line_edit.text = found_roughness

	_print_debug("Auto-filled texture paths based on albedo path: {p}".format({"p": self.original_path}))
	_print_debug("Found Normal: {n}, Metal: {m}, Emission: {e}, Roughness: {r}".format({
		"n": found_normal if not found_normal.is_empty() else "None",
		"m": found_metal if not found_metal.is_empty() else "None",
		"e": found_emission if not found_emission.is_empty() else "None",
		"r": found_roughness if not found_roughness.is_empty() else "None",
	}))

## --- FBX Texturing Section ---
func process_fbx_files():
	_print_info("--- Starting FBX Batch Processing ---")

	var resolved_fbx_dir = convert_uid(get_fbx_directory())
	var resolved_output_scene_dir = convert_uid(get_output_scene_directory())

	if resolved_fbx_dir.is_empty():
		_print_error("FBX directory is not set or could not be resolved.")
		return
	if resolved_output_scene_dir.is_empty():
		_print_error("Output scene directory is not set or could not be resolved.")
		return
	if self.original_path.is_empty():
		_print_error("Albedo or Material path (resolved) is not set.")
		return

	var target_material: StandardMaterial3D = _prep_material()
	if target_material == null:
		_print_error("Material preparation failed. Aborting FBX processing.")
		return

	var dir = DirAccess.open(resolved_fbx_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".fbx"):
				current_file = file_name
				_print_debug("Identified FBX file: " + file_name)
				var fbx_full_path = resolved_fbx_dir.path_join(file_name)
				_print_debug("Processing FBX at: " + fbx_full_path)
				_process_single_fbx(fbx_full_path, target_material, resolved_output_scene_dir)
			file_name = dir.get_next()
		_print_info("--- FBX Batch Processing Finished ---")
	else:
		_print_error("Could not open FBX directory: {d}".format({"d": resolved_fbx_dir}))

func _process_single_fbx(fbx_path: String, target_material: StandardMaterial3D, resolved_output_dir: String):
	_print_info("Processing FBX: {p}".format({"p": fbx_path}))

	var fbx_resource: PackedScene = ResourceLoader.load(fbx_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if fbx_resource == null:
		_print_error("Failed to load FBX resource as PackedScene: {p}".format({"p": fbx_path}))
		return

	var fbx_scene_instance: Node = fbx_resource.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if fbx_scene_instance == null:
		_print_error("Failed to instantiate FBX scene: {p}".format({"p": fbx_path}))
		return

	var mesh_instance_original = _find_mesh_instance(fbx_scene_instance)
	if mesh_instance_original == null:
		_print_warning("No MeshInstance3D found in FBX file: {p}. Skipping.".format({"p": fbx_path}))
		fbx_scene_instance.queue_free()
		return

	# Create the new MeshInstance3D
	var new_mesh_instance = MeshInstance3D.new()

	if mesh_instance_original.mesh:
		new_mesh_instance.mesh = mesh_instance_original.mesh.duplicate(true)
	else:
		_print_warning("Original MeshInstance in {p} has no mesh resource. Skipping.".format({"p": fbx_path}))
		fbx_scene_instance.queue_free()
		new_mesh_instance.queue_free()
		return

	# Set the name for the MeshInstance3D
	var scene_name = fbx_path.get_file().get_basename()
	new_mesh_instance.name = scene_name
	new_mesh_instance.transform = mesh_instance_original.transform

	_print_debug("Prepared MeshInstance3D '{name}'.".format({"name": new_mesh_instance.name}))

	# Apply material
	if new_mesh_instance.mesh != null:
		var surface_count = new_mesh_instance.mesh.get_surface_count()
		if surface_count > 0:
			new_mesh_instance.material_override = target_material
			_print_info("Applied material override to MeshInstance3D '{name}'.".format({"name": new_mesh_instance.name}))
		else:
			_print_warning("MeshInstance3D '{name}' has no surfaces.".format({"name": new_mesh_instance.name}))
	else:
		_print_warning("MeshInstance3D '{name}' has no mesh resource after duplication.".format({"name": new_mesh_instance.name}))

	# Determine root node based on mesh_only setting
	var root_node: Node3D = Node3D.new()
	
	if mesh_only:
		# Old behavior: MeshInstance3D is the root
		_print_debug("Using mesh-only mode for {name}".format({"name": scene_name}))
		root_node = new_mesh_instance
	else:
		# New default behavior: Create the full scene structure
		_print_debug("Creating physics-enabled scene for {name}".format({"name": scene_name}))
		
		# Create the root Node3D
		root_node = Node3D.new()
		root_node.set_name(scene_name)
		
		# Reparent the MeshInstance3D to the new root
		root_node.add_child(new_mesh_instance)
		new_mesh_instance.set_owner(root_node)
		
		# Add physics components based on selected collision type
		_add_physics_components(new_mesh_instance)

	# Save the scene
	var scene_save_path = resolved_output_dir.path_join(scene_name + ".tscn")
	var packed_scene_to_save = PackedScene.new()

	var pack_error = packed_scene_to_save.pack(root_node)
	if pack_error != OK:
		_print_error("Failed to pack scene for saving: {p} Error: {e}".format({"p": scene_save_path, "e": error_string(pack_error)}))
	else:
		var save_error = ResourceSaver.save(packed_scene_to_save, scene_save_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
		if save_error != OK:
			_print_error("Failed to save scene to: {p} Error: {e}".format({"p": scene_save_path, "e": error_string(save_error)}))
		else:
			_print_info("Successfully saved scene to: {p}".format({"p": scene_save_path}))

	# Clean up
	fbx_scene_instance.queue_free()
	
	# Only free new_mesh_instance if it's NOT the root node (when mesh_only is false)
	if not mesh_only:
		new_mesh_instance.queue_free()

	current_file = ""

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found != null:
			return found
	return null

## --- Verbosity Helpers ---
func _print_error(message: String):
	if current_verbosity >= Verbosity.ERRORS:
		printerr("ERROR (FBX Importer): {msg}".format({"msg": message}))

func _print_warning(message: String):
	if current_verbosity >= Verbosity.WARNINGS:
		print("WARNING (FBX Importer): {msg}".format({"msg": message}))

func _print_info(message: String):
	if current_verbosity >= Verbosity.INFO:
		print("INFO (FBX Importer): {msg}".format({"msg": message}))

func _print_debug(message: String):
	if current_verbosity >= Verbosity.DEBUG:
		print("DEBUG (FBX Importer): {msg}".format({"msg": message}))

# Add this new function to handle physics setup
func _add_physics_components(mesh_instance: MeshInstance3D) -> void:
	_print_debug("Adding physics components to {name} with collision type: {type}".format({
		"name": mesh_instance.name, 
		"type": CollisionShapes.keys()[current_shape]
	}))
	
	# Use Godot's built-in methods for collision generation
	match current_shape:
		CollisionShapes.TRIMESH_COLLISION:
			mesh_instance.create_trimesh_collision()
			_print_debug("Created trimesh collision for {name}".format({"name": mesh_instance.name}))
		CollisionShapes.SINGLE_CONVEX_COLLISION:
			mesh_instance.create_convex_collision(false)
			_print_debug("Created single convex collision for {name}".format({"name": mesh_instance.name}))
		CollisionShapes.SIMPLIFIED_CONVEX_COLLISION:
			mesh_instance.create_convex_collision(true)
			_print_debug("Created simplified convex collision for {name}".format({"name": mesh_instance.name}))
		CollisionShapes.MULTIPLE_CONVEX_COLLISION:
			mesh_instance.create_multiple_convex_collisions()
			_print_debug("Created multiple convex collisions for {name}".format({"name": mesh_instance.name}))
		_:
			_print_warning("Unknown collision shape type selected: {t}".format({"t": current_shape}))
			mesh_instance.create_trimesh_collision()
