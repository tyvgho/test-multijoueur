# lobby_browser.gd
extends Control

# Résultats de la recherche : Array[{id, name, players, max_players, map}]
var lobby_list: Array = []

@export var lobby_container: VBoxContainer  # parent des lignes UI
@export var lobby_row_scene: PackedScene    # voir Étape 3
@export var refresh_button: Button
@export var status_label: Label

func _ready():
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	refresh_button.pressed.connect(request_lobby_list)


# ── Lancer la recherche ──────────────────────────────────────────────────────

func request_lobby_list():
	lobby_list.clear()
	_clear_rows()
	status_label.text = "Recherche en cours…"
	refresh_button.disabled = true

	# Filtres optionnels (à adapter selon ton jeu)
	Steam.addRequestLobbyListStringFilter(
		"version", "1.0.0",
		Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL
	)
	Steam.addRequestLobbyListFilterSlotsAvailable(2)   # au moins 1 place libre

	Steam.requestLobbyList()


# ── Réception des résultats ──────────────────────────────────────────────────

func _on_lobby_match_list(lobbies: Array):
	refresh_button.disabled = false

	if lobbies.is_empty():
		status_label.text = "Aucun lobby trouvé."
		return

	status_label.text = "%d lobby(s) trouvé(s)" % lobbies.size()

	for id in lobbies:
		var entry = {
			"id":          id,
			"name":        Steam.getLobbyData(id, "name"),
			"map":         Steam.getLobbyData(id, "map"),
			"players":     Steam.getNumLobbyMembers(id),
			"max_players": Steam.getLobbyMemberLimit(id),
		}

		# Filtre côté client : ignorer les lobbies pleins
		if entry.players >= entry.max_players:
			continue

		lobby_list.append(entry)
		_add_lobby_row(entry)

	if lobby_list.is_empty():
		status_label.text = "Tous les lobbies sont pleins."


# ── Création des lignes UI ───────────────────────────────────────────────────

func _add_lobby_row(entry: Dictionary):
	var row = lobby_row_scene.instantiate()
	# L'interface du row est définie à l'Étape 3
	row.setup(entry, _on_join_pressed)
	lobby_container.add_child(row)


func _clear_rows():
	for child in lobby_container.get_children():
		child.queue_free()


# ── Rejoindre depuis le navigateur ──────────────────────────────────────────

func _on_join_pressed(lobby_id: int):
	status_label.text = "Connexion au lobby %d…" % lobby_id
	# Délègue à ton gestionnaire principal
	get_parent().join_lobby(lobby_id)
