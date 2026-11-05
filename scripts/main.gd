extends Node3D

# Ilha Viva — protótipo survival mobile. O servidor dedicado é a autoridade da sessão.
const PORT := 24517
const MAX_PLAYERS := 24
const NEED_TICK := 10.0
const SAVE_PATH := "user://ilha_viva_world.json"
var peer := ENetMultiplayerPeer.new()
var player: CharacterBody3D
var camera: Camera3D
var camera_pivot: Node3D
var world_manager: Node
var joystick := Vector2.ZERO
var virtual_stick: Control
var hud: Label
var notice: Label
var hunger := 100.0
var thirst := 100.0
var health := 100.0
var stamina := 100.0
var wood := 0
var stone := 0
var food := 0
var cloth := 0
var elapsed := 0.0
var day_clock := 0.0
var resources: Array[Node3D] = []
var zombies: Array[CharacterBody3D] = []
var remote_players: Dictionary = {}
var remote_positions: Dictionary = {}
var guild_name := ""
var guild_members: Array[String] = []
var world_data := {"guilds": {}, "bases": []}
var server_mode := false
var last_attack := 0.0
var network_send_timer := 0.0

func _ready() -> void:
	server_mode = OS.get_cmdline_user_args().has("--server")
	_load_world()
	_build_world()
	if server_mode:
		_setup_network_signals()
	if server_mode:
		_start_dedicated_server()
		return
	_build_player()
	world_manager.call("set_player", player)
	_build_ui()
	_setup_network_signals()
	_update_hud()

func _process(delta: float) -> void:
	day_clock = fmod(day_clock + delta, 600.0)
	elapsed += delta
	if elapsed >= NEED_TICK:
		elapsed = 0.0
		hunger = maxf(0.0, hunger - 1.2)
		thirst = maxf(0.0, thirst - 1.8)
		stamina = minf(100.0, stamina + 3.0)
		if hunger <= 0.0 or thirst <= 0.0:
			health = maxf(0.0, health - 2.0)
		_update_hud()
	if is_instance_valid(world_manager):
		var focus := player.global_position if is_instance_valid(player) else Vector3.ZERO
		world_manager.call("tick", delta, focus)
		resources.clear()
		for item in world_manager.get("resources"):
			resources.append(item)
	if not server_mode:
		network_send_timer += delta
		if network_send_timer >= 0.05:
			network_send_timer = 0.0
			_sync_my_position()

func _physics_process(delta: float) -> void:
	if server_mode:
		_server_zombie_tick(delta)
		return
	if not is_instance_valid(player):
		return
	var axis := Vector2(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"), Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
	if joystick.length() > 0.12:
		axis = joystick
	axis = axis.limit_length(1.0)
	var direction := camera_pivot.global_basis * Vector3(axis.x, 0.0, axis.y)
	direction.y = 0.0
	direction = direction.normalized()
	player.velocity.x = direction.x * 5.5
	player.velocity.z = direction.z * 5.5
	if direction.length() > 0.08:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = -0.5
	player.move_and_slide()
	_tick_local_zombies(delta)

func _build_world() -> void:
	world_manager = Node.new()
	world_manager.name = "WorldManager"
	world_manager.set_script(load("res://scripts/world_manager.gd"))
	add_child(world_manager)
	for i in range(12):
		_spawn_zombie(Vector3(randf_range(-48, 48), 0.1, randf_range(-48, 48)))

func _make_box(pos: Vector3, size: Vector3, color: Color, collision := false) -> Node3D:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		root.add_child(cs)
	else:
		root = Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	root.position = pos
	add_child(root)
	return root

func _make_tree(pos: Vector3) -> void:
	var trunk := _make_box(pos + Vector3(0, 1.2, 0), Vector3(0.5, 2.4, 0.5), Color(0.32, 0.19, 0.1), true)
	trunk.add_to_group("wood_node")
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.45
	sphere.height = 2.7
	crown.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.32, 0.13)
	crown.material_override = mat
	crown.position = pos + Vector3(0, 3.0, 0)
	add_child(crown)
	resources.append(trunk)

