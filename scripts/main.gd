extends Node3D

const PLAYER_SPEED := 6.0
const NEEDS_INTERVAL := 8.0
var hunger := 100.0
var thirst := 100.0
var energy := 100.0
var wood := 0
var stone := 0
var berries := 0
var elapsed := 0.0
var player: CharacterBody3D
var hud: Label
var status: Label
var message: Label
var joystick := Vector2.ZERO
var peer := ENetMultiplayerPeer.new()
var remote_players := {}

func _ready() -> void:
	_build_world()
	_build_player()
	_build_ui()
	_setup_multiplayer()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= NEEDS_INTERVAL:
		elapsed = 0.0
		hunger = maxf(0.0, hunger - 1.0)
		thirst = maxf(0.0, thirst - 1.6)
		energy = minf(100.0, energy + 0.4)
	_update_hud()
	_update_daylight()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var axis := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if joystick.length() > 0.12:
		axis = joystick
	axis = axis.limit_length(1.0)
	var direction := Vector3(axis.x, 0.0, axis.y)
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * get_physics_process_delta_time()
	else:
		player.velocity.y = -0.5
	player.move_and_slide()
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_broadcast_positions()

func _build_world() -> void:
	var ground := _make_box(Vector3(0, -0.6, 0), Vector3(100, 1, 100), Color(0.28, 0.52, 0.27))
	ground.name = "IslandGround"
	for i in range(65):
		var x := randf_range(-44, 44)
		var z := randf_range(-44, 44)
		if Vector2(x, z).length() < 7.0:
			continue
		if i % 3 == 0:
			_make_tree(Vector3(x, 0, z))
		else:
			_make_rock(Vector3(x, 0, z))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.82, 0.92)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	add_child(env)

func _make_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	item.material_override = mat
	item.position = pos
	add_child(item)
	return item

func _make_tree(pos: Vector3) -> void:
	_make_box(pos + Vector3(0, 1.4, 0), Vector3(0.55, 2.8, 0.55), Color(0.35, 0.22, 0.12))
	var crown := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.5
	mesh.height = 2.8
	crown.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, randf_range(0.34, 0.24), 0.13)
	crown.material_override = mat
	crown.position = pos + Vector3(0, 3.2, 0)
	add_child(crown)

func _make_rock(pos: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = randf_range(0.45, 0.9)
	mesh.height = 1.0
	rock.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.44, 0.45)
	rock.material_override = mat
	rock.position = pos + Vector3(0, 0.45, 0)
	rock.scale = Vector3(1.3, 0.75, 1.0)
	add_child(rock)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "LocalPlayer"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	player.add_child(shape)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.8
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.48, 0.72)
	body.material_override = mat
	body.position.y = 0.9
	player.add_child(body)
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 11, 13)
	camera.rotation_degrees = Vector3(-38, 0, 0)
	player.add_child(camera)
	camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.size = Vector2(340, 112)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 19)
	column.add_child(hud)
	status = Label.new()
	status.text = "Ilha Viva  •  Sobreviva e explore"
	status.add_theme_font_size_override("font_size", 15)
	column.add_child(status)
	var actions := HBoxContainer.new()
	actions.position = Vector2(16, 140)
	layer.add_child(actions)
	_add_action(actions, "Coletar", _gather)
	_add_action(actions, "Comer", _eat)
	_add_action(actions, "Beber", _drink)
	_add_action(actions, "Abrigo", _build_shelter)
	var net := HBoxContainer.new()
	net.position = Vector2(16, 190)
	layer.add_child(net)
	_add_action(net, "Criar sala", _host_game)
	_add_action(net, "Entrar IP", _join_dialog)
	message = Label.new()
	message.position = Vector2(16, 238)
	message.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(message)
	var stick := TouchScreenButton.new()
	stick.position = Vector2(90, 560)
	stick.action = "move_forward"
	stick.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	layer.add_child(stick)
	_update_hud()

func _add_action(parent: HBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(118, 46)
	button.pressed.connect(callback)
	parent.add_child(button)

func _update_hud() -> void:
	if is_instance_valid(hud):
		hud.text = "Vida 100  |  Fome %d  |  Sede %d  |  Energia %d\nMadeira %d  Pedra %d  Frutas %d" % [int(hunger), int(thirst), int(energy), wood, stone, berries]

func _gather() -> void:
	var roll := randi_range(0, 2)
	if roll == 0:
		wood += 2
		_show_message("+2 madeira coletada")
	elif roll == 1:
		stone += 2
		_show_message("+2 pedras coletadas")
	else:
		berries += 1
		_show_message("+1 fruta coletada")
	_update_hud()

func _eat() -> void:
	if berries <= 0:
		_show_message("Procure frutas para comer.")
		return
	berries -= 1
	hunger = minf(100.0, hunger + 24.0)
	_update_hud()

func _drink() -> void:
	thirst = minf(100.0, thirst + 20.0)
	_show_message("Você bebeu água da cantil inicial.")
	_update_hud()

func _build_shelter() -> void:
	if wood < 5 or stone < 2:
		_show_message("Precisa de 5 madeiras e 2 pedras.")
		return
	wood -= 5
	stone -= 2
	_make_box(player.global_position + Vector3(0, 1, -3), Vector3(4, 2, 0.35), Color(0.42, 0.27, 0.15))
	_make_box(player.global_position + Vector3(0, 2.1, -3), Vector3(4.5, 0.25, 4), Color(0.3, 0.2, 0.12))
	_show_message("Abrigo construído!")
	_update_hud()

func _show_message(value: String) -> void:
	if is_instance_valid(message):
		message.text = value

func _update_daylight() -> void:
	var light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.rotation_degrees.x = -25.0 - sin(Time.get_ticks_msec() / 45000.0) * 35.0

func _setup_multiplayer() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _host_game() -> void:
	var error := peer.create_server(24517, 8)
	if error != OK:
		_show_message("Não foi possível criar a sala: %s" % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	_show_message("Sala criada. Compartilhe seu IP e a porta 24517.")

func _join_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Entrar em sala"
	var field := LineEdit.new()
	field.placeholder_text = "IP do anfitrião"
	field.custom_minimum_size = Vector2(280, 44)
	dialog.add_child(field)
	dialog.confirmed.connect(func():
		var error := peer.create_client(field.text.strip_edges(), 24517)
		if error == OK:
			multiplayer.multiplayer_peer = peer
			_show_message("Conectando à sala...")
		else:
			_show_message("Endereço inválido.")
	)
	add_child(dialog)
	dialog.popup_centered()

func _on_peer_connected(id: int) -> void:
	_show_message("Jogador %d entrou." % id)
	_rpc_spawn_remote.rpc(id)

func _on_peer_disconnected(id: int) -> void:
	if remote_players.has(id):
		remote_players[id].queue_free()
		remote_players.erase(id)

@rpc("any_peer", "call_local", "reliable")
func _rpc_spawn_remote(id: int) -> void:
	if id == multiplayer.get_unique_id() or remote_players.has(id):
		return
	var avatar := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	avatar.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.65, 0.2)
	avatar.material_override = mat
	avatar.position = Vector3(randf_range(-4, 4), 0.9, randf_range(-4, 4))
	add_child(avatar)
	remote_players[id] = avatar

func _broadcast_positions() -> void:
	for id in multiplayer.get_peers():
		_rpc_remote_position.rpc_id(id, multiplayer.get_unique_id(), player.global_position)

@rpc("any_peer", "unreliable")
func _rpc_remote_position(id: int, pos: Vector3) -> void:
	if remote_players.has(id):
		remote_players[id].global_position = pos
