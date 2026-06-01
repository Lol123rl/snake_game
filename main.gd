extends Node3D

# ============================================================
# CUBE SNAKE: FACE WARS
# one file game
# ============================================================


# -----------------------------
# BASIC SETTINGS
# -----------------------------

const FACE_SIZE: int = 10
const CELL_SIZE: float = 2.4
const VISUAL_SPEED: float = 10.0
const WIN_SCORE: int = 100

const FACE_HOME: int = 0
const FACE_SNOW: int = 1
const FACE_BEACH: int = 2
const FACE_LAVA: int = 3
const FACE_FOREST: int = 4
const FACE_SPACE: int = 5

const POWER_NONE: int = 0
const POWER_SHIELD: int = 1
const POWER_GHOST: int = 2
const POWER_BOOST: int = 3
const POWER_BOMB: int = 4

enum GameState {
	TITLE,
	PLAYING,
	LOST,
	WON
}


# -----------------------------
# SNAKE DATA
# -----------------------------

class SnakeData:
	var name: String = ""
	var face: int = 0
	var home_face: int = 0
	var pos: Vector2i = Vector2i.ZERO
	var dir: Vector2i = Vector2i.RIGHT
	var next_dir: Vector2i = Vector2i.RIGHT
	var length: int = 5
	var score: int = 0
	var alive: bool = true
	var is_player: bool = false
	var is_boss: bool = false
	var boss_lives: int = 0
	var color: Color = Color.WHITE
	var trail: Array[String] = []
	var nodes: Array[Node3D] = []
	var targets: Array[Vector3] = []


class StepResult:
	var face: int = 0
	var pos: Vector2i = Vector2i.ZERO
	var dir: Vector2i = Vector2i.RIGHT


# -----------------------------
# GAME VARIABLES
# -----------------------------

var game_state: GameState = GameState.TITLE

var current_level: int = 1
var unlocked_level: int = 1
var level_kills: int = 0
var captured_count: int = 0

var player: SnakeData = SnakeData.new()
var bots: Array[SnakeData] = []

var food_positions: Array[Vector2i] = []
var food_nodes: Array[Node3D] = []

var captured_faces: Array[bool] = []
var face_food_count: Array[int] = []

var powerup_face: int = FACE_HOME
var powerup_pos: Vector2i = Vector2i.ZERO
var powerup_type: int = POWER_NONE
var powerup_node: Node3D = null

var shield_on: bool = false
var ghost_moves: int = 0
var boost_moves: int = 0

var cube_root: Node3D
var camera: Camera3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D
var move_timer: Timer

var ui_layer: CanvasLayer
var title_label: Label
var title_art_label: Label
var small_label: Label
var score_label: Label
var status_label: Label
var task_label: Label
var map_label: Label
var enemy_label: Label

var difficulty_index: int = 1
var music_enabled: bool = true
var m_key_was_down: bool = false
var r_key_was_down: bool = false

var music_player: AudioStreamPlayer
var music_stream: AudioStreamGenerator
var music_playback: AudioStreamGeneratorPlayback
var music_phase: float = 0.0
var bass_phase: float = 0.0
var music_time: float = 0.0
var music_note_index: int = 0

var camera_bump_timer: float = 0.0


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	randomize()
	create_world()
	create_camera()
	create_lights()
	create_music()
	create_timer()
	create_ui()
	show_title()


func _process(delta: float) -> void:
	handle_input()
	update_camera(delta)
	update_snakes(delta)
	update_food(delta)
	update_powerup(delta)
	update_music(delta)


# ============================================================
# WORLD STUFF
# ============================================================

func create_world() -> void:
	world_environment = WorldEnvironment.new()
	add_child(world_environment)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.95, 1.0)
	env.ambient_light_energy = 1.25

	world_environment.environment = env


func create_camera() -> void:
	camera = Camera3D.new()
	add_child(camera)

	camera.current = true
	camera.fov = 58.0
	camera.near = 0.05
	camera.far = 300.0
	camera.position = get_camera_position(FACE_HOME)
	camera.look_at(get_face_center(FACE_HOME), get_camera_up(FACE_HOME))


func create_lights() -> void:
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	sun.light_energy = 3.6
	sun.shadow_enabled = true

	fill_light = DirectionalLight3D.new()
	add_child(fill_light)
	fill_light.rotation_degrees = Vector3(-70.0, 135.0, 0.0)
	fill_light.light_energy = 1.7
	fill_light.shadow_enabled = false


func create_timer() -> void:
	move_timer = Timer.new()
	add_child(move_timer)

	move_timer.wait_time = get_move_speed()
	move_timer.one_shot = false
	move_timer.autostart = false
	move_timer.timeout.connect(_on_move_timer_timeout)


# ============================================================
# MUSIC
# ============================================================

func create_music() -> void:
	music_stream = AudioStreamGenerator.new()
	music_stream.mix_rate = 22050.0
	music_stream.buffer_length = 0.25

	music_player = AudioStreamPlayer.new()
	music_player.stream = music_stream
	add_child(music_player)

	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback


func update_music(_delta: float) -> void:
	if music_player == null:
		return

	if not music_enabled:
		if music_player.playing:
			music_player.stop()
		return

	if not music_player.playing:
		music_player.play()
		music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback

	if music_playback == null:
		return

	var sample_rate: float = 22050.0

	while music_playback.get_frames_available() > 0:
		var melody_frequency: float = get_melody_note(music_note_index)
		var bass_frequency: float = get_bass_note(music_note_index)

		var melody: float = sin(music_phase) * 0.035
		var bass: float = sin(bass_phase) * 0.030
		var drum: float = 0.0

		if music_time < 0.020:
			drum = 0.050

		if game_state == GameState.TITLE:
			melody *= 0.6
			bass *= 0.6
			drum *= 0.3

		var sample: float = melody + bass + drum

		music_phase += TAU * melody_frequency / sample_rate
		bass_phase += TAU * bass_frequency / sample_rate
		music_time += 1.0 / sample_rate

		if music_time >= 0.15:
			music_time = 0.0
			music_note_index += 1

			if music_note_index >= 32:
				music_note_index = 0

		music_playback.push_frame(Vector2(sample, sample))


