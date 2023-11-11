extends Node

var config_file: String = "res://addons/websockets/config.cfg"
var init: bool = false
var hostname: String = "localhost"
var port: int = 25565
var is_server: bool = false
var client: WebSocketClient
var server: WebSocketServer
var server_ready: bool = false
var client_ready: bool = false
var pairings: Dictionary = {}
var debug: bool = false

func _init():
    var config = ConfigFile.new()
    var status = config.load(config_file)
    if status == OK:
        if config.has_section_key("main", "hostname"):
            hostname = config.get_value("main", "hostname", "localhost")
            port = config.get_value("main", "port", 25565)
            is_server = config.get_value("main", "is_server", true)
            debug = config.get_value("main", "debug", false)
            init = true
            return
    printerr("Unable to read config file " + config_file)

func _ready():
    if OS.get_name() == "HTML5":
        is_server = false
    if is_server:
        server_connect()
    else:
        client_connect()
        
func _process(__: float):
    if init: 
        if is_server and server_ready:
            if server.is_listening():
                server.poll()
        elif client_ready:
            client.poll()

func server_connect():
    var __
    server = WebSocketServer.new()
    var status: int = server.listen(port, PoolStringArray(), true);
    if status != OK:
        print(Time.get_datetime_string_from_system() + ": Unable to start at " + hostname + ":" + str(port))
    else:
        get_tree().set_network_peer(server);
        get_tree().set_meta("network_peer", server)
        __ = get_tree().connect("network_peer_connected", self, "_server_network_peer_connected")
        __ = get_tree().connect("network_peer_disconnected", self, "_server_network_peer_disconnected")
        if get_tree().is_network_server():
            print(Time.get_datetime_string_from_system() + ": " + server.to_string() + " listening on " + str(hostname) + ":" + str(port) + " with id " + str(server.get_unique_id()))
            server_ready = true

func client_connect():
    var __
    client = WebSocketClient.new()
    var url = "ws://" + str(hostname) + ":" + str(port)
    var state: int = client.connect_to_url(url, PoolStringArray(), true);
    if state != OK:
        dprint("Error connecting to server")
    else:
        get_tree().set_network_peer(client)
        get_tree().set_meta("network_peer", client)
        __ = get_tree().connect("connected_to_server", self, "_client_connected_to_server")
        __ = get_tree().connect("connection_failed", self, "_client_connection_failed")
        __ = get_tree().connect("server_disconnected", self, "_client_server_disconnected")

func _server_network_peer_connected(id):
    print(Time.get_datetime_string_from_system() + ": Client connected with id " + str(id))

func _server_network_peer_disconnected(id):
    print(Time.get_datetime_string_from_system() + ": Client disconnected with id " + str(id))

func _client_connected_to_server():
    dprint("" + client.to_string() + " connected to " + str(hostname) + " with network id " + str(client.get_unique_id()))
    client_ready = true

func _client_server_disconnected():
    dprint("" + client.to_string() + " disconnected from " + str(hostname))

func _client_connection_failed():
    dprint("unable to connect to server " + str(hostname))

func dprint(msg: String):
    if debug:
        print(msg)

remote func register_player(id: int, code: String) -> void:
    if !is_server:
        return
    if pairings.has(code):
        var pair = pairings[code]
        if pair.size == 0:
            pairings[code] = [id]
            print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " registered with code " + code + " as player 1 in existing game")
        elif pair.size == 1:
            pairings[code] = [pair[0], id]
            print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " registered with code " + code + " as player 2 in existing game")
    else:
        pairings[code] = [id]
        print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " registered with code " + code + " as player 1 in new game")

remote func get_opponent_id(id: int, code: String) -> int:
    if !is_server:
        return -1
    return 0

func _exit_tree() -> void:
    if is_server:
        for peer in get_tree().get_network_connected_peers():
            server.disconnect_peer(peer, 1000, "Server shutting down")
            server.stop()
    else:
        client.disconnect_from_host(1000, "Client closing") 
    get_tree().set_network_peer(null)
