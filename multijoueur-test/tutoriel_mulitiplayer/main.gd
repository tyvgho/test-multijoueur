# main.gd
extends Node3D

var lobby_id = 0
var peer: SteamMultiplayerPeer

@export var player_scene: PackedScene
@export var host_button: Button
@export var multiplayer_spawner: MultiplayerSpawner
@export var join_button: Button
@export var id_prompt: LineEdit
@export var ui: Control
@export var USE_STEAM = true

var is_joining = false

func _ready():
	print("=== READY ===")
	var init = Steam.steamInit(480, true)
	print("Steam init result: ", init)
	print("Steam App ID: ", Steam.getAppID())
	print("Mon Steam ID: ", Steam.getSteamID())
	print("Mon pseudo Steam: ", Steam.getPersonaName())
	Steam.initRelayNetworkAccess()

	multiplayer_spawner.spawn_function = summon_player
	print("spawn_function assignée")

	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_remove_player)
	print("=== READY OK ===")

# ── HÔTE ────────────────────────────────────────────────────────────────────

func host_lobby():
	print("=== HOST LOBBY ===")
	join_button.disabled = true
	if USE_STEAM:
		print("Création lobby Steam PUBLIC 16 slots...")
		Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 16)
	else:
		_host_local(7777)

func _host_local(port: int):
	print("=== HOST LOCAL port:", port, " ===")
	var enet_peer = ENetMultiplayerPeer.new()
	enet_peer.create_server(port, 16)
	multiplayer.multiplayer_peer = enet_peer
	_spawn_player(1)

func _on_lobby_created(result: int, new_lobby_id: int):
	print("=== LOBBY CREATED === result:", result, " id:", new_lobby_id)
	if result != Steam.Result.RESULT_OK:
		print("ERREUR création lobby, code: ", result)
		return

	ui.visible = false
	lobby_id = new_lobby_id

	var set_type = Steam.setLobbyType(lobby_id, Steam.LobbyType.LOBBY_TYPE_PUBLIC)
	print("setLobbyType OK: ", set_type)
	var set_join = Steam.setLobbyJoinable(lobby_id, true)
	print("setLobbyJoinable OK: ", set_join)

	Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s lobby")
	Steam.setLobbyData(lobby_id, "map", "level_01")
	Steam.setLobbyData(lobby_id, "version", "1.0.0")
	print("Lobby data set")

	peer = SteamMultiplayerPeer.new()
	var host_result = peer.create_host(1)
	print("create_host result: ", host_result)
	multiplayer.multiplayer_peer = peer
	print("multiplayer_peer assigné")
	print("Mon peer ID (hôte): ", multiplayer.get_unique_id())

	_spawn_player(multiplayer.get_unique_id())
	print(">>> LOBBY ID À DONNER AU CLIENT : ", lobby_id, " <<<")

# ── CLIENT ───────────────────────────────────────────────────────────────────

func join_lobby(target_lobby_id: int):
	print("=== JOIN LOBBY === target_id:", target_lobby_id)
	if USE_STEAM:
		is_joining = true
		print("Appel Steam.joinLobby(", target_lobby_id, ")")
		Steam.joinLobby(target_lobby_id)
		print("joinLobby appelé, en attente du signal lobby_joined...")
	else:
		_join_local("127.0.0.1", 7777)

func _join_local(ip: String, port: int):
	print("=== JOIN LOCAL ", ip, ":", port, " ===")
	var enet_peer = ENetMultiplayerPeer.new()
	enet_peer.create_client(ip, port)
	multiplayer.multiplayer_peer = enet_peer

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int):
	print("un joueur ces conecter au lobby")
	print("=== LOBBY JOINED === id:", joined_lobby_id, " response:", response, " is_joining:", is_joining)
	if response != Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("ERREUR connexion lobby code: ", response)
		is_joining = false
		return

	ui.visible = false
	lobby_id = joined_lobby_id
	is_joining = false
	print("Lobby rejoint avec succès, lobby_id=", lobby_id)

	# Vérifier les membres du lobby
	var member_count = Steam.getNumLobbyMembers(lobby_id)
	print("Membres dans le lobby: ", member_count)
	for i in member_count:
		print("  Membre ", i, " : ", Steam.getLobbyMemberByIndex(lobby_id, i))

	peer = SteamMultiplayerPeer.new()
	print("Appel create_client(", lobby_id, ", 0)...")
	var client_result = peer.create_client(lobby_id, 1)
	print("create_client result: ", client_result)

	multiplayer.multiplayer_peer = peer
	print("multiplayer_peer assigné côté client")
	print("Mon peer ID (avant connexion): ", multiplayer.get_unique_id())

	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	print("Signaux connected_to_server et connection_failed connectés, en attente...")