func get_melody_note(index: int) -> float:
	var notes: Array[float] = [
		220.0, 247.0, 262.0, 294.0,
		330.0, 392.0, 330.0, 294.0,
		262.0, 247.0, 220.0, 196.0,
		220.0, 247.0, 294.0, 330.0,
		392.0, 440.0, 392.0, 330.0,
		294.0, 262.0, 247.0, 220.0,
		196.0, 220.0, 247.0, 262.0,
		294.0, 330.0, 294.0, 247.0
	]

	return notes[index % notes.size()]


func get_bass_note(index: int) -> float:
	var step: int = int(index / 4) % 4

	if step == 0:
		return 110.0
	if step == 1:
		return 98.0
	if step == 2:
		return 131.0

	return 123.0


# ============================================================
# UI
# ============================================================

func create_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	score_label = Label.new()
	score_label.position = Vector2(20.0, 20.0)
	score_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(score_label)

	status_label = Label.new()
	status_label.position = Vector2(20.0, 52.0)
	status_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(status_label)

	task_label = Label.new()
	task_label.position = Vector2(20.0, 80.0)
	task_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(task_label)

	enemy_label = Label.new()
	enemy_label.position = Vector2(20.0, 108.0)
	enemy_label.add_theme_font_size_override("font_size", 17)
	ui_layer.add_child(enemy_label)

	map_label = Label.new()
	map_label.position = Vector2(20.0, 140.0)
	map_label.add_theme_font_size_override("font_size", 17)
	ui_layer.add_child(map_label)

	title_art_label = Label.new()
	title_art_label.position = Vector2(80.0, 80.0)
	title_art_label.add_theme_font_size_override("font_size", 22)
	ui_layer.add_child(title_art_label)

	title_label = Label.new()
	title_label.position = Vector2(80.0, 210.0)
	title_label.add_theme_font_size_override("font_size", 48)
	ui_layer.add_child(title_label)

	small_label = Label.new()
	small_label.position = Vector2(85.0, 280.0)
	small_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(small_label)

	update_ui()


func update_ui() -> void:
	if game_state == GameState.PLAYING:
		score_label.text = "L" + str(current_level) + "  Score " + str(player.score) + "  Kills " + str(level_kills) + "  Captures " + str(captured_count)
		status_label.text = get_short_status()
		task_label.text = "Task: " + get_task_text()
		enemy_label.text = get_enemy_text()
		map_label.text = get_cube_map()
	else:
		score_label.text = ""
		status_label.text = ""
		task_label.text = ""
		enemy_label.text = ""
		map_label.text = ""


func get_task_text() -> String:
	if current_level == 1:
		return "Get 20 points"

	if current_level == 2:
		return "Get 30 points + 1 kill"

	if current_level == 3:
		return "Get 50 points + capture 1 face"

	if current_level == 4:
		return "Get 50 points + 3 kills"

	if current_level == 5:
		return "Get 80 points OR capture 3 faces"

	return "Beat boss OR get 100 points"


func get_enemy_text() -> String:
	var text: String = "Enemies: "

	var any_alive: bool = false

	for bot: SnakeData in bots:
		if bot.alive:
			any_alive = true

			if bot.is_boss:
				text += bot.name + "(" + str(bot.boss_lives) + " lives) "
			else:
				text += bot.name + " "

	if not any_alive:
		text += "none"

	return text


func get_short_status() -> String:
	var text: String = get_face_name(player.face)

	if shield_on:
		text += " | Shield"
	if ghost_moves > 0:
		text += " | Ghost " + str(ghost_moves)
	if boost_moves > 0:
		text += " | Boost " + str(boost_moves)

	return text


func get_cube_map() -> String:
	var snow: String = tag_face(FACE_SNOW, "SNOW")
	var beach: String = tag_face(FACE_BEACH, "BEACH")
	var home: String = tag_face(FACE_HOME, "HOME")
	var lava: String = tag_face(FACE_LAVA, "LAVA")
	var space: String = tag_face(FACE_SPACE, "SPACE")
	var forest: String = tag_face(FACE_FOREST, "FOREST")

	return "        " + snow + "\n" + beach + " " + home + " " + lava + " " + space + "\n        " + forest


func tag_face(face: int, name_text: String) -> String:
	var text: String = name_text

	if captured_faces.size() > face and captured_faces[face]:
		text = "*" + text

	if player.face == face:
		return "[" + text + "]"

	return " " + text + " "


func show_title() -> void:
	game_state = GameState.TITLE
	move_timer.stop()

	clear_game_objects()
	build_cube()

	title_art_label.visible = true
	title_label.visible = true
	small_label.visible = true

	title_art_label.text = "        _______\n     __/______/|\n    /______/ / |\n    |      | | |\n    | FACE | | /\n    |______|_|/"
	title_label.text = "CUBE SNAKE"
	small_label.text = "Enter: Start   Arrows: Level/Difficulty   M: Music\nLevel " + str(current_level) + "/" + str(unlocked_level) + "   " + get_difficulty_name() + "\n" + get_task_text()

	update_ui()


func show_lost(reason: String) -> void:
	game_state = GameState.LOST
	move_timer.stop()

	title_art_label.visible = false
	title_label.visible = true
	small_label.visible = true

	title_label.text = "YOU LOST"
	small_label.text = reason + "\nEnter: Retry   R: Title"


func show_won(reason: String) -> void:
	game_state = GameState.WON
	move_timer.stop()

	title_art_label.visible = false
	title_label.visible = true
	small_label.visible = true

	title_label.text = "LEVEL CLEAR"
	small_label.text = reason + "\nEnter: Next   R: Replay"


func get_difficulty_name() -> String:
	if difficulty_index == 0:
		return "Easy"
	if difficulty_index == 1:
		return "Normal"

	return "Fast"


func get_move_speed() -> float:
	var speed: float = 0.20

	if difficulty_index == 0:
		speed = 0.26
	elif difficulty_index == 2:
		speed = 0.15

	if boost_moves > 0:
		speed *= 0.70

	if player.face == FACE_BEACH:
		speed *= 1.15

	return speed


# ============================================================
# START LEVEL
# ============================================================

func start_game() -> void:
	game_state = GameState.PLAYING

	title_art_label.visible = false
	title_label.visible = false
	small_label.visible = false

	clear_game_objects()
	reset_level_data()
	build_cube()

	setup_player()
	setup_bots()
	setup_food()
	spawn_powerup()

	create_snake_nodes(player)

	for bot: SnakeData in bots:
		create_snake_nodes(bot)

	draw_all_food()
	draw_powerup()
	update_ui()

	move_timer.wait_time = get_move_speed()
	move_timer.start()


func reset_level_data() -> void:
	level_kills = 0
	captured_count = 0

	shield_on = false
	ghost_moves = 0
	boost_moves = 0

	captured_faces.clear()
	face_food_count.clear()

	for face: int in range(6):
		captured_faces.append(false)
		face_food_count.append(0)


func setup_player() -> void:
	player = SnakeData.new()
	player.name = "Player"
	player.face = FACE_HOME
	player.home_face = FACE_HOME
	player.pos = Vector2i(4, 5)
	player.dir = Vector2i.RIGHT
	player.next_dir = Vector2i.RIGHT
	player.length = 6
	player.score = 0
	player.alive = true
	player.is_player = true
	player.is_boss = false
	player.color = Color(0.10, 1.00, 0.25)

	for i: int in range(player.length):
		var trail_pos: Vector2i = player.pos - Vector2i(i, 0)
		trail_pos.x = clamp(trail_pos.x, 0, FACE_SIZE - 1)
		player.trail.append(make_key(player.face, trail_pos))


func setup_bots() -> void:
	bots.clear()

	if current_level >= 1:
		add_bot("Snow", FACE_SNOW, Color(0.20, 0.85, 1.00), false)

	if current_level >= 2:
		add_bot("Beach", FACE_BEACH, Color(1.00, 0.82, 0.10), false)

	if current_level >= 3:
		add_bot("Lava", FACE_LAVA, Color(1.00, 0.20, 0.08), false)

	if current_level >= 4:
		add_bot("Forest", FACE_FOREST, Color(0.00, 0.72, 0.25), false)

	if current_level >= 5:
		add_bot("Space", FACE_SPACE, Color(0.75, 0.25, 1.00), false)

	if current_level == 6:
		add_bot("Boss", FACE_SPACE, Color(1.00, 0.10, 0.95), true)


func add_bot(bot_name: String, start_face: int, bot_color: Color, boss: bool) -> void:
	var bot: SnakeData = SnakeData.new()
	bot.name = bot_name
	bot.face = start_face
	bot.home_face = start_face
	bot.pos = Vector2i(5, 5)
	bot.dir = Vector2i.LEFT
	bot.next_dir = Vector2i.LEFT
	bot.score = 0
	bot.alive = true
	bot.is_player = false
	bot.is_boss = boss
	bot.color = bot_color

	if boss:
		bot.length = 14
		bot.boss_lives = 3
	else:
		bot.length = 5

	for i: int in range(bot.length):
		var trail_pos: Vector2i = bot.pos - bot.dir * i
		trail_pos.x = clamp(trail_pos.x, 0, FACE_SIZE - 1)
		trail_pos.y = clamp(trail_pos.y, 0, FACE_SIZE - 1)
		bot.trail.append(make_key(bot.face, trail_pos))

	bots.append(bot)


func setup_food() -> void:
	food_positions.clear()
	food_nodes.clear()

	for face: int in range(6):
		food_positions.append(Vector2i.ZERO)
		food_nodes.append(null)

	for face: int in range(6):
		spawn_food(face)


# ============================================================
# CUBE VISUALS
# ============================================================

func build_cube() -> void:
	if cube_root != null and is_instance_valid(cube_root):
		cube_root.queue_free()

	cube_root = Node3D.new()
	add_child(cube_root)

	for face: int in range(6):
		build_face(face)


func build_face(face: int) -> void:
	for y: int in range(FACE_SIZE):
		for x: int in range(FACE_SIZE):
			var pos: Vector2i = Vector2i(x, y)

			var tile: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = get_tile_size(face)
			tile.mesh = mesh
			tile.position = grid_to_world(face, pos)

			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = get_face_color(face, x, y)
			mat.roughness = 0.65
			tile.material_override = mat

			cube_root.add_child(tile)

	build_face_border(face)
	build_face_icon(face)


func build_face_border(face: int) -> void:
	var mat: StandardMaterial3D = make_mat(Color(0.95, 0.95, 1.0))

	for i: int in range(FACE_SIZE):
		make_marker(face, Vector2i(i, 0), mat)
		make_marker(face, Vector2i(i, FACE_SIZE - 1), mat)
		make_marker(face, Vector2i(0, i), mat)
		make_marker(face, Vector2i(FACE_SIZE - 1, i), mat)


func make_marker(face: int, pos: Vector2i, mat: StandardMaterial3D) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()

	if face == FACE_SNOW or face == FACE_FOREST:
		mesh.size = Vector3(CELL_SIZE * 0.18, 0.18, CELL_SIZE * 0.18)
	elif face == FACE_HOME or face == FACE_SPACE:
		mesh.size = Vector3(CELL_SIZE * 0.18, CELL_SIZE * 0.18, 0.18)
	else:
		mesh.size = Vector3(0.18, CELL_SIZE * 0.18, CELL_SIZE * 0.18)

	marker.mesh = mesh
	marker.position = grid_to_world(face, pos) + get_face_normal(face) * 0.08
	marker.material_override = mat

	cube_root.add_child(marker)


func build_face_icon(face: int) -> void:
	var color_value: Color = Color.WHITE

	if face == FACE_HOME:
		color_value = Color(0.0, 0.8, 0.2)
	elif face == FACE_SNOW:
		color_value = Color(0.8, 0.95, 1.0)
	elif face == FACE_BEACH:
		color_value = Color(1.0, 0.8, 0.2)
	elif face == FACE_LAVA:
		color_value = Color(1.0, 0.25, 0.0)
	elif face == FACE_FOREST:
		color_value = Color(0.0, 0.6, 0.15)
	else:
		color_value = Color(0.75, 0.25, 1.0)

	var icon: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.10
	icon.mesh = mesh
	icon.position = grid_to_world(face, Vector2i(1, 1)) + get_face_normal(face) * 0.75
	icon.material_override = make_mat(color_value)
	cube_root.add_child(icon)


func get_tile_size(face: int) -> Vector3:
	if face == FACE_SNOW or face == FACE_FOREST:
		return Vector3(CELL_SIZE * 0.94, 0.10, CELL_SIZE * 0.94)

	if face == FACE_HOME or face == FACE_SPACE:
		return Vector3(CELL_SIZE * 0.94, CELL_SIZE * 0.94, 0.10)

	return Vector3(0.10, CELL_SIZE * 0.94, CELL_SIZE * 0.94)


func get_face_color(face: int, x: int, y: int) -> Color:
	var checker: bool = ((x + y) % 2) == 0

	if captured_faces.size() > face and captured_faces[face]:
		if checker:
			return Color(0.08, 0.70, 0.22)
		return Color(0.04, 0.48, 0.16)

	if face == FACE_HOME:
		if checker:
			return Color(0.18, 0.50, 0.20)
		return Color(0.10, 0.35, 0.15)

	if face == FACE_SNOW:
		if checker:
			return Color(0.85, 0.95, 1.0)
		return Color(0.62, 0.78, 0.95)

	if face == FACE_BEACH:
		if checker:
			return Color(0.95, 0.74, 0.32)
		return Color(0.76, 0.55, 0.22)

	if face == FACE_LAVA:
		if checker:
			return Color(0.55, 0.10, 0.04)
		return Color(0.22, 0.04, 0.03)

	if face == FACE_FOREST:
		if checker:
			return Color(0.05, 0.36, 0.12)
		return Color(0.02, 0.22, 0.08)

	if checker:
		return Color(0.12, 0.10, 0.28)

	return Color(0.04, 0.04, 0.12)


func rebuild_cube() -> void:
	build_cube()
	draw_all_food()
	draw_powerup()


func make_mat(color_value: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color_value
	mat.roughness = 0.6
	return mat


# ============================================================
# INPUT
# ============================================================

func handle_input() -> void:
	var m_down: bool = Input.is_key_pressed(KEY_M)
	var r_down: bool = Input.is_key_pressed(KEY_R)

	if m_down and not m_key_was_down:
		music_enabled = not music_enabled

	m_key_was_down = m_down

	if r_down and not r_key_was_down:
		if game_state == GameState.LOST:
			show_title()
		elif game_state == GameState.WON:
			start_game()

	r_key_was_down = r_down

	if game_state == GameState.TITLE:
		if Input.is_action_just_pressed("ui_left"):
			current_level -= 1
			if current_level < 1:
				current_level = unlocked_level
			show_title()

		if Input.is_action_just_pressed("ui_right"):
			current_level += 1
			if current_level > unlocked_level:
				current_level = 1
			show_title()

		if Input.is_action_just_pressed("ui_up"):
			difficulty_index += 1
			if difficulty_index > 2:
				difficulty_index = 0
			show_title()

		if Input.is_action_just_pressed("ui_down"):
			difficulty_index -= 1
			if difficulty_index < 0:
				difficulty_index = 2
			show_title()

		if Input.is_action_just_pressed("ui_accept"):
			start_game()

		return

	if game_state == GameState.LOST:
		if Input.is_action_just_pressed("ui_accept"):
			start_game()
		return

	if game_state == GameState.WON:
		if Input.is_action_just_pressed("ui_accept"):
			if current_level >= 6:
				show_title()
			else:
				current_level += 1
				if current_level > unlocked_level:
					unlocked_level = current_level
				start_game()
		return

	if game_state != GameState.PLAYING:
		return

	if Input.is_action_just_pressed("ui_up") and player.dir != Vector2i.DOWN:
		player.next_dir = Vector2i.UP

	if Input.is_action_just_pressed("ui_down") and player.dir != Vector2i.UP:
		player.next_dir = Vector2i.DOWN

	if Input.is_action_just_pressed("ui_left") and player.dir != Vector2i.RIGHT:
		player.next_dir = Vector2i.LEFT

	if Input.is_action_just_pressed("ui_right") and player.dir != Vector2i.LEFT:
		player.next_dir = Vector2i.RIGHT


# ============================================================
# GAME LOOP
# ============================================================

func _on_move_timer_timeout() -> void:
	if game_state != GameState.PLAYING:
		return

	move_timer.wait_time = get_move_speed()

	choose_bot_moves()

	var snakes: Array[SnakeData] = get_all_snakes()
	var next_faces: Array[int] = []
	var next_positions: Array[Vector2i] = []
	var next_dirs: Array[Vector2i] = []

	for snake: SnakeData in snakes:
		if not snake.alive:
			next_faces.append(snake.face)
			next_positions.append(snake.pos)
			next_dirs.append(snake.dir)
			continue

		var move_dir: Vector2i = snake.next_dir

		if snake.is_player and snake.face == FACE_SNOW and randi_range(0, 5) == 0:
			move_dir = snake.dir

		var step: StepResult = get_next_step(snake.face, snake.pos, move_dir)
		next_faces.append(step.face)
		next_positions.append(step.pos)
		next_dirs.append(step.dir)

	resolve_moves(snakes, next_faces, next_positions, next_dirs)

	tick_powers()
	sync_all_snake_nodes()
	draw_all_food()
	update_ui()
	check_level()


func choose_bot_moves() -> void:
	for bot: SnakeData in bots:
		if bot.alive:
			bot.next_dir = choose_bot_dir(bot)


func choose_bot_dir(bot: SnakeData) -> Vector2i:
	var target_face: int = choose_food_face(bot)
	var target_pos: Vector2i = food_positions[target_face]

	if player.alive:
		var face_dist: int = get_face_distance(bot.face, player.face)
		var same_face_close: bool = bot.face == player.face and get_grid_dist(bot.pos, player.pos) <= 6

		if bot.is_boss or same_face_close or face_dist == 1:
			target_face = player.face
			target_pos = player.pos

	var options: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.UP,
		Vector2i.DOWN
	]

	var best_dir: Vector2i = bot.dir
	var best_score: int = 999999

	for option: Vector2i in options:
		if option == -bot.dir:
			continue

		var step: StepResult = get_next_step(bot.face, bot.pos, option)
		var key: String = make_key(step.face, step.pos)

		if bot.trail.has(key):
			continue

		var score_value: int = get_grid_dist(step.pos, target_pos)

		if step.face != target_face:
			score_value += get_face_distance(step.face, target_face) * 12

		if step.face == player.face:
			score_value -= 3

		if bot.is_boss:
			score_value -= 2

		if score_value < best_score:
			best_score = score_value
			best_dir = option

	return best_dir


func choose_food_face(bot: SnakeData) -> int:
	var best_face: int = bot.face
	var best_score: int = 999999

	for face: int in range(6):
		var score_value: int = get_face_distance(bot.face, face) * 12
		score_value += get_grid_dist(bot.pos, food_positions[face])

		if score_value < best_score:
			best_score = score_value
			best_face = face

	return best_face


func resolve_moves(snakes: Array[SnakeData], next_faces: Array[int], next_positions: Array[Vector2i], next_dirs: Array[Vector2i]) -> void:
	var deaths: Array[bool] = []
	var killer: Array[int] = []

	for i: int in range(snakes.size()):
		deaths.append(false)
		killer.append(-1)

	for i: int in range(snakes.size()):
		var snake: SnakeData = snakes[i]

		if not snake.alive:
			continue

		var key: String = make_key(next_faces[i], next_positions[i])
		var owner: int = get_trail_owner(key, snakes)

		if owner != -1:
			if snake.is_player and ghost_moves > 0:
				continue

			if snake.is_player and shield_on:
				shield_on = false
				clear_enemy_trails_near(player.face, player.pos, 1)
				continue

			deaths[i] = true

			if owner != i:
				killer[i] = owner

	for i: int in range(snakes.size()):
		for j: int in range(i + 1, snakes.size()):
			if snakes[i].alive and snakes[j].alive:
				if next_faces[i] == next_faces[j] and next_positions[i] == next_positions[j]:
					deaths[i] = true
					deaths[j] = true

	for i: int in range(snakes.size()):
		if deaths[i]:
			var killer_index: int = killer[i]

			if killer_index != -1 and killer_index < snakes.size():
				snakes[killer_index].score += 10

				if snakes[killer_index].is_player:
					level_kills += 1

	for i: int in range(snakes.size()):
		var snake: SnakeData = snakes[i]

		if not snake.alive:
			continue

		if deaths[i]:
			damage_or_kill(snake)
			continue

		var old_face: int = snake.face

		snake.face = next_faces[i]
		snake.pos = next_positions[i]
		snake.dir = next_dirs[i]
		snake.next_dir = next_dirs[i]

		if snake.is_player and old_face != snake.face:
			camera_bump_timer = 0.45

		var new_key: String = make_key(snake.face, snake.pos)
		snake.trail.insert(0, new_key)

		if food_positions[snake.face] == snake.pos:
			eat_food(snake)
		else:
			while snake.trail.size() > snake.length:
				snake.trail.remove_at(snake.trail.size() - 1)

		if snake.is_player and snake.face == powerup_face and snake.pos == powerup_pos:
			collect_powerup()


func eat_food(snake: SnakeData) -> void:
	var points: int = 1

	if snake.face != snake.home_face:
		points = 3

	if snake.face == FACE_LAVA:
		points += 2

	if captured_faces[snake.face] and snake.is_player:
		points += 1

	snake.score += points
	snake.length += points

	if snake.is_player:
		face_food_count[snake.face] += 1

		if snake.face != FACE_HOME and not captured_faces[snake.face] and face_food_count[snake.face] >= 2:
			captured_faces[snake.face] = true
			captured_count += 1
			player.score += 10
			rebuild_cube()

	spawn_food(snake.face)

	if randi_range(0, 3) == 0:
		spawn_powerup()


func damage_or_kill(snake: SnakeData) -> void:
	if snake.is_boss:
		snake.boss_lives -= 1

		if snake.boss_lives > 0:
			snake.length = max(6, snake.length - 3)
			while snake.trail.size() > snake.length:
				snake.trail.remove_at(snake.trail.size() - 1)
			return

	kill_snake(snake)


func kill_snake(snake: SnakeData) -> void:
	snake.alive = false

	for node: Node3D in snake.nodes:
		if is_instance_valid(node):
			node.queue_free()

	snake.nodes.clear()
	snake.targets.clear()
	snake.trail.clear()


func tick_powers() -> void:
	if ghost_moves > 0:
		ghost_moves -= 1

	if boost_moves > 0:
		boost_moves -= 1


func check_level() -> void:
	if not player.alive:
		show_lost("Cut off")
		return

	for bot: SnakeData in bots:
		if bot.alive and bot.score >= WIN_SCORE:
			show_lost(bot.name + " won")
			return

	if level_complete():
		if current_level >= unlocked_level and unlocked_level < 6:
			unlocked_level += 1

		show_won("Level " + str(current_level))
		return


func level_complete() -> bool:
	if current_level == 1:
		return player.score >= 20

	if current_level == 2:
		return player.score >= 30 and level_kills >= 1

	if current_level == 3:
		return player.score >= 50 and captured_count >= 1

	if current_level == 4:
		return player.score >= 50 and level_kills >= 3

	if current_level == 5:
		return player.score >= 80 or captured_count >= 3

	if current_level == 6:
		if player.score >= WIN_SCORE:
			return true

		for bot: SnakeData in bots:
			if bot.is_boss and not bot.alive:
				return true

	return false


# ============================================================
# POWERUPS
# ============================================================

func spawn_powerup() -> void:
	powerup_face = randi_range(0, 5)
	powerup_pos = Vector2i(randi_range(1, FACE_SIZE - 2), randi_range(1, FACE_SIZE - 2))
	powerup_type = randi_range(POWER_SHIELD, POWER_BOMB)
	draw_powerup()


func draw_powerup() -> void:
	if powerup_node != null and is_instance_valid(powerup_node):
		powerup_node.queue_free()

	if powerup_type == POWER_NONE:
		return

	powerup_node = Node3D.new()

	var box: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.90, 0.90, 0.90)
	box.mesh = mesh
	box.material_override = make_mat(get_power_color(powerup_type))
	powerup_node.add_child(box)

	powerup_node.position = grid_to_world(powerup_face, powerup_pos) + get_face_normal(powerup_face) * 0.85
	add_child(powerup_node)


func get_power_color(power_type: int) -> Color:
	if power_type == POWER_SHIELD:
		return Color(0.2, 0.7, 1.0)
	if power_type == POWER_GHOST:
		return Color(0.8, 0.8, 1.0)
	if power_type == POWER_BOOST:
		return Color(1.0, 0.9, 0.1)
	if power_type == POWER_BOMB:
		return Color(1.0, 0.2, 0.1)

	return Color.WHITE


func collect_powerup() -> void:
	if powerup_type == POWER_SHIELD:
		shield_on = true

	if powerup_type == POWER_GHOST:
		ghost_moves = 20

	if powerup_type == POWER_BOOST:
		boost_moves = 25

	if powerup_type == POWER_BOMB:
		clear_enemy_trails_near(player.face, player.pos, 2)

	player.score += 2
	powerup_type = POWER_NONE

	if powerup_node != null and is_instance_valid(powerup_node):
		powerup_node.queue_free()

	powerup_node = null


func clear_enemy_trails_near(face: int, center: Vector2i, radius: int) -> void:
	for snake: SnakeData in get_all_snakes():
		if snake.is_player or not snake.alive:
			continue

		var new_trail: Array[String] = []

		for key: String in snake.trail:
			var parsed: Array[int] = parse_key(key)
			var key_face: int = parsed[0]
			var pos: Vector2i = Vector2i(parsed[1], parsed[2])

			if key_face == face and abs(pos.x - center.x) <= radius and abs(pos.y - center.y) <= radius:
				continue

			new_trail.append(key)

		snake.trail = new_trail
		snake.length = min(snake.length, snake.trail.size())


func update_powerup(delta: float) -> void:
	if powerup_node == null:
		return

	if not is_instance_valid(powerup_node):
		return

	var base: Vector3 = grid_to_world(powerup_face, powerup_pos) + get_face_normal(powerup_face) * 0.85
	var bounce: float = sin(float(Time.get_ticks_msec()) / 180.0) * 0.12
	var target: Vector3 = base + get_face_normal(powerup_face) * bounce

	powerup_node.position = powerup_node.position.lerp(target, clamp(delta * 8.0, 0.0, 1.0))
	powerup_node.rotate_y(delta * 2.0)


# ============================================================
# FOOD
# ============================================================

func spawn_food(face: int) -> void:
	var spaces: Array[Vector2i] = []

	for y: int in range(FACE_SIZE):
		for x: int in range(FACE_SIZE):
			var pos: Vector2i = Vector2i(x, y)
			var key: String = make_key(face, pos)

			if get_trail_owner(key, get_all_snakes()) == -1:
				spaces.append(pos)

	if spaces.is_empty():
		return

	var index: int = randi_range(0, spaces.size() - 1)
	food_positions[face] = spaces[index]


func draw_all_food() -> void:
	while food_nodes.size() < 6:
		food_nodes.append(null)

	for face: int in range(6):
		if food_nodes[face] == null or not is_instance_valid(food_nodes[face]):
			var food: Node3D = make_food(face)
			add_child(food)
			food_nodes[face] = food

		food_nodes[face].position = grid_to_world(face, food_positions[face]) + get_face_normal(face) * 0.65


func make_food(face: int) -> Node3D:
	var food: Node3D = Node3D.new()

	var fruit: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.90
	fruit.mesh = mesh
	fruit.material_override = make_mat(get_food_color(face))
	food.add_child(fruit)

	return food


func get_food_color(face: int) -> Color:
	if captured_faces.size() > face and captured_faces[face]:
		return Color(0.10, 1.0, 0.35)

	if face == FACE_LAVA:
		return Color(1.0, 0.45, 0.05)

	if face == FACE_HOME:
		return Color(0.20, 0.85, 1.0)

	return Color(1.0, 0.08, 0.10)


func update_food(delta: float) -> void:
	for face: int in range(food_nodes.size()):
		var node: Node3D = food_nodes[face]

		if node == null:
			continue

		if not is_instance_valid(node):
			continue

		var base: Vector3 = grid_to_world(face, food_positions[face]) + get_face_normal(face) * 0.65
		var bounce: float = sin(float(Time.get_ticks_msec()) / 220.0 + float(face)) * 0.10
		var target: Vector3 = base + get_face_normal(face) * bounce

		node.position = node.position.lerp(target, clamp(delta * 8.0, 0.0, 1.0))


# ============================================================
# SNAKE VISUALS
# ============================================================

func create_snake_nodes(snake: SnakeData) -> void:
	for i: int in range(snake.trail.size()):
		var part: Node3D = make_snake_part(snake, i == 0)
		var parsed: Array[int] = parse_key(snake.trail[i])
		var face: int = parsed[0]
		var pos: Vector2i = Vector2i(parsed[1], parsed[2])
		var target: Vector3 = grid_to_world(face, pos) + get_face_normal(face) * 0.62

		part.position = target
		add_child(part)

		snake.nodes.append(part)
		snake.targets.append(target)


func make_snake_part(snake: SnakeData, is_head: bool) -> Node3D:
	var part: Node3D = Node3D.new()

	var body: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()

	if snake.is_boss:
		if is_head:
			mesh.radius = 0.82
			mesh.height = 1.64
		else:
			mesh.radius = 0.55
			mesh.height = 1.10
	else:
		if is_head:
			mesh.radius = 0.58
			mesh.height = 1.16
		else:
			mesh.radius = 0.40
			mesh.height = 0.80

	body.mesh = mesh
	body.material_override = make_mat(snake.color)
	part.add_child(body)

	if is_head:
		var crown: MeshInstance3D = MeshInstance3D.new()
		var crown_mesh: BoxMesh = BoxMesh.new()
		crown_mesh.size = Vector3(0.36, 0.20, 0.36)

		if snake.is_boss:
			crown_mesh.size = Vector3(0.60, 0.30, 0.60)

		crown.mesh = crown_mesh
		crown.position = Vector3(0.0, 0.46, 0.0)
		crown.material_override = make_mat(Color.WHITE)
		part.add_child(crown)

	return part


func sync_all_snake_nodes() -> void:
	for snake: SnakeData in get_all_snakes():
		if snake.alive:
			sync_snake_nodes(snake)


func sync_snake_nodes(snake: SnakeData) -> void:
	while snake.nodes.size() < snake.trail.size():
		var part: Node3D = make_snake_part(snake, false)
		var last_key: String = snake.trail[snake.trail.size() - 1]
		var parsed: Array[int] = parse_key(last_key)
		var face: int = parsed[0]
		var pos: Vector2i = Vector2i(parsed[1], parsed[2])
		var start_pos: Vector3 = grid_to_world(face, pos) + get_face_normal(face) * 0.62

		part.position = start_pos
		add_child(part)

		snake.nodes.append(part)
		snake.targets.append(start_pos)

	while snake.nodes.size() > snake.trail.size():
		var old_node: Node3D = snake.nodes[snake.nodes.size() - 1]
		snake.nodes.remove_at(snake.nodes.size() - 1)
		snake.targets.remove_at(snake.targets.size() - 1)

		if is_instance_valid(old_node):
			old_node.queue_free()

	for i: int in range(snake.trail.size()):
		var parsed: Array[int] = parse_key(snake.trail[i])
		var face: int = parsed[0]
		var pos: Vector2i = Vector2i(parsed[1], parsed[2])
		snake.targets[i] = grid_to_world(face, pos) + get_face_normal(face) * 0.62


func update_snakes(delta: float) -> void:
	for snake: SnakeData in get_all_snakes():
		if not snake.alive:
			continue

		for i: int in range(snake.nodes.size()):
			if i >= snake.targets.size():
				return

			snake.nodes[i].position = snake.nodes[i].position.lerp(
				snake.targets[i],
				clamp(delta * VISUAL_SPEED, 0.0, 1.0)
			)


# ============================================================
# CAMERA
# ============================================================

func update_camera(delta: float) -> void:
	var face: int = FACE_HOME

	if game_state == GameState.PLAYING and player.alive:
		face = player.face

	var target_pos: Vector3 = get_camera_position(face)
	var target_center: Vector3 = get_face_center(face)
	var up: Vector3 = get_camera_up(face)

	if camera_bump_timer > 0.0:
		var power: float = sin((camera_bump_timer / 0.45) * PI)
		target_pos += get_face_normal(face) * (-3.0 * power)
		camera_bump_timer -= delta

		if camera_bump_timer < 0.0:
			camera_bump_timer = 0.0

	camera.position = camera.position.lerp(target_pos, clamp(delta * 5.0, 0.0, 1.0))
	camera.look_at(target_center, up)


func get_camera_position(face: int) -> Vector3:
	return get_face_center(face) + get_face_normal(face) * 30.0


func get_camera_up(face: int) -> Vector3:
	if face == FACE_SNOW:
		return Vector3.FORWARD

	if face == FACE_FOREST:
		return Vector3.BACK

	return Vector3.UP


# ============================================================
# CUBE MOVEMENT
# ============================================================

func get_next_step(face: int, pos: Vector2i, dir: Vector2i) -> StepResult:
	var result: StepResult = StepResult.new()
	var next_pos: Vector2i = pos + dir

	result.face = face
	result.pos = next_pos
	result.dir = dir

	if next_pos.x >= 0 and next_pos.x < FACE_SIZE and next_pos.y >= 0 and next_pos.y < FACE_SIZE:
		return result

	if next_pos.x < 0:
		result.face = get_neighbor_face(face, Vector2i.LEFT)
		result.pos = Vector2i(FACE_SIZE - 1, pos.y)

	if next_pos.x >= FACE_SIZE:
		result.face = get_neighbor_face(face, Vector2i.RIGHT)
		result.pos = Vector2i(0, pos.y)

	if next_pos.y < 0:
		result.face = get_neighbor_face(face, Vector2i.UP)
		result.pos = Vector2i(pos.x, FACE_SIZE - 1)

	if next_pos.y >= FACE_SIZE:
		result.face = get_neighbor_face(face, Vector2i.DOWN)
		result.pos = Vector2i(pos.x, 0)

	return result


func get_neighbor_face(face: int, edge_dir: Vector2i) -> int:
	if face == FACE_HOME:
		if edge_dir == Vector2i.UP:
			return FACE_SNOW
		if edge_dir == Vector2i.DOWN:
			return FACE_FOREST
		if edge_dir == Vector2i.LEFT:
			return FACE_BEACH
		if edge_dir == Vector2i.RIGHT:
			return FACE_LAVA

	if face == FACE_SPACE:
		if edge_dir == Vector2i.UP:
			return FACE_SNOW
		if edge_dir == Vector2i.DOWN:
			return FACE_FOREST
		if edge_dir == Vector2i.LEFT:
			return FACE_LAVA
		if edge_dir == Vector2i.RIGHT:
			return FACE_BEACH

	if face == FACE_BEACH:
		if edge_dir == Vector2i.LEFT:
			return FACE_SPACE
		if edge_dir == Vector2i.RIGHT:
			return FACE_HOME
		if edge_dir == Vector2i.UP:
			return FACE_SNOW
		if edge_dir == Vector2i.DOWN:
			return FACE_FOREST

	if face == FACE_LAVA:
		if edge_dir == Vector2i.LEFT:
			return FACE_HOME
		if edge_dir == Vector2i.RIGHT:
			return FACE_SPACE
		if edge_dir == Vector2i.UP:
			return FACE_SNOW
		if edge_dir == Vector2i.DOWN:
			return FACE_FOREST

	if face == FACE_SNOW:
		if edge_dir == Vector2i.UP:
			return FACE_SPACE
		if edge_dir == Vector2i.DOWN:
			return FACE_HOME
		if edge_dir == Vector2i.LEFT:
			return FACE_BEACH
		if edge_dir == Vector2i.RIGHT:
			return FACE_LAVA

	if face == FACE_FOREST:
		if edge_dir == Vector2i.UP:
			return FACE_HOME
		if edge_dir == Vector2i.DOWN:
			return FACE_SPACE
		if edge_dir == Vector2i.LEFT:
			return FACE_BEACH
		if edge_dir == Vector2i.RIGHT:
			return FACE_LAVA

	return FACE_HOME


func get_face_distance(start_face: int, target_face: int) -> int:
	if start_face == target_face:
		return 0

	var neighbors: Array[int] = []
	neighbors.append(get_neighbor_face(start_face, Vector2i.RIGHT))
	neighbors.append(get_neighbor_face(start_face, Vector2i.LEFT))
	neighbors.append(get_neighbor_face(start_face, Vector2i.UP))
	neighbors.append(get_neighbor_face(start_face, Vector2i.DOWN))

	if neighbors.has(target_face):
		return 1

	return 2


# ============================================================
# HELPERS
# ============================================================

func make_key(face: int, pos: Vector2i) -> String:
	return str(face) + ":" + str(pos.x) + ":" + str(pos.y)


func parse_key(key: String) -> Array[int]:
	var pieces: PackedStringArray = key.split(":")
	var result: Array[int] = []
	result.append(pieces[0].to_int())
	result.append(pieces[1].to_int())
	result.append(pieces[2].to_int())
	return result


func get_trail_owner(key: String, snakes: Array[SnakeData]) -> int:
	for i: int in range(snakes.size()):
		var snake: SnakeData = snakes[i]

		if snake.alive and snake.trail.has(key):
			return i

	return -1


func get_grid_dist(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func get_half_size() -> float:
	return float(FACE_SIZE - 1) * CELL_SIZE / 2.0


func grid_to_world(face: int, pos: Vector2i) -> Vector3:
	var half: float = get_half_size()
	var u: float = float(pos.x) * CELL_SIZE - half
	var v: float = float(pos.y) * CELL_SIZE - half

	if face == FACE_HOME:
		return Vector3(u, -v, half)

	if face == FACE_SPACE:
		return Vector3(-u, -v, -half)

	# fixed so Beach left/right feels right
	if face == FACE_BEACH:
		return Vector3(-half, -v, u)

	# fixed so Lava left/right feels right
	if face == FACE_LAVA:
		return Vector3(half, -v, -u)

	if face == FACE_SNOW:
		return Vector3(u, half, v)

	if face == FACE_FOREST:
		return Vector3(u, -half, -v)

	return Vector3.ZERO


func get_face_normal(face: int) -> Vector3:
	if face == FACE_HOME:
		return Vector3.BACK

	if face == FACE_SPACE:
		return Vector3.FORWARD

	if face == FACE_BEACH:
		return Vector3.LEFT

	if face == FACE_LAVA:
		return Vector3.RIGHT

	if face == FACE_SNOW:
		return Vector3.UP

	if face == FACE_FOREST:
		return Vector3.DOWN

	return Vector3.UP


func get_face_center(face: int) -> Vector3:
	var half: float = get_half_size()

	if face == FACE_HOME:
		return Vector3(0.0, 0.0, half)

	if face == FACE_SPACE:
		return Vector3(0.0, 0.0, -half)

	if face == FACE_BEACH:
		return Vector3(-half, 0.0, 0.0)

	if face == FACE_LAVA:
		return Vector3(half, 0.0, 0.0)

	if face == FACE_SNOW:
		return Vector3(0.0, half, 0.0)

	if face == FACE_FOREST:
		return Vector3(0.0, -half, 0.0)

	return Vector3.ZERO


func get_face_name(face: int) -> String:
	if face == FACE_HOME:
		return "Home"

	if face == FACE_SNOW:
		return "Snow"

	if face == FACE_BEACH:
		return "Beach"

	if face == FACE_LAVA:
		return "Lava"

	if face == FACE_FOREST:
		return "Forest"

	if face == FACE_SPACE:
		return "Space"

	return "?"


func get_all_snakes() -> Array[SnakeData]:
	var all: Array[SnakeData] = []
	all.append(player)

	for bot: SnakeData in bots:
		all.append(bot)

	return all


func clear_game_objects() -> void:
	if cube_root != null and is_instance_valid(cube_root):
		cube_root.queue_free()

	cube_root = null

	for node: Node3D in food_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()

	food_nodes.clear()
	food_positions.clear()

	if powerup_node != null and is_instance_valid(powerup_node):
		powerup_node.queue_free()

	powerup_node = null
	powerup_type = POWER_NONE

	for snake: SnakeData in get_all_snakes():
		for node: Node3D in snake.nodes:
			if is_instance_valid(node):
				node.queue_free()

		snake.nodes.clear()
		snake.targets.clear()
		snake.trail.clear()

	bots.clear()
