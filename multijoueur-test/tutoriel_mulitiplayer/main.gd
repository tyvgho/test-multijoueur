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
	print("Initializing Steam ", Steam.steamInit(480, true))
	Steam.initRelayNetworkAccess()
	# On utilise le MultiplayerSpawner correctement :
	# sa spawn_function est appelée quand on fait multiplayer_spawner.spawn(data)
	multiplayer_spawner.spawn_function = summon_player

	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)

	# Ces signaux viennent du MultiplayerAPI, pas de Steam
	# On les connecte ici une seule fois
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_remove_player)

# ── HÔTE ────────────────────────────────────────────────────────────────────

func host_lobby():
	join_button.disabled = true
	if USE_STEAM:
		# ← FRIENDS_ONLY pour les tests, tu pourras repasser en PUBLIC après
		Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 16)
	else:
		_host_local(7777)

func _host_local(port: int):
	var enet_peer = ENetMultiplayerPeer.new()
	enet_peer.create_server(port, 16)
	multiplayer.multiplayer_peer = enet_peer  # ← IMPORTANT : assigner avant tout
	_spawn_player(1)  # Instancier le joueur hôte

func _on_lobby_created(result: int, new_lobby_id: int):
	if result != Steam.Result.RESULT_OK:
		print("Échec création lobby : ", result)
		return

	ui.visible = false
	lobby_id = new_lobby_id

	# ← Changer en FRIENDS_ONLY pour les tests entre amis
	Steam.setLobbyType(lobby_id, Steam.LobbyType.LOBBY_TYPE_PUBLIC)

	# ← Ajouter ceci : rendre le lobby joignable
	Steam.setLobbyJoinable(lobby_id, true)

	Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s lobby")
	Steam.setLobbyData(lobby_id, "map", "level_01")
	Steam.setLobbyData(lobby_id, "version", "1.0.0")

	peer = SteamMultiplayerPeer.new()
	peer.create_host(0)
	multiplayer.multiplayer_peer = peer

	_spawn_player(multiplayer.get_unique_id())

	# ← Afficher l'ID du lobby pour le copier facilement
	print("Lobby créé ! ID : ", lobby_id)

# ── CLIENT ───────────────────────────────────────────────────────────────────

func join_lobby(target_lobby_id: int):
	if USE_STEAM:
		is_joining = true
		Steam.joinLobby(target_lobby_id)
	else:
		_join_local("127.0.0.1", 7777)

func _join_local(ip: String, port: int):
	var enet_peer = ENetMultiplayerPeer.new()
	enet_peer.create_client(ip, port)
	multiplayer.multiplayer_peer = enet_peer

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response != Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Échec connexion lobby : ", response)
		is_joining = false
		return

	if not is_joining:
		return

	ui.visible = false
	lobby_id = joined_lobby_id
	is_joining = false

	peer = SteamMultiplayerPeer.new()
	peer.create_client(lobby_id, 0)

	# ← CORRECTION 2 : assigner le peer AVANT tout RPC ou spawn
	# Le signal peer_connected se déclenchera automatiquement une fois connecté
	multiplayer.multiplayer_peer = peer

	# NE PAS appeler _add_player ici manuellement.
	# Le signal multiplayer.connected_to_server va gérer ça proprement.
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)

func _on_connected_to_server():
	# On est maintenant connecté, on connaît notre vrai peer ID
	# On demande à l'hôte de nous spawner
	var my_id = multiplayer.get_unique_id()
	print("Connecté au serveur, mon ID : ", my_id)
	# Demander à l'hôte de spawner notre personnage pour tout le monde
	request_spawn.rpc_id(1, my_id)

# ── GESTION DES PEERS ────────────────────────────────────────────────────────

func _on_peer_connected(player_id: int):
	# Ce signal est déclenché sur l'hôte quand un client se connecte,
	# ET sur tous les clients quand un nouveau pair arrive.
	# L'hôte gère le spawn ; les clients reçoivent via le MultiplayerSpawner.
	print("Peer connecté : ", player_id)
	if multiplayer.is_server():
		# L'hôte spawne le joueur pour tout le monde
		_spawn_player(player_id)

func _remove_player(player_id: int):
	var node_path = str(player_id)
	if has_node(node_path):
		get_node(node_path).queue_free()

# ── SPAWN ────────────────────────────────────────────────────────────────────

# Appelé par le client sur l'hôte pour demander son spawn
# (utile si peer_connected n'est pas fiable dans ton setup Steam)
@rpc("any_peer", "call_local", "reliable")
func request_spawn(player_id: int):
	print("Demande de spawn de ", player_id)
	# Seul l'hôte exécute réellement le spawn
	if not multiplayer.is_server():
		return
	# Éviter un double spawn si peer_connected l'a déjà fait
	if not has_node(str(player_id)):
		_spawn_player(player_id)

func _spawn_player(player_id: int):
	# ← CORRECTION 3 : on passe par le MultiplayerSpawner
	# Il va appeler summon_player(player_id) et répliquer le nœud
	# automatiquement sur tous les clients connectés ET futurs.
	if has_node(str(player_id)):
		print("Joueur ", player_id, " déjà spawné, on ignore")
		return
	multiplayer_spawner.spawn(player_id)

func summon_player(player_id: int) -> Node:
	var player = player_scene.instantiate()
	player.name = str(player_id)

	# ← CORRECTION 4 : set_multiplayer_authority AVANT add_child
	# Comme summon_player est appelé par le spawner qui fait add_child ensuite,
	# on peut déjà configurer l'autorité ici.
	player.set_multiplayer_authority(player_id)

	print("Spawn joueur ", player_id, " | autorité : ", player_id)
	return player

# ── UI ───────────────────────────────────────────────────────────────────────

func _on_host_button_pressed():
	host_lobby()

func _on_join_button_pressed():
	join_lobby(int(id_prompt.text))

func _on_id_prompt_text_changed(new_text: String):
	join_button.disabled = (new_text.length() == 0)
