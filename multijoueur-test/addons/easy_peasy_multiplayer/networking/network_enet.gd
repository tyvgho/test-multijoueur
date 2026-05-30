class_name NetworkEnet
extends Node

## The port number to use for Enet servers
const DEFAULT_PORT = 7000

## The [MultiplayerPeer] for the Enet server. We can define this on initialization because this script should only run if we are going to be networking using ENet
var peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()

#region Network-Specific Functions
## Creates a game server as the host. See [Network.become_host] for more information
func become_host(connection_info : Dictionary = { "port" : DEFAULT_PORT }):
	var error = peer.create_server(connection_info.port, Network.room_size)
	if error:
		if Network._is_verbose:
			print("Error creating host: %s" % error_string(error))
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = peer

	Network.is_host = true
	Network.connected_players[1] = Network.player_info
	Network.server_started.emit()
	Network.player_connected.emit(1, Network.player_info)
	if Network._is_verbose:
		print("ENet Server hosted on port %d" % connection_info.port)

## Joins a game using an id in [Network]. See [Network.join_as_client] for more information
func join_as_client():
	var ip = Network.ip_address
	var port = DEFAULT_PORT

	# Check if the ip_address contains a port (e.g., "192.168.1.1:8080")
	# This snippet was written by https://github.com/SimonMcCallum. Thank you for forking my plugin, your project is so cool!
	if ":" in ip:
		var parts = ip.split(":")
		ip = parts[0]
		port = int(parts[1])

	var error = peer.create_client(ip, port)
	if error:
		if Network._is_verbose:
			print("ENet client failed to connect to server %s:%d with error: %s" % [ip, port, error_string(error)])
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = peer
	Network.is_host = false

	if Network._is_verbose:
		print("ENet client connecting to %s:%d" % [ip, port])

## This does nothing as Enet does not have a lobby implementation. It is only here to prevent errors.
func list_lobbies():
	pass
#endregion
