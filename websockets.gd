extends Node

var debug: bool = false

var config_file: String = "res://addons/websockets/config.ini"
var init: bool = false
var hostname: String = "localhost"
var port: int = 25565
var is_server: bool = false
var client: WebSocketClient
var server: WebSocketServer
var server_ready: bool = false
var client_ready: bool = false

var cert_path: String = "res://addons/websockets/wsserver.crt"
var key_path: String = "res://addons/websockets/wsserver.key"

var cert: X509Certificate = X509Certificate.new()
var key: CryptoKey = CryptoKey.new()

var pairings: Dictionary = {}
var opponent_id: int = -1
var player_number = -1
signal pairing_complete
signal opponent_left

func _init():
    var config = ConfigFile.new()
    var status = config.load(config_file)
    if status == OK:
        if config.has_section_key("main", "hostname"):
            hostname = config.get_value("main", "hostname", "localhost")
            port = config.get_value("main", "port", 25565)
            is_server = config.get_value("main", "is_server", true)
            debug = config.get_value("main", "debug", false)
            cert_path = config.get_value("main", "cert_path", "res://addons/websockets/wsserver.crt")
            key_path = config.get_value("main", "key_path", "res://addons/websockets/wsserver.key")
            cert.load(cert_path)
            init = true
            return
    printerr(Time.get_datetime_string_from_system() + ": Unable to read config file " + config_file)

func _ready():
    if OS.get_name() == "HTML5":
        is_server = false
    if is_server and !server_ready:
        server_connect()
    elif !client_ready:
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
    if hostname != "localhost":
        key.load(key_path)
        server.private_key = key
        server.ssl_certificate = cert
    var status: int = server.listen(port, PoolStringArray(["wsserver-1.0"]), true);
    if status != OK:
        print(Time.get_datetime_string_from_system() + ": Unable to start at " + hostname + ":" + str(port))
    else:
        get_tree().set_network_peer(server);
        get_tree().set_meta("network_peer", server)
        __ = get_tree().connect("network_peer_connected", self, "_server_network_peer_connected")
        __ = get_tree().connect("network_peer_disconnected", self, "_server_network_peer_disconnected")
        if get_tree().is_network_server():
            print(Time.get_datetime_string_from_system() + ": " + server.to_string() + " listening on " + str(hostname) + ":" + str(port))
            server_ready = true

func client_connect():
    if !client_ready:
        var __
        var prefix = "ws://"
        client = WebSocketClient.new()
        if hostname != "localhost":
            client.trusted_ssl_certificate = cert
            prefix = "wss://"
        if OS.get_name() != "HTML5":
            client.verify_ssl = false
        var url = prefix + str(hostname) + ":" + str(port)
        var state: int = client.connect_to_url(url, PoolStringArray(["wsserver-1.0"]), true);
        if state != OK:
            dprint("Error connecting to server")
        else:
            __ = get_tree().connect("connected_to_server", self, "_client_connected_to_server")
            __ = get_tree().connect("connection_failed", self, "_client_connection_failed")
            __ = get_tree().connect("server_disconnected", self, "_client_server_disconnected")
            get_tree().set_network_peer(client)
            get_tree().set_meta("network_peer", client)
            client_ready = true

func client_disconnect():
    if client_ready:
        deregister_player(get_tree().get_network_unique_id())
        client.disconnect_from_host(1000, "Manually disconnected during game") 
        get_tree().set_network_peer(null)
        opponent_id = -1
        player_number = -1
        client_ready = false

func _server_network_peer_connected(id):
    print(Time.get_datetime_string_from_system() + ": Client connected from " + server.get_peer_address(id) + " with id " + str(id))

func _server_network_peer_disconnected(id):
    deregister_player(id)
    print(Time.get_datetime_string_from_system() + ": Client with id " + str(id) + " disconnected")

func _client_connected_to_server():
    dprint("" + client.to_string() + " connected to " + str(hostname) + " with id " + str(client.get_unique_id()))
    client_ready = true

func _client_server_disconnected():
    dprint("" + client.to_string() + " disconnected from " + str(hostname))
    client_ready = false

func _client_connection_failed():
    dprint("unable to connect to server " + str(hostname))
    client_ready = false

func dprint(msg: String):
    if debug:
        print(msg)

func send_code(code: String):
    if client_ready:
        rpc_id(1, "register_player", client.get_unique_id(), code)

remote func register_player(id: int, code: String) -> void:
    if !is_server:
        return
    if pairings.has(code):
        var pair = pairings[code]
        if pair.size() > 1:
            if pair[0] == id or pair[1] == id:
                rpc_id(pair[0], "pairing_complete")
                rpc_id(pair[1], "pairing_complete")
                print(Time.get_datetime_string_from_system() + ": Re-paired " + str(pair[0]) + " and " + str(pair[1]) + " as player 1 and 2 respectively")
            else:
                printerr(Time.get_datetime_string_from_system() + ": Player " + str(id) + " attempted to register with code " + code + " in a game that is already fully paired")
        elif pair.size() == 0:
            pairings[code] = [id]
            if server.has_peer(id):
                rpc_id(id, "set_player_number", 0)
                print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " registered with code " + code + " as player 1 in existing game")
        elif pair.size() == 1:
            pairings[code] = [pair[0], id]
            print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " registered with code " + code + " as player 2 in existing game")
            if server.has_peer(pair[0]):
                rpc_id(pair[0], "set_opponent_id", id)
                rpc_id(pair[0], "set_player_number", 0)
                rpc_id(pair[0], "pairing_complete")
            if server.has_peer(id):
                rpc_id(id, "set_opponent_id", pair[0])
                rpc_id(id, "set_player_number", 1)
                rpc_id(id, "pairing_complete")
            print(Time.get_datetime_string_from_system() + ": Paired " + str(pair[0]) + " and " + str(id) + " as player 1 and 2 respectively")
    else:
        pairings[code] = [id]
        print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " registered with code " + code + " as player 1 in new game")

func deregister_player(id: int) -> void:
    if !is_server:
        return
    for code in pairings.keys():
        var pair = pairings[code]
        if pair.size() == 1 and pair[0] == id:
            pairings.erase(code)
            print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " deregistered with code " + code)
        elif pair.size() == 2 and (pair[0] == id or pair[1] == id):
            if (pair[0] == id):
                if server.has_peer(pair[1]):
                    rpc_id(pair[1], "opponent_left", id)
            if (pair[1] == id):
                if server.has_peer(pair[0]):
                    rpc_id(pair[0], "opponent_left", id)
            pairings.erase(code)
            print(Time.get_datetime_string_from_system() + ": Player " + str(id) + " deregistered with code " + code)

remote func set_opponent_id(id: int):
    opponent_id = id

remote func set_player_number(num: int):
    player_number = num

remote func opponent_left(id: int):
    if opponent_id == id:
        emit_signal("opponent_left", id)
        opponent_id = -1

remote func pairing_complete():
    emit_signal("pairing_complete")

func _exit_tree() -> void:
    if is_server and server_ready:
        for peer in get_tree().get_network_connected_peers():
            server.disconnect_peer(peer, 1000, "Server shutting down")
        server.stop()
        server_ready = false
        pairings = {}
    elif client_ready:
        client_disconnect()
    get_tree().set_network_peer(null)
