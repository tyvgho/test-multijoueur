extends Node3D


var lobby_id = 0
var peer : SteamMultiplayerPeer
@export var player_scene : PackedScene

@export var host_button : Button
@export var join_button : Button
@export var id_prompt : LineEdit

@export var ui : Control

@export var USE_STEAM = true
var is_host = false
var is_joining = false

func _ready():
	print("Initializing Steam ",Steam.steamInit(480,true))
	Steam.initRelayNetworkAccess()

	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)


func host_lobby():
	join_button.disabled = true
	if USE_STEAM:
		Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 16)
		is_host = true
	else:
		_host_local(7777)

func _host_local(port: int):
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 16)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	_add_player(1)

func _on_lobby_created(result: int, lobby_id: int):
	if result == Steam.Result.RESULT_OK:
		self.lobby_id = lobby_id
		Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s lobby")
		Steam.setLobbyData(lobby_id, "map", "level_01")
		Steam.setLobbyData(lobby_id, "version", "1.0.0")

		peer = SteamMultiplayerPeer.new()
		peer.create_host(true)
		multiplayer.multiplayer_peer = peer   # ✅ manquait dans ton code
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_add_player(1)
		ui.visible = false
		print("Lobby created with id ", lobby_id)
func join_lobby(lobby_id : int):
	if USE_STEAM:
		is_joining = true
		Steam.joinLobby(lobby_id)
	else:
		_join_local("127.0.0.1", 7777)

func _join_local(ip: String, port: int):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer

func _on_lobby_joined(lobby_id, permissions, locked, response):
	print("_on_lobby_joined -> id:%s perm:%s locked:%s response:%s" % [lobby_id, permissions, locked, response])

	if int(response) != 1:
		print("Échec de la connexion, code : ", response)
		is_joining = false
		return

	if !is_joining:
		return

	ui.visible = false
	self.lobby_id = int(lobby_id)

	var owner_id : int = Steam.getLobbyOwner(lobby_id)
	print("Owner ID : ", owner_id)

	peer = SteamMultiplayerPeer.new()
	# owner_id est un Steam ID 64-bit, on le passe directement SANS cast int()
	var err = peer.create_client(owner_id)
	print("create_client error code : ", err)

	if err != OK:
		print("Échec create_client : ", err)
		is_joining = false
		return

	multiplayer.multiplayer_peer = peer
	is_joining = false
	print("Peer client créé, owner : ", owner_id)

func _add_player(player_id : int):
	var player = player_scene.instantiate()
	player.name = str(player_id)
	call_deferred("add_child",player)

func _remove_player(player_id : int):
	if !self.has_node(str(player_id)): return
	self.get_node(str(player_id)).queue_free()

func _on_host_button_pressed() -> void:
	host_lobby()


func _on_id_prompt_text_changed(new_text: String) -> void:
	join_button.disabled =(new_text.length() == 0)


func _on_join_button_pressed() -> void:
	join_lobby(int(id_prompt.text.to_int()))
