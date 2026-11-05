extends Node3D
## Mundo procedural em chunks. Recursos coletados são persistidos por ID e nunca renascem.

const CHUNK_SIZE := 64.0
const VIEW_RADIUS := 2
const SAVE_PATH := "user://ilha_viva_world_v2.json"
const DAY_LENGTH := 1200.0
const DAYS_PER_SEASON := 7
const SEASONS := ["Primavera", "Verão", "Outono", "Inverno"]
const WEATHER := ["Limpo", "Nublado", "Chuva", "Neblina", "Tempestade"]

var player: Node3D
var resources: Array[Node3D] = []
var chunks: Dictionary = {}
var harvested: Dictionary = {}
var world_seconds := 0.0
var weather_name := "Limpo"
var weather_timer := 0.0
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var rain: GPUParticles3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_load_state()
	_build_sky_and_weather()

func set_player(value: Node3D) -> void:
	player = value
	update_chunks(player.global_position)

func tick(delta: float, focus: Vector3) -> void:
	world_seconds += delta
	weather_timer += delta
	if weather_timer >= 100.0:
		weather_timer = 0.0
		_change_weather()
	_update_sun()
	_update_weather_visuals(focus)
	update_chunks(focus)
	if int(world_seconds) % 30 == 0:
		_save_state()

func update_chunks(focus: Vector3) -> void:
	var center := Vector2i(floori(focus.x / CHUNK_SIZE), floori(focus.z / CHUNK_SIZE))
	var wanted: Dictionary = {}
	for x in range(center.x - VIEW_RADIUS, center.x + VIEW_RADIUS + 1):
		for z in range(center.y - VIEW_RADIUS, center.y + VIEW_RADIUS + 1):
			var key := _chunk_key(x, z)
			wanted[key] = true
			if not chunks.has(key):
				chunks[key] = _create_chunk(x, z)
	var remove_keys: Array = []
	for key in chunks.keys():
		if not wanted.has(key):
			remove_keys.append(key)
	for key in remove_keys:
		var node: Node3D = chunks[key]
		if is_instance_valid(node):
			node.queue_free()
		chunks.erase(key)

func _create_chunk(cx: int, cz: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [cx, cz]
	root.position = Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE)
	add_child(root)

	var ground := StaticBody3D.new()
	ground.position = Vector3(CHUNK_SIZE * 0.5, -0.55, CHUNK_SIZE * 0.5)
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CHUNK_SIZE, 1.0, CHUNK_SIZE)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	ground_mesh.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.24, 0.39, 0.22)
	ground_mat.roughness = 1.0
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	root.add_child(ground)

	var chunk_rng := RandomNumberGenerator.new()
	chunk_rng.seed = abs(hash(Vector2i(cx, cz))) + 7331
	for i in range(22):
		var local_x := chunk_rng.randf_range(3.0, CHUNK_SIZE - 3.0)
		var local_z := chunk_rng.randf_range(3.0, CHUNK_SIZE - 3.0)
		var world_pos := root.position + Vector3(local_x, 0, local_z)
		var kind := ["wood", "stone", "food"][chunk_rng.randi_range(0, 2)]
		var id := "%s:%d:%d:%d" % [kind, cx, cz, i]
		if harvested.has(id):
			continue
		var item := _create_resource(kind, id, world_pos)
		root.add_child(item)
		resources.append(item)
	return root

func _create_resource(kind: String, id: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = id.replace(":", "_")
	root.set_meta("resource_id", id)
	root.position = pos
	if kind == "wood":
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.22
		trunk_mesh.bottom_radius = 0.34
		trunk_mesh.height = 2.2
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.1
		trunk.material_override = _material(Color(0.34, 0.21, 0.12))
		root.add_child(trunk)
		var crown := MeshInstance3D.new()
		var crown_mesh := ConeMesh.new()
		crown_mesh.radius = 1.35
		crown_mesh.height = 2.8
		crown.mesh = crown_mesh
		crown.position.y = 3.0
		crown.material_override = _material(Color(0.12, 0.31, 0.13))
		root.add_child(crown)
		root.add_to_group("wood_node")
	elif kind == "stone":
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.72
		rock_mesh.height = 1.0
		rock_mesh.radial_segments = 7
		rock.mesh = rock_mesh
		rock.position.y = 0.45
		rock.material_override = _material(Color(0.42, 0.44, 0.46))
		root.add_child(rock)
		root.add_to_group("stone_node")
	else:
		var plant := MeshInstance3D.new()
		var plant_mesh := SphereMesh.new()
		plant_mesh.radius = 0.38
		plant_mesh.height = 0.65
		plant.mesh = plant_mesh
		plant.position.y = 0.35
		plant.material_override = _material(Color(0.58, 0.22, 0.18))
		root.add_child(plant)
		root.add_to_group("food_node")
	return root

func harvest(item: Node3D) -> void:
	if not is_instance_valid(item):
		return
	var id := str(item.get_meta("resource_id", ""))
	if not id.is_empty():
		harvested[id] = true
	resources.erase(item)
	item.queue_free()
	_save_state()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat

func _build_sky_and_weather() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 1.1
	add_child(sun)

	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.79, 0.88)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_density = 0.001
	world_env.environment = env
	add_child(world_env)

	rain = GPUParticles3D.new()
	rain.name = "RainParticles"
	rain.amount = 450
	rain.lifetime = 1.4
	rain.emitting = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, -1, 0)
	process.initial_velocity_min = 13.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3(0, -9.8, 0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(18, 7, 18)
	rain.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.22)
	drop.material = _material(Color(0.68, 0.79, 0.92, 0.7))
	rain.draw_pass_1 = drop
	add_child(rain)

func _change_weather() -> void:
	var season := _season_index()
	var choices := WEATHER.duplicate()
	if season == 1:
		choices = ["Limpo", "Limpo", "Nublado", "Chuva", "Tempestade"]
	elif season == 3:
		choices = ["Nublado", "Neblina", "Neblina", "Chuva", "Tempestade"]
	weather_name = choices[rng.randi_range(0, choices.size() - 1)]

func _update_sun() -> void:
	var day_progress := fposmod(world_seconds, DAY_LENGTH) / DAY_LENGTH
	sun.rotation_degrees.x = -90.0 + day_progress * 360.0
	var daylight := clampf(sin(day_progress * TAU) * 1.5 + 0.25, 0.08, 1.0)
	sun.light_energy = daylight
	var env := world_env.environment
	env.ambient_light_energy = 0.22 + daylight * 0.55

func _update_weather_visuals(focus: Vector3) -> void:
	rain.global_position = focus + Vector3(0, 9, 0)
	rain.emitting = weather_name == "Chuva" or weather_name == "Tempestade"
	var env := world_env.environment
	env.fog_density = 0.004 if weather_name == "Neblina" else (0.0025 if weather_name == "Tempestade" else 0.001)
	if weather_name == "Tempestade":
		sun.light_energy *= 0.55

func get_season() -> String:
	return SEASONS[_season_index()]

func get_day_number() -> int:
	return int(world_seconds / DAY_LENGTH) + 1

func get_time_text() -> String:
	var day_progress := fposmod(world_seconds, DAY_LENGTH) / DAY_LENGTH
	var minutes := int(day_progress * 1440.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

func _season_index() -> int:
	return (int(world_seconds / DAY_LENGTH) / DAYS_PER_SEASON) % SEASONS.size()

func _chunk_key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"world_seconds": world_seconds, "harvested": harvested.keys()}))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		world_seconds = float(data.get("world_seconds", 0.0))
		for id in data.get("harvested", []):
			harvested[str(id)] = true
