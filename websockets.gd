extends Node

var config_file: String = "res://addons/websockets/config.ini"
var server: String = "localhost"
var port: int = 25565
var is_server: bool = false

func _init():
    var config = ConfigFile.new()
    var status = config.load(config_file)
    if status == OK:
        if config.has_section_key("main", "server"):
            server = config.get_value("main", "server", "localhost")
            port = config.get_value("main", "port", 25565)
            is_server = config.get_value("main", "is_server", false)
            pass
    printerr("Unable to read config file " + config_file)
        
func _enter_tree() -> void:
    print("websockets entered tree")

func _exit_tree() -> void:
    print("websockets left tree")