func _make_rock(pos: Vector3) -> void:
	var rock := _make_box(pos + Vector3(0, 0.45, 0), Vector3(1.25, 0.9, 1.1), Color(0.4, 0.42, 0.43), true)
	rock.add_to_group("stone_node")
	resources.append(rock)

func _make_food_plant(pos: Vector3) -> void:
	var plant := _make_box(pos + Vector3(0, 0.35, 0), Vector3(0.5, 0.7, 0.5), Color(0.48, 0.18, 0.16), false)
	plant.add_to_group("food_node")
	resources.append(plant)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)

	var skin := _lowpoly_material(Color(0.78, 0.59, 0.43))
	var shirt := _lowpoly_material(Color(0.24, 0.38, 0.27))
	var pants := _lowpoly_material(Color(0.25, 0.29, 0.34))
	var boots := _lowpoly_material(Color(0.16, 0.14, 0.12))
	var hair := _lowpoly_material(Color(0.19, 0.15, 0.12))
	_add_player_box("Torso", Vector3(0, 1.08, 0), Vector3(0.62, 0.72, 0.34), shirt)
	_add_player_box("Pelvis", Vector3(0, 0.68, 0), Vector3(0.48, 0.25, 0.3), pants)
	_add_player_box("LeftLeg", Vector3(-0.16, 0.34, 0), Vector3(0.22, 0.52, 0.25), pants)
	_add_player_box("RightLeg", Vector3(0.16, 0.34, 0), Vector3(0.22, 0.52, 0.25), pants)
	_add_player_box("LeftBoot", Vector3(-0.16, 0.09, -0.045), Vector3(0.25, 0.16, 0.36), boots)
	_add_player_box("RightBoot", Vector3(0.16, 0.09, -0.045), Vector3(0.25, 0.16, 0.36), boots)
	_add_player_box("LeftArm", Vector3(-0.43, 1.08, 0), Vector3(0.2, 0.65, 0.25), shirt)
	_add_player_box("RightArm", Vector3(0.43, 1.08, 0), Vector3(0.2, 0.65, 0.25), shirt)
	_add_player_box("LeftHand", Vector3(-0.43, 0.69, 0), Vector3(0.17, 0.16, 0.18), skin)
	_add_player_box("RightHand", Vector3(0.43, 0.69, 0), Vector3(0.17, 0.16, 0.18), skin)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head_mesh.radial_segments = 7
	head_mesh.rings = 4
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0, 1.66, 0)
	player.add_child(head)
	_add_player_box("Hair", Vector3(0, 1.84, 0.015), Vector3(0.34, 0.1, 0.32), hair)

	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	camera_pivot = Node3D.new()
	camera_pivot.name = "ThirdPersonCameraPivot"
	camera_pivot.position = Vector3(0, 1.45, 0)
	player.add_child(camera_pivot)
	var arm := SpringArm3D.new()
	arm.spring_length = 5.5
	arm.margin = 0.2
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	arm.add_child(camera)
	camera.current = true
	camera_pivot.rotation_degrees.x = -12.0

func _lowpoly_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat

func _add_player_box(part_name: String, local_pos: Vector3, part_size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.material_override = material
	part.position = local_pos
	player.add_child(part)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 10)
	panel.size = Vector2(440, 104)
	layer.add_child(panel)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 17)
	panel.add_child(hud)
	var actions := HBoxContainer.new()
	actions.position = Vector2(12, 124)
	layer.add_child(actions)
	_add_button(actions, "Coletar", _gather)
	_add_button(actions, "Comer", _eat)
	_add_button(actions, "Beber", _drink)
	_add_button(actions, "Craft", _craft)
	var actions2 := HBoxContainer.new()
	actions2.position = Vector2(12, 176)
	layer.add_child(actions2)
	_add_button(actions2, "Construir", _build_base_piece)
	_add_button(actions2, "Ataque", _attack)
	_add_button(actions2, "Guilda", _guild_dialog)
	_add_button(actions2, "Criar sala", _host_game)
	_add_button(actions2, "Entrar", _join_dialog)
	notice = Label.new()
	notice.position = Vector2(14, 232)
	notice.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(notice)
	virtual_stick = Control.new()
	virtual_stick.set_script(load("res://scripts/virtual_stick.gd"))
	virtual_stick.anchor_left = 0
	virtual_stick.anchor_top = 1
	virtual_stick.anchor_right = 0
	virtual_stick.anchor_bottom = 1
	virtual_stick.offset_left = 20
	virtual_stick.offset_top = -220
	virtual_stick.offset_right = 220
	virtual_stick.offset_bottom = -20
	virtual_stick.custom_minimum_size = Vector2(200, 200)
	layer.add_child(virtual_stick)
	virtual_stick.direction_changed.connect(func(v: Vector2): joystick = v)
	# O joystick virtual aparece apenas em aparelhos com tela touch.
	virtual_stick.visible = OS.has_feature("mobile")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * 0.003
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * 0.003, -0.85, 0.25)
		return
	if event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
		camera_pivot.rotation.y -= event.relative.x * 0.004
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * 0.004, -0.85, 0.25)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	# Atalhos para teclado no PC; os botões da interface continuam funcionando.
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_E:
			_gather()
		KEY_F:
			_eat()
		KEY_G:
			_drink()
		KEY_C:
			_craft()
		KEY_B:
			_build_base_piece()
		KEY_SPACE:
			_attack()

func _add_button(parent: HBoxContainer, caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(104, 44)
	b.pressed.connect(callback)
	parent.add_child(b)

func _update_hud() -> void:
	if is_instance_valid(hud):
		var climate := ""
		if is_instance_valid(world_manager):
			climate = "\nDia %d • %s • %s • %s" % [world_manager.call("get_day_number"), world_manager.call("get_season"), world_manager.call("get_time_text"), world_manager.get("weather_name")]
		hud.text = "VIDA %d  FOME %d  SEDE %d  ENERGIA %d\nMadeira %d | Pedra %d | Comida %d | Tecido %d%s" % [int(health), int(hunger), int(thirst), int(stamina), wood, stone, food, cloth, climate]

func _gather() -> void:
	if not is_instance_valid(player):
		return
	var nearest: Node3D
	var nearest_distance := 4.0
	for node in resources:
		if not is_instance_valid(node):
			continue
		var d := player.global_position.distance_to(node.global_position)
		if d < nearest_distance:
			nearest = node
			nearest_distance = d
	if nearest == null:
		_show("Chegue mais perto de uma árvore, pedra ou planta.")
		return
	if nearest.is_in_group("wood_node"):
		wood += 3
		_emit_noise(player.global_position, 26.0)
		_show("+3 madeira")
	elif nearest.is_in_group("stone_node"):
		stone += 2
		_emit_noise(player.global_position, 18.0)
		_show("+2 pedras")
	elif nearest.is_in_group("food_node"):
		food += 2
		_show("+2 alimentos")
	if is_instance_valid(world_manager):
		world_manager.call("harvest", nearest)
	else:
		resources.erase(nearest)
		nearest.queue_free()
	_update_hud()

func _eat() -> void:
	if food <= 0:
		_show("Você não tem comida. Colete plantas pelo mapa.")
		return
	food -= 1
	hunger = minf(100, hunger + 28)
	_update_hud()

func _drink() -> void:
	thirst = minf(100, thirst + 24)
	_show("Você bebeu água do cantil.")
	_update_hud()

func _craft() -> void:
	if wood >= 2 and stone >= 1:
		wood -= 2
		stone -= 1
		cloth += 1
		stamina = minf(100, stamina + 10)
		_show("Craft concluído: 1 kit de reparo (tecido).")
	else:
		_show("Receita: 2 madeiras + 1 pedra = 1 kit de reparo.")
	_update_hud()

func _build_base_piece() -> void:
	if wood < 5 or stone < 2:
		_show("Parede: precisa de 5 madeiras e 2 pedras.")
		return
	wood -= 5
	stone -= 2
	_emit_noise(player.global_position, 34.0)
	var pos := player.global_position + Vector3(0, 1.0, -3.0)
	var piece := _make_box(pos, Vector3(4, 2, 0.3), Color(0.36, 0.24, 0.14), true)
	piece.add_to_group("player_base")
	world_data["bases"].append({"x": pos.x, "y": pos.y, "z": pos.z})
	_save_world()
	_show("Parede da base construída!")
	_update_hud()

func _attack() -> void:
	if Time.get_ticks_msec() / 1000.0 - last_attack < 0.65:
		return
	last_attack = Time.get_ticks_msec() / 1000.0
	var target: CharacterBody3D
	var closest := 3.0
	for z in zombies:
		if is_instance_valid(z):
			var d := player.global_position.distance_to(z.global_position)
			if d < closest:
				closest = d
				target = z
	if target:
		target.queue_free()
		zombies.erase(target)
		_show("Zumbi derrotado! (combate arcade)")
	else:
		_show("Nenhum zumbi por perto.")
	# O PvP multiplayer será validado pelo servidor dedicado; não confiar em dano calculado no cliente.

func _spawn_zombie(pos: Vector3) -> void:
	var z := CharacterBody3D.new()
	z.name = "Zombie"
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.55
	shape.shape = cap
	shape.position.y = 0.78
	z.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.55
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.48, 0.25)
	visual.material_override = mat
	visual.position.y = 0.78
	z.add_child(visual)
	z.position = pos
	add_child(z)
	zombies.append(z)

