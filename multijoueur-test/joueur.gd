# joueur.gd
# IMPORTANT : dans ta scène joueur (CharacterBody3D), tu dois ajouter
# un nœud enfant MultiplayerSynchronizer nommé "MultiplayerSynchronizer".
# Configure-le dans l'éditeur avec les propriétés à synchroniser :
#   - position (Vector3)
#   - rotation (Vector3)
#   - velocity (Vector3)  [optionnel, pour interpolation]
# Mets "Replication Mode" sur "Always" ou "On Change".
# L'autorité (root_path) doit pointer sur le CharacterBody3D parent.

extends CharacterBody3D

@export var walk_speed : float = 5.0
@export var sprint_speed : float = 10.0
@export var jump_velocity : float = 4.5
@export var mouse_sensitivity : float = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var camera_pivot : Node3D
@export var camera : Camera3D

func _ready():
	print("joueur _ready | name=", name, " | is_authority=", is_multiplayer_authority())
	# CORRECTION BUG #4 : mouse capture uniquement pour le joueur local
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.current = true
	else:
		# Désactiver la caméra des autres joueurs pour éviter les conflits
		camera.current = false

func _input(event):
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x,
			deg_to_rad(-90),
			deg_to_rad(90)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta):
	# CORRECTION BUG #5 : le mouvement n'est calculé que par l'autorité locale.
	# Le MultiplayerSynchronizer (configuré dans la scène) se charge de
	# répliquer position/rotation vers tous les autres peers.
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	var input_dir = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var direction = (transform.basis * Vector3(
		input_dir.x,
		0,
		input_dir.y
	)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()