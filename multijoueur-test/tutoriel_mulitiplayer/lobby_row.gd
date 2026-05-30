# lobby_row.gd
extends Control

@export var lobby_name_label:    Label  
@export var lobby_players_label: Label  
@export var join_button:         Button 

var _lobby_id: int
var _join_callback: Callable

func setup(entry: Dictionary, join_callback: Callable):
    _lobby_id      = entry.id
    _join_callback = join_callback

    lobby_name_label.text    = entry.name if entry.name != "" else "Lobby #%d" % entry.id
    lobby_players_label.text = "%d / %d" % [entry.players, entry.max_players]
    join_button.pressed.connect(_on_join_pressed)

func _on_join_pressed():
    # ✅ Utilise le callback propre au lieu du chemin de nœuds fragile
    _join_callback.call(_lobby_id)