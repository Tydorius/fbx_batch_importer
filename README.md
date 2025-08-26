## FBX Batch Importer

# Godot 4.4 FBX Batch Importer & Texturer Tool

## Description

This tool script for Godot Engine 4.4 automates the process of importing multiple FBX files from a specified directory, extracting the primary mesh from each, applying a material, generating a collision shape, and saving each textured mesh as a new `.tscn` scene file. The material can either be loaded from an existing Godot Material resource or automatically created from a set of provided textures (Albedo, Normal, Metal, Emission, Roughness).

Originally, this only created a MeshInstance3D and created a scene with only the single object. Based on feedback, I have added additional functionality that uses the MeshInstance3D built in functions to automatically generate a collision mesh. The old functionality can be used through a new checkbox labeled 'Only Output Mesh TSCN'.

## Benefits

This gets around some limitations on bulk importing FBX files from asset providers such as Synty. The end result is a tscn with only a single mesh inside. No animationplayers, no blank material 0, no hoping the fbx is configured to load an actual texture so you don't have to manually apply it yourself.

## Requirements

* Godot Engine 4.4 or later.
    * Note: Because of the addition of UIDs, this plugin expect 4.4 or later. It is untested on <4.4.
* A Godot project setup.

## Instructions

1.  Add the folder fbx_bulk_conversion to your `addons` folder.
2.  Add the addon to your project.
3.  Under Project> Tools, select FBX Batch Importer
4.  Select your material file for albedo / material. This can be an image file or .tres file.
5.  If you are using image files, you can create a material with additional layers by populating the 'normal', 'metal', etc. fields with their corresponding files.
6.  Select the material output folder if you are creating a material. If you are using a .tres file that is a complete 'material' and not a compressed texture 2D, you do not need to select this option.
7.  If you only wish to process the material, you can use the "Process & Save Material" button once you've selected the files and the output destination.
8.  Select the FBX source directory.
9.  Select the output directory for your TSCN files.
10. If you wish to only generate TSCN files containing a single MeshInstance3D, check the 'Only Output Mesh TSCN' checkbox.
11. Otherwise, use the dropdown to select the type of mesh you wish to generate.
12. Trigger the batch with the "Process FBX Files" button.

## Notes

The best place to report issues is via [Github](https://github.com/Tydorius/fbx_batch_importer/issues).

## Support Me

You can donate to me through my itch.io [profile](https://tydorius.itch.io/godot-fbx-batch-importer) or through my Ko-fi [link](https://ko-fi.com/tydorius).
