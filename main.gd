tool
extends EditorPlugin
const AUTOLOAD_NAME = "Websockets"

func _enter_tree() -> void:
    add_autoload_singleton(AUTOLOAD_NAME, "res://addons/websockets/websockets.gd")


func _exit_tree() -> void:
    remove_autoload_singleton(AUTOLOAD_NAME)