func _tick_local_zombies(delta: float) -> void:
	for z in zombies:
		if not is_instance_valid(z):
			continue
		var target_position := player.global_position
		var investigate_left := float(z.get_meta("investigate_left", 0.0))
		if investigate_left > 0.0:
			investigate_left -= delta
			z.set_meta("investigate_left", investigate_left)
			target_position = z.get_meta("heard_position", player.global_position)
		var offset := target_position - z.global_position
		var player_distance := player.global_position.distance_to(z.global_position)
		if investigate_left > 0.0 or player_distance < 18.0:
			var dir := offset.normalized()
			z.velocity.x = dir.x * 2.0
			z.velocity.z = dir.z * 2.0
			if not z.is_on_floor():
				z.velocity.y -= 20.0 * delta
			else:
				z.velocity.y = -0.4
			z.move_and_slide()
			if player_distance < 1.25:
				health = maxf(0, health - 8.0 * delta)
	_update_hud()

func _server_zombie_tick(delta: float) -> void:
	if remote_positions.is_empty():
		return
	for z in zombies:
		if not is_instance_valid(z):
			continue
		var nearest_position := Vector3.ZERO
		var nearest_distance := INF
		for pos in remote_positions.values():
			var distance := z.global_position.distance_to(pos)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_position = pos
		if nearest_distance < 22.0:
			var direction := nearest_position - z.global_position
			direction.y = 0.0
			direction = direction.normalized()
			z.velocity.x = direction.x * 2.0
			z.velocity.z = direction.z * 2.0
			z.velocity.y = -0.5 if z.is_on_floor() else z.velocity.y - 20.0 * delta
			z.move_and_slide()

func _emit_noise(origin: Vector3, radius: float) -> void:
	for z in zombies:
		if not is_instance_valid(z):
			continue
		if z.global_position.distance_to(origin) <= radius:
			z.set_meta("heard_position", origin)
			z.set_meta("investigate_left", 9.0)

func _show(text_value: String) -> void:
	if is_instance_valid(notice):
		notice.text = text_value