func _on_connection_failed():
	print("!!! CONNEXION AU SERVEUR ÉCHOUÉE !!!")

func _on_connected_to_server():
	print("=== CONNECTED TO SERVER ===")
	var my_id = multiplayer.get_unique_id()
	print("Mon peer ID (après connexion): ", my_id)
	print("Envoi request_spawn.rpc_id(1, ", my_id, ")")
	request_spawn.rpc_id(1, my_id)

# ── GESTION DES PEERS ────────────────────────────────────────────────────────

func _on_peer_connected(player_id: int):
	print("=== PEER CONNECTED === player_id:", player_id, " | je suis serveur:", multiplayer.is_server())
	if multiplayer.is_server():
		_spawn_player(player_id)

func _remove_player(player_id: int):
	print("=== PEER DISCONNECTED === player_id:", player_id)
	var node_path = str(player_id)
	if has_node(node_path):
		get_node(node_path).queue_free()
		print("Joueur ", player_id, " supprimé")
	else:
		print("Joueur ", player_id, " introuvable pour suppression")

# ── SPAWN ────────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func request_spawn(player_id: int):
	print("=== REQUEST_SPAWN reçu === player_id:", player_id, " | je suis serveur:", multiplayer.is_server())
	if not multiplayer.is_server():
		print("Je ne suis pas le serveur, j'ignore")
		return
	if not has_node(str(player_id)):
		_spawn_player(player_id)
	else:
		print("Joueur ", player_id, " déjà spawné")

func _spawn_player(player_id: int):
	print("=== SPAWN PLAYER === player_id:", player_id)
	if has_node(str(player_id)):
		print("Joueur ", player_id, " déjà présent, skip")
		return
	print("Appel multiplayer_spawner.spawn(", player_id, ")")
	multiplayer_spawner.spawn(player_id)
	print("Spawn OK pour ", player_id)

func summon_player(player_id: int) -> Node:
	print("=== SUMMON PLAYER === player_id:", player_id)
	var player = player_scene.instantiate()
	player.name = str(player_id)
	player.set_multiplayer_authority(player_id)
	print("Joueur instancié: ", player.name, " | autorité: ", player.get_multiplayer_authority())
	return player

# ── UI ───────────────────────────────────────────────────────────────────────

func _on_host_button_pressed():
	host_lobby()

func _on_join_button_pressed():
	print("=== JOIN BUTTON PRESSED === texte saisi: '", id_prompt.text, "'")
	var parsed_id = int(id_prompt.text)
	print("ID parsé: ", parsed_id)
	join_lobby(parsed_id)

func _on_id_prompt_text_changed(new_text: String):
	join_button.disabled = (new_text.length() == 0)

# autres
func _physics_process(delta):
	Steam.run_callbacks()
	if Input.is_action_just_pressed("ui_down"):
		print_loby_info(lobby_id)

func print_loby_info(id):
	print("ID du lobby: ", id)
	print("Nom du lobby: ", Steam.getLobbyData(id, "name"))
	print("Map: ", Steam.getLobbyData(id, "map"))
	print("Version: ", Steam.getLobbyData(id, "version"))
	print("Membres: ", Steam.getNumLobbyMembers(id))
	print("Limite de membres: ", Steam.getLobbyMemberLimit(id))
	print("player nobres", Steam.getLobbyData(id, "players"))