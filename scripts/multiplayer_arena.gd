extends Node2D

signal return_to_title

enum State { READY, COUNTDOWN, FIGHT, BREAK, FINISHED }
const PlayerScript = preload("res://scripts/arena_player.gd")
const EnemyScript = preload("res://scripts/arena_enemy.gd")
# Order, counts and difficulty are isolated from the story campaign.
const WAVES = [
	{"name": "THE FIRST RAID", "ogres": 2, "goblins": 6, "bosses": 0},
	{"name": "GOBLIN HORDE", "ogres": 1, "goblins": 13, "bosses": 0},
	{"name": "IRON RAID", "ogres": 4, "goblins": 12, "bosses": 0},
	{"name": "CAVE SIEGE", "ogres": 5, "goblins": 15, "bosses": 0},
	{"name": "THE OGRE WARLORD", "ogres": 4, "goblins": 17, "bosses": 1}
]
var state: State = State.READY
var wave: int = 0
var countdown: float = 0.0
var elapsed: float = 0.0
var victorious: bool = false
var background: Sprite2D
var actors: Node2D
var players: Array[Node2D] = []
var enemies: Array[Node2D] = []
var extent := Vector2(1152, 648)
var floor_bounds := Rect2(75, 310, 1002, 285)
var hud: CanvasLayer
var cards: Array[PanelContainer] = []
var bars: Array[ProgressBar] = []
var hp_labels: Array[Label] = []
var wave_label: Label
var count_label: Label
var banner: Label
var help_label: Label
var boss_bar: ProgressBar
var boss_label: Label
var pause_button: Button
var menu: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	background = Sprite2D.new()
	background.texture = preload("res://assets/passage_interior.png")
	background.z_index = -10
	background.modulate = Color(0.72, 0.72, 0.82)
	add_child(background)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	actors.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(actors)
	_build_hud()
	for number in [1, 2]:
		var player := CharacterBody2D.new()
		player.set_script(PlayerScript)
		player.player_number = number
		player.arena = self
		actors.add_child(player)
		players.append(player)
		player.health_changed.connect(_refresh_hud)
		player.defeated.connect(_check_defeat)
	menu = CanvasLayer.new()
	menu.set_script(preload("res://scripts/choice_menu.gd"))
	add_child(menu)
	menu.body.custom_minimum_size.y = 200
	menu.selected.connect(_menu_selected)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_reset_positions()
	_refresh_hud()
	menu.present("MULTIPLAYER MODE", "[b]Two dragons. One keyboard. Five fierce waves.[/b]\n[color=#b9ef71]P1 Green:[/color] WASD to move, R to attack, Q to dash.\n[color=#75c7ff]P2 Blue:[/color] Arrow keys to move, Enter to attack, Shift to dash.\nHold attack for repeated strikes. Move to aim. Avoid the red circles!\nClear a wave: +30 HP and revive your partner at 60 HP.\nDefeat the Ogre Warlord and his escorts to win.", [{"id":"start", "label":"Start the Raid"}, {"id":"title", "label":"Back to Title"}])

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 3
	add_child(hud)
	for number in [1, 2]:
		var color := Color("a9ee54") if number == 1 else Color("63baff")
		var card := PanelContainer.new()
		var style := bar_style(Color(0.055, 0.065, 0.13, 0.94))
		style.border_color = color
		style.set_border_width_all(2)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		card.add_theme_stylebox_override("panel", style)
		hud.add_child(card)
		cards.append(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		card.add_child(column)
		var name_label := _make_label("P%d  /  %s FINNY" % [number, "GREEN" if number == 1 else "BLUE"], 18, color)
		column.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(230, 15)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("fill", bar_style(color))
		bar.add_theme_stylebox_override("background", bar_style(Color("25273b")))
		column.add_child(bar)
		bars.append(bar)
		var label := _make_label("100 / 100 HP", 15, Color.WHITE)
		column.add_child(label)
		hp_labels.append(label)
	wave_label = _make_label("LOCAL CO-OP", 23, Color("f5d98a"))
	count_label = _make_label("Prepare for the raid", 17, Color.WHITE)
	banner = _make_label("", 25, Color("f5e6b5"))
	help_label = _make_label("P1  WASD • R attack • Q dash     |     P2  Arrows • Enter attack • Shift dash", 16, Color("e6e5fc"))
	boss_label = _make_label("OGRE WARLORD", 17, Color("ffce7e"))
	for label in [wave_label, count_label, banner, help_label, boss_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hud.add_child(label)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.max_value = 1600
	boss_bar.add_theme_stylebox_override("fill", bar_style(Color("d94b56")))
	boss_bar.add_theme_stylebox_override("background", bar_style(Color("20162b")))
	hud.add_child(boss_bar)
	boss_bar.hide()
	boss_label.hide()
	pause_button = Button.new()
	pause_button.text = "Pause [Esc]"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(pause_arena)
	hud.add_child(pause_button)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("11121d"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style

func _layout() -> void:
	var old_bounds := floor_bounds
	extent = get_viewport_rect().size
	background.position = extent / 2
	background.scale = Vector2.ONE * maxf(extent.x / background.texture.get_width(), extent.y / background.texture.get_height())
	floor_bounds = Rect2(75, extent.y * 0.48, extent.x - 150, extent.y * 0.44)
	for actor in actors.get_children():
		var fraction: Vector2 = (actor.position - old_bounds.position) / old_bounds.size
		actor.position = floor_bounds.position + fraction * floor_bounds.size
		# Keep a committed enemy strike in the same place relative to the floor.
		if actor.get_script() == EnemyScript:
			actor.strike_position = floor_bounds.position + (actor.strike_position - old_bounds.position) / old_bounds.size * floor_bounds.size
		clamp_actor(actor)
	cards[0].position = Vector2(20, 18)
	cards[1].position = Vector2(extent.x - 280, 18)
	for card in cards: card.size = Vector2(260, 98)
	wave_label.position = Vector2(300, 23)
	wave_label.size = Vector2(extent.x - 600, 32)
	count_label.position = Vector2(300, 59)
	count_label.size = Vector2(extent.x - 600, 28)
	banner.position = Vector2(0, 166)
	banner.size = Vector2(extent.x, 64)
	help_label.position = Vector2(0, extent.y - 31)
	help_label.size = Vector2(extent.x - 135, 26)
	pause_button.position = Vector2(extent.x - 134, extent.y - 35)
	pause_button.size = Vector2(124, 29)
	boss_label.position = Vector2(extent.x * 0.30, 109)
	boss_label.size = Vector2(extent.x * 0.40, 26)
	boss_bar.position = Vector2(extent.x * 0.30, 139)
	boss_bar.size = Vector2(extent.x * 0.40, 14)
	queue_redraw()

func _draw() -> void:
	var r := floor_bounds.grow(28)
	var points := PackedVector2Array([r.position + Vector2(55, 0), Vector2(r.end.x - 55, r.position.y), Vector2(r.end.x, r.position.y + 30), r.end - Vector2(0, 25), r.end - Vector2(50, 0), Vector2(r.position.x + 50, r.end.y), Vector2(r.position.x, r.end.y - 25), r.position + Vector2(0, 30)])
	draw_colored_polygon(points, Color(0.12, 0.09, 0.23, 0.91))
	var edge := points.duplicate()
	edge.append(points[0])
	draw_polyline(edge, Color("8977aa"), 3, true)
	for row in range(1, 5):
		var y := r.position.y + r.size.y * row / 5.0
		draw_line(Vector2(r.position.x + 20, y), Vector2(r.end.x - 20, y), Color(0.45, 0.39, 0.55, 0.25), 2)
		for col in range(1, 8):
			var x := r.position.x + r.size.x * (col + (0.35 if row % 2 == 0 else 0.0)) / 8.0
			draw_line(Vector2(x, y), Vector2(x - 14, y + r.size.y / 5.0), Color(0.45, 0.39, 0.55, 0.22), 2)
	draw_arc(r.get_center(), 73, 0, TAU, 64, Color(0.65, 0.60, 0.79, 0.16), 3, true)

func _reset_positions() -> void:
	players[0].position = floor_bounds.position + floor_bounds.size * Vector2(0.40, 0.68)
	players[1].position = floor_bounds.position + floor_bounds.size * Vector2(0.60, 0.68)
	players[0].facing = Vector2.LEFT
	players[0].sprite.flip_h = true
	players[1].facing = Vector2.RIGHT

func clamp_actor(actor: Node2D) -> void:
	actor.position.x = clampf(actor.position.x, floor_bounds.position.x, floor_bounds.end.x)
	actor.position.y = clampf(actor.position.y, floor_bounds.position.y, floor_bounds.end.y)

func living_players() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for player in players:
		if is_instance_valid(player) and not player.is_dead: alive.append(player)
	return alive

func living_enemies() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead: alive.append(enemy)
	return alive

func players_can_move() -> bool:
	return state in [State.FIGHT, State.BREAK, State.COUNTDOWN] and not get_tree().paused

func _process(delta: float) -> void:
	if get_tree().paused: return
	if state == State.FIGHT:
		elapsed += delta
		if living_players().is_empty():
			finish_match(false)
		elif living_enemies().is_empty():
			if wave == WAVES.size():
				finish_match(true)
			else:
				state = State.BREAK
				countdown = 5.0
				# Wait for any death tween before reviving a fallen teammate.
				for player in players: player.velocity = Vector2.ZERO
	elif state in [State.COUNTDOWN, State.BREAK]:
		countdown -= delta
		if countdown <= 0:
			if state == State.BREAK:
				for player in players: player.recover_between_waves()
			start_wave(wave + 1)
	_refresh_hud()

func start_wave(number: int) -> void:
	if number < 1 or number > WAVES.size(): return
	for enemy in enemies:
		if is_instance_valid(enemy):
			actors.remove_child(enemy)
			enemy.queue_free()
	enemies.clear()
	wave = number
	state = State.FIGHT
	var setup: Array[int] = []
	var raid: Dictionary = WAVES[wave - 1]
	for i in range(raid.bosses): setup.append(2)
	for i in range(raid.ogres): setup.append(1)
	for i in range(raid.goblins): setup.append(0)
	for i in range(setup.size()):
		var enemy := CharacterBody2D.new()
		enemy.set_script(EnemyScript)
		enemy.kind = setup[i]
		enemy.raid_number = wave
		enemy.arena = self
		var row := floori(i / 2.0)
		var lane := float(row) / maxf(1.0, ceilf(setup.size() / 2.0) - 1.0)
		var stagger := 0.08 if row % 2 == 1 else 0.0
		enemy.position = floor_bounds.position + floor_bounds.size * Vector2(0.04 + stagger if i % 2 == 0 else 0.96 - stagger, 0.12 + lane * 0.76)
		actors.add_child(enemy)
		enemies.append(enemy)
	_refresh_hud()

func _refresh_hud() -> void:
	for i in range(players.size()):
		bars[i].value = players[i].health
		hp_labels[i].text = "DOWN - revive after this wave" if players[i].is_dead else "%d / 100 HP" % players[i].health
	var alive := living_enemies()
	wave_label.text = "WAVE %d / %d" % [wave, WAVES.size()] if wave > 0 else "LOCAL CO-OP"
	count_label.text = "%s  •  %d left" % [WAVES[wave - 1].name, alive.size()] if wave > 0 else "Prepare for the raid"
	boss_bar.hide()
	boss_label.hide()
	for enemy in alive:
		if enemy.kind == 2:
			boss_bar.show()
			boss_label.show()
			boss_bar.max_value = enemy.max_health
			boss_bar.value = enemy.health
			boss_label.text = "OGRE WARLORD  /  %d HP" % enemy.health
	if state == State.COUNTDOWN:
		banner.text = "GET READY  /  %d" % maxi(1, ceili(countdown))
	elif state == State.BREAK:
		banner.text = "WAVE CLEARED!\nHeal + revive in %d" % maxi(1, ceili(countdown))
	elif state == State.FIGHT and living_players().size() == 1:
		banner.text = "Your partner is down. Clear the wave to bring them back!"
	else:
		banner.text = ""

func _check_defeat() -> void:
	if living_players().is_empty(): finish_match(false)

func finish_match(won: bool) -> void:
	if state == State.FINISHED: return
	state = State.FINISHED
	victorious = won
	for actor in actors.get_children():
		actor.velocity = Vector2.ZERO
		actor.sprite.stop()
	var defeated_count := 0
	for i in range(wave - 1): defeated_count += wave_enemy_count(i)
	if wave > 0: defeated_count += wave_enemy_count(wave - 1) - living_enemies().size()
	menu.present("CAVE DEFENDERS!" if won else "TEAM DEFEATED", ("Both dragons defended the cave. The Ogre Warlord is defeated!" if won else "Both dragons fell. Try moving out of the red circles and attacking together.") + "\nEnemies defeated: %d / %d   |   Battle time: %d:%02d\nYour campaign save is unchanged." % [defeated_count, total_enemy_count(), floori(elapsed / 60.0), int(elapsed) % 60], [{"id":"retry", "label":"Play Again"}, {"id":"title", "label":"Return to Title"}])

func wave_enemy_count(index: int) -> int:
	var raid: Dictionary = WAVES[index]
	return int(raid.goblins) + int(raid.ogres) + int(raid.bosses)

func total_enemy_count() -> int:
	var total := 0
	for i in range(WAVES.size()): total += wave_enemy_count(i)
	return total

func pause_arena() -> void:
	if state in [State.READY, State.FINISHED] or get_tree().paused: return
	get_tree().paused = true
	menu.present("CO-OP PAUSED", "P1: WASD / R attack / Q dash\nP2: Arrow keys / Enter attack / Shift dash\nResume this match or restart all five waves.", [{"id":"resume", "label":"Resume"}, {"id":"retry", "label":"Restart Match"}, {"id":"title", "label":"Return to Title"}])

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if get_tree().paused: _menu_selected("resume")
		else: pause_arena()
		get_viewport().set_input_as_handled()

func _menu_selected(choice: String) -> void:
	match choice:
		"start", "retry":
			get_tree().paused = false
			menu.hide()
			for enemy in enemies:
				if is_instance_valid(enemy):
					actors.remove_child(enemy)
					enemy.queue_free()
			enemies.clear()
			for player in players:
				player.recover_between_waves()
				player.health = 100
				player.sprite.rotation = 0
				player.sprite.play("idle")
				player.dash_cooldown = 0
				player._update_health()
			_reset_positions()
			wave = 0
			elapsed = 0
			victorious = false
			state = State.COUNTDOWN
			countdown = 3
		"resume":
			menu.hide()
			get_tree().paused = false
		"title":
			get_tree().paused = false
			return_to_title.emit()
	get_viewport().gui_release_focus()
