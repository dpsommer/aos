extends RefCounted
## The fixture model libraries in test/fixtures/, shared by the 3D model tests so they never load
## the real models in assets/3d/models/ (which CI checks out as Git LFS pointers).
## Preload it: const ModelKit := preload("res://test/support/model_kit.gd")

## Untextured models: Lone Statue, Plain Guard, Test Shrine and the Twin Raiders variants.
const MODELS := "res://test/fixtures/models"
## Painted Guard, whose .mtl gives it its own material.
const TEXTURED := "res://test/fixtures/models_textured"
## Pointer Model, a Git LFS pointer that Godot fails to import.
const UNIMPORTED := "res://test/fixtures/models_unimported"


static func library() -> ModelLibrary:
	return ModelLibrary.new(MODELS)


static func textured_library() -> ModelLibrary:
	return ModelLibrary.new(TEXTURED)


static func unimported_library() -> ModelLibrary:
	return ModelLibrary.new(UNIMPORTED)