func _update_daylight() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.rotation_degrees.x = -20.0 - sin(day_clock / 600.0 * TAU) * 35.0

func _setup_network_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _start_dedicated_server() -> void:
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("Falha ao iniciar servidor ENet: " + error_string(err))
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = peer
	print("ILHA VIVA SERVER ONLINE port=", PORT, " max_players=", MAX_PLAYERS)

func _host_game() -> void:
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		_show("Não foi possível abrir sala: " + error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	_show("Sala local aberta. Para 24h, use um servidor dedicado hospedado.")

func _join_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Conectar ao servidor"
	var field := LineEdit.new()
	field.placeholder_text = "IP ou domínio do servidor"
	field.custom_minimum_size = Vector2(300, 46)
	dialog.add_child(field)
	dialog.confirmed.connect(func():
		var client := ENetMultiplayerPeer.new()
		var err := client.create_client(field.text.strip_edges(), PORT)
		if err == OK:
			multiplayer.multiplayer_peer = client
			_show("Conectando...")
		else:
			_show("Endereço inválido.")
	)
	add_child(dialog)
	dialog.popup_centered()

func _on_peer_connected(id: int) -> void:
	print("Player connected: ", id)
	for existing_id in remote_positions.keys():
		rpc_id(id, "_rpc_remote_position", int(existing_id), remote_positions[existing_id])
	if not server_mode:
		_show("Jogador conectado: %d" % id)

func _on_peer_disconnected(id: int) -> void:
	if remote_players.has(id):
		remote_players[id].queue_free()
		remote_players.erase(id)
	remote_positions.erase(id)

func _sync_my_position() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer or not is_instance_valid(player):
		return
	var my_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		remote_positions[my_id] = player.global_position
		_ensure_remote_player(my_id, player.global_position)
		rpc("_rpc_remote_position", my_id, player.global_position)
	else:
		_rpc_position.rpc_id(1, player.global_position)

@rpc("any_peer", "unreliable")
func _rpc_position(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if remote_positions.has(id) and (remote_positions[id] as Vector3).distance_to(pos) > 18.0:
		return
	remote_positions[id] = pos
	_ensure_remote_player(id, pos)
	rpc("_rpc_remote_position", id, pos)

@rpc("authority", "call_remote", "unreliable")
func _rpc_remote_position(id: int, pos: Vector3) -> void:
	if id == multiplayer.get_unique_id():
		return
	_ensure_remote_player(id, pos)

func _ensure_remote_player(id: int, pos: Vector3) -> void:
	if not server_mode and id == multiplayer.get_unique_id():
		return
	if not remote_players.has(id):
		var avatar := Node3D.new()
		avatar.name = "RemotePlayer_%d" % id
		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.34
		body_mesh.height = 1.75
		body.mesh = body_mesh
		body.material_override = _lowpoly_material(Color(0.68, 0.74, 0.78))
		body.position.y = 0.88
		avatar.add_child(body)
		add_child(avatar)
		remote_players[id] = avatar
	remote_players[id].global_position = pos

func _guild_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Criar ou entrar em guilda"
	var field := LineEdit.new()
	field.placeholder_text = "Nome da guilda"
	field.custom_minimum_size = Vector2(280, 44)
	dialog.add_child(field)
	dialog.confirmed.connect(func():
		var value := field.text.strip_edges()
		if value.is_empty():
			return
		guild_name = value
		if not world_data["guilds"].has(value):
			world_data["guilds"][value] = []
		if not world_data["guilds"][value].has("Você"):
			world_data["guilds"][value].append("Você")
		guild_members = world_data["guilds"][value]
		_save_world()
		_show("Guilda: " + guild_name)
	)
	add_child(dialog)
	dialog.popup_centered()

func _load_world() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			world_data = parsed
			if not world_data.has("guilds"):
				world_data["guilds"] = {}
			if not world_data.has("bases"):
				world_data["bases"] = []

func _save_world() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(world_data))
