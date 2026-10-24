extends Node2D

enum Flow { TITLE, PLAYING, PAUSED, DECISION, RESULT, COOP, INTRO }
const SAVE_PATH := "user://campaign_v3.cfg"
const MenuScript = preload("res://scripts/choice_menu.gd")
const LevelOne = preload("res://scenes/level01.tscn")
const LevelTwo = preload("res://scenes/level02.tscn")
const PlayerScene = preload("res://player/player_01.tscn")
const ChestScene = preload("res://level/chest/chest.tscn")

@onready var level: Node2D = $Level01
@onready var hud: CanvasLayer = $UI
@onready var screen: TextureRect = $MenuLayer/Screen
@onready var result_label: Label = $MenuLayer/ResultLabel
var menu: CanvasLayer
var flow: Flow = Flow.TITLE
var music: AudioStreamPlayer
var day_label: Label
var details_label: Label
var morning_checkpoint: Dictionary = {}
var level_checkpoint: Dictionary = {}
var testing_level_two: bool = false
var title_screen: Control
var transitioning: bool = false
var notice: Label
var notice_time: float = 0
var hud_actions: HBoxContainer
var arena: Node2D
var intro: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(quit_game)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.hide()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.hide()
	screen.hide()
	result_label.hide()
	menu = CanvasLayer.new()
	menu.set_script(MenuScript)
	add_child(menu)
	title_screen = Control.new()
	title_screen.set_script(preload("res://scripts/title_scene.gd"))
	$MenuLayer.add_child(title_screen)
	title_screen.selected.connect(_title_selected)
	day_label = _label(23, Color("ffe0a0"))
	details_label = _label(16, Color("e9ebff"))
	notice = _label(18, Color("fff0be"))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_actions = HBoxContainer.new()
	hud_actions.add_theme_constant_override("separation", 8)
	hud.add_child(hud_actions)
	for item in [["Ledger [B]", open_ledger], ["Save [F5]", manual_save], ["Pause [Esc]", pause_menu]]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(125, 32)
		button.pressed.connect(item[1])
		hud_actions.add_child(button)
	$UI/PanelContainer/Controls.add_theme_font_size_override("font_size", 15)
	$UI/PanelContainer/Controls.text = "WASD / Arrows: Move    E: Show / Door / Deposit / Rest    R: Attack    B: Ledger    F5: Save    F11: Fullscreen"
	for label in [$UI/LabelKing, $UI/LabelBusinnes, $UI/LabelWallet]:
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_outline_size", 5)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_create_music()
	title_menu()

func _process(delta: float) -> void:
	if notice_time > 0:
		notice_time -= delta
		notice.visible = notice_time > 0
	if flow == Flow.PLAYING and is_instance_valid(level) and level.is_running:
		if level.game_has_ended():
			_end_game(false)
		else:
			day_label.text = "LEVEL %d | DAY %d / %d | %s" % [Economy.level_number, level.current_day, level.last_day(), "NIGHT" if level.is_night else "OPEN"]
			details_label.text = "Customers %d / %d | %s" % [level.customers_spawned_today, level.day_customer_count, ["SHOW HALL", "PASSAGE", "ROOM"][level.current_location]]
			if Economy.level_number == 2:
				details_label.text += "\nShow %d - supplies 50 | Staff %d | Loan due %d" % [Economy.ticket_price(), Economy.employees, Economy.loan_due]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if flow != Flow.PLAYING:
		return
	match event.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			pause_menu()
		KEY_B:
			get_viewport().set_input_as_handled()
			open_ledger()
		KEY_F5:
			get_viewport().set_input_as_handled()
			manual_save()

func _create_music() -> void:
	var stream := load("res://assets/background_music.ogg") as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = -16
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	music.play()

func ask(title: String, body: String, options: Array) -> String:
	var previous_flow := flow
	flow = Flow.DECISION
	get_tree().paused = true
	menu.present(title, body, options)
	var choice: String = await menu.selected
	menu.hide()
	flow = previous_flow
	get_tree().paused = previous_flow in [Flow.TITLE, Flow.RESULT, Flow.PAUSED]
	return choice

func title_menu() -> void:
	flow = Flow.TITLE
	get_tree().paused = true
	hud.hide()
	if is_instance_valid(level):
		level.hide()
	title_screen.show()
	title_screen.refresh(_has_save())

func load_level(number: int, day: int, saved: Dictionary = {}) -> void:
	_discard_arena()
	get_tree().paused = false
	if is_instance_valid(level):
		level.stop_game()
		remove_child(level)
		level.queue_free()
	await get_tree().process_frame
	Economy.level_number = number
	Economy.current_day = day
	level = (LevelOne if number == 1 else LevelTwo).instantiate()
	level.name = "Level01" if number == 1 else "Level02"
	level.host = self
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.add_child(PlayerScene.instantiate())
	add_child(level)
	move_child(level, 0)
	level.day_started.connect(_on_day_started)
	level.night_started.connect(_on_night_started)
	level.game_finished.connect(_on_game_finished)
	title_screen.hide()
	hud.show()
	flow = Flow.PLAYING
	Economy.notify_money()
	level.start_game(day, 0, saved)

func _on_day_started(day: int) -> void:
	day_label.text = "LEVEL %d | DAY %d | OPEN" % [Economy.level_number, day]
	if music != null:
		music.volume_db = -16

func _on_night_started(day: int) -> void:
	day_label.text = "LEVEL %d  |  DAY %d  |  NIGHT" % [Economy.level_number, day]
	if music != null:
		music.volume_db = -22

func night_summary(active_level: Node2D) -> void:
	var final_night: bool = active_level.current_day == (3 if Economy.level_number == 1 else 7)
	while true:
		var wages: String = active_level.wages_message if Economy.level_number == 2 else ""
		var body := "Cash collected: [b]%d[/b]   |   Expenses paid: [b]%d[/b]\nCash collected minus expenses: [b]%d[/b]   |   New credit: %d\nBorrowed today: %d (not profit). %s\nKing: %d / %d   |   Wallet: %d   |   Business: %d   |   Loan due: %d" % [Economy.daily_income, Economy.daily_expenses, Economy.daily_income - Economy.daily_expenses, Economy.daily_credit, Economy.daily_borrowed, wages, Economy.king_chest, Economy.target(), Economy.wallet, Economy.business_box, Economy.loan_due]
		var choice := await ask("DAY %d  /  THE NIGHT LEDGER" % active_level.current_day, body, [
			{"id":"manage", "label":"Distribute money / manage the business"},
			{"id":"next", "label":"Finish this level" if final_night else "Rest and start the next day"}
		])
		if choice == "next":
			return
		await business_menu()

func business_menu() -> void:
	while true:
		var text := "Wallet: [b]%d[/b]   |   Business: [b]%d[/b]   |   King: [b]%d / %d[/b]\nSupplies and bills use business cash first, then your wallet.\nRoyal withdrawals lose 20%%. Loan repayments are due by day 7." % [Economy.wallet, Economy.business_box, Economy.king_chest, Economy.target()]
		if Economy.level_number == 2:
			text += "\nShow price %d | supplies 50 | staff %d x 120/night | loan due %d" % [Economy.ticket_price(), Economy.employees, Economy.loan_due]
		var options: Array = [
			{"id":"money", "label":"Move money: wallet / business / King's chest"}
		]
		if Economy.level_number == 2:
			options.append_array([
				{"id":"expand", "label":"Build stage 2: 600 | +120 per paid show", "disabled":Economy.second_stage or Economy.stage_broken or Economy.available() < 600},
				{"id":"hire", "label":"Hire goblin: +60 per show | wages 120/night", "disabled":not Economy.second_stage or Economy.stage_broken or Economy.employees >= 2},
				{"id":"loans", "label":"Loans: compare offers / repay debt"}
			])
		options.append({"id":"back", "label":"Back"})
		var choice := await ask("BUSINESS LEDGER", text, options)
		match choice:
			"back": return
			"money": await money_menu()
			"expand": Economy.expand()
			"hire": Economy.hire()
			"loans": await loan_menu()

func money_menu() -> void:
	while true:
		var text := "Wallet: %d   |   Business: %d   |   King: %d / %d\nKeep money for supplies, wages and emergencies before paying the King.\nScroll down to find withdrawals. Business withdrawals have no fee." % [Economy.wallet, Economy.business_box, Economy.king_chest, Economy.target()]
		var options: Array = [
			{"id":"back", "label":"Back to business ledger"},
			{"id":"king100", "label":"Wallet -> King's chest: 100", "disabled":Economy.wallet <= 0 or Economy.king_chest >= Economy.target()},
			{"id":"kingall", "label":"Wallet -> King's chest: as much as needed", "disabled":Economy.wallet <= 0 or Economy.king_chest >= Economy.target()},
			{"id":"business100", "label":"Wallet -> business reserve: 100", "disabled":Economy.wallet <= 0},
			{"id":"businessall", "label":"Wallet -> business reserve: all", "disabled":Economy.wallet <= 0},
			{"id":"withdraw", "label":"Business -> wallet: all (no fee)", "disabled":Economy.business_box <= 0}
		]
		if Economy.level_number == 2:
			options.append({"id":"royalwithdraw", "label":"King -> wallet: withdraw 100, receive 80", "disabled":Economy.king_chest <= 0})
		var choice := await ask("MOVE MONEY", text, options)
		match choice:
			"back": return
			"king100": Economy.transfer_to_king(100)
			"kingall": Economy.deposit_to_king()
			"business100": Economy.transfer_to_business(100)
			"businessall": Economy.deposit_to_business()
			"withdraw": Economy.withdraw_business(Economy.business_box)
			"royalwithdraw": Economy.withdraw_king(100)

func loan_menu() -> void:
	if not Economy.loan_kind.is_empty():
		var arrival := "Pending: arrives next morning." if Economy.bank_arrival_day > 0 else "Funds already received."
		var answer := await ask("YOUR LOAN AGREEMENT", "Lender: %s\nAmount still owed: %d. Due at the end of day 7.\n%s\nAvailable cash: %d" % [Economy.loan_kind, Economy.loan_due, arrival, Economy.available()], [
			{"id":"repay", "label":"Repay %d in full" % Economy.loan_due, "disabled":Economy.loan_due <= 0 or Economy.bank_arrival_day > 0 or Economy.available() < Economy.loan_due},
			{"id":"back", "label":"Back to the ledger"}
		])
		if answer == "repay":
			Economy.repay_loan()
		return
	var choice := await ask("LOOK AT THE TOTAL COST", "[b]Goblin Bank[/b]: receive 800 tomorrow. Interest 80. [b]Repay 880 total[/b].\n[b]Troll[/b]: receive 800 now. Interest 800. [b]Repay 1,600 total[/b].\nOne loan per campaign. Both are due by the end of day 7.\nBorrowing increases cash AND debt; it is not show income.", [
		{"id":"bank", "label":"Choose the Bank - arrives next morning", "disabled":Economy.current_day >= 7},
		{"id":"troll", "label":"Choose the Troll - cash immediately"},
		{"id":"back", "label":"Do not borrow"}
	])
	if choice != "back":
		Economy.take_loan(choice)

func pause_menu() -> void:
	if flow != Flow.PLAYING:
		return
	flow = Flow.PAUSED
	var safe: bool = level.is_save_safe()
	var body := "Save your day, location, health, cash, customers and business upgrades.\nContinue returns to this saved moment."
	if not safe:
		body += "\nFinish the current animation or story event before saving."
	var choice := await ask("PAUSED", body, [{"id":"resume", "label":"Resume"}, {"id":"save", "label":"Save Game", "disabled":not safe}, {"id":"save_exit", "label":"Save and Return to Title", "disabled":not safe}, {"id":"title", "label":"Return to Title (without saving)"}])
	if choice in ["save", "save_exit"]:
		if not save_game():
			await ask("SAVE FAILED", "Your previous save is still available. Check free space and folder access.", [{"id":"ok", "label":"Resume"}])
			choice = "resume"
	if choice in ["title", "save_exit"]:
		level.stop_game()
		title_menu()
	else:
		flow = Flow.PLAYING
		get_tree().paused = false

func load_save() -> void:
	var config := _read_save()
	if config == null:
		await ask("SAVE NOT AVAILABLE", "Start a New Game to create a compatible campaign save.", [{"id":"ok", "label":"Back"}])
		title_menu()
		return
	var saved: Dictionary = config.get_value("campaign", "economy")
	var world: Dictionary = config.get_value("campaign", "world")
	level_checkpoint = config.get_value("campaign", "level_start", saved)
	Economy.restore(saved)
	await load_level(Economy.level_number, int(world.day), world)
	toast("GAME LOADED - Day %d" % int(world.day))

func _remove_save() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _on_game_finished(victory: bool) -> void:
	if victory and Economy.level_number == 1:
		flow = Flow.RESULT
		await ask("A LETTER FROM THE KING", '"Not bad, dragon. Four days left."\nYou paid 1,200. Keep your remaining cash for supplies and expansion.\n[b]Real-life tip:[/b] add up every cost before setting your price.', [{"id":"next", "label":"Unlock Level 2 - Expand or Burn"}])
		Economy.level_number = 2
		Economy.current_day = 4
		level_checkpoint = Economy.snapshot()
		await load_level(2, 4)
	else:
		_end_game(victory)

func _end_game(victory: bool) -> void:
	if flow == Flow.RESULT:
		return
	flow = Flow.RESULT
	level.stop_game()
	var reason := "The King takes the cave: the royal payment is incomplete."
	if level.game_has_ended():
		reason = "Finny was defeated while defending the cave."
	elif Economy.loan_due > 0:
		reason = "Cave repossessed: the %s loan still needs %d coins." % [Economy.loan_kind, Economy.loan_due]
	var summary := "King: %d / %d | Loan due: %d | Fake coins spotted: %d\n" % [Economy.king_chest, Economy.target(), Economy.loan_due, Economy.scams_avoided]
	if victory:
		summary += 'Your goblins cheer. The King asks for a birthday show!\n[b]Dragon Entrepreneur of the Year[/b]\nScore: %d\n' % (Economy.king_chest + Economy.available() + Economy.scams_avoided * 100)
	else:
		summary += reason + "\n[b]Tip:[/b] keep emergency cash, check payments and compare total loan costs.\n"
	if testing_level_two:
		summary += "[i]Level 2 test run[/i]\n"
	for entry in Economy.decisions:
		summary += "• " + entry + "\n"
	var choice := await ask("CAVE SAVED!" if victory else "GAME OVER", summary, [
		{"id":"retry", "label":"Retry this level from its start"},
		{"id":"title", "label":"Return to title"}
	])
	if victory:
		_remove_save()
	if choice == "retry":
		Economy.restore(level_checkpoint)
		await load_level(Economy.level_number, Economy.current_day)
	else:
		await title_menu()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size", 5)
	hud.add_child(label)
	return label

func _layout_hud() -> void:
	var size := get_viewport_rect().size
	day_label.position = Vector2(340, 10)
	day_label.size = Vector2(size.x - 360, 30)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	details_label.position = Vector2(340, 47)
	details_label.size = Vector2(size.x - 360, 56)
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notice.position = Vector2(40, 112)
	notice.size = Vector2(size.x - 80, 40)
	$UI/PanelContainer.position = Vector2(0, size.y - 30)
	$UI/PanelContainer.size = Vector2(size.x, 30)
	hud_actions.position = Vector2(size.x - 410, size.y - 68)

func toast(message: String) -> void:
	notice.text = message
	notice_time = 6
	notice.show()

func open_ledger() -> void:
	if flow == Flow.PLAYING:
		await business_menu()

func _title_selected(choice: String) -> void:
	if flow != Flow.TITLE or transitioning:
		return
	transitioning = true
	match choice:
		"new":
			if _has_save():
				var answer := await ask("NEW GAME", "Starting a new campaign replaces your saved progress.", [{"id":"new", "label":"Start New Game"}, {"id":"back", "label":"Back"}])
				if answer == "back":
					transitioning = false
					return
			Economy.reset()
			_remove_save()
			level_checkpoint = Economy.snapshot()
			await play_intro()
			await load_level(1, 1)
		"continue":
			await load_save()
		"multiplayer":
			start_multiplayer()
		"quit":
			quit_game()
	transitioning = false

func play_intro() -> void:
	flow = Flow.INTRO
	get_tree().paused = true
	title_screen.hide()
	hud.hide()
	menu.hide()
	if music != null: music.volume_db = -25
	intro = preload("res://scenes/intro_story.tscn").instantiate()
	$MenuLayer.add_child(intro)
	await intro.finished
	$MenuLayer.remove_child(intro)
	intro.queue_free()
	intro = null
	if music != null: music.volume_db = -16

func start_multiplayer() -> void:
	_discard_arena()
	if is_instance_valid(level):
		level.stop_game()
		remove_child(level)
		level.queue_free()
		level = null
	flow = Flow.COOP
	get_tree().paused = false
	title_screen.hide()
	hud.hide()
	menu.hide()
	arena = preload("res://scenes/multiplayer_arena.tscn").instantiate()
	add_child(arena)
	arena.return_to_title.connect(_leave_multiplayer, CONNECT_DEFERRED)
	if music != null: music.volume_db = -16
	get_viewport().gui_release_focus()

func _discard_arena() -> void:
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
		arena = null

func _leave_multiplayer() -> void:
	_discard_arena()
	title_menu()

func manual_save() -> void:
	if flow != Flow.PLAYING:
		return
	if not level.is_save_safe():
		toast("Finish the current animation or event, then press F5 to save.")
		return
	if not save_game():
		toast("Save failed. Your previous save was kept.")

func autosave() -> void:
	if level.is_save_safe():
		save_game(false)

func save_game(show_notice: bool = true) -> bool:
	if not level.is_save_safe():
		return false
	var config := ConfigFile.new()
	config.set_value("campaign", "version", 3)
	config.set_value("campaign", "economy", Economy.snapshot())
	config.set_value("campaign", "world", level.get_save_progress())
	config.set_value("campaign", "level_start", level_checkpoint)
	var temp := SAVE_PATH + ".tmp"
	if config.save(temp) != OK:
		return false
	var path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), path) != OK:
		return false
	if show_notice:
		toast("GAME SAVED - Day %d" % level.current_day)
	return true

func _read_save() -> ConfigFile:
	for path in [SAVE_PATH, SAVE_PATH + ".bak"]:
		var config := ConfigFile.new()
		if config.load(path) != OK or config.get_value("campaign", "version", 0) != 3:
			continue
		var money = config.get_value("campaign", "economy", null)
		var world = config.get_value("campaign", "world", null)
		if not money is Dictionary or not world is Dictionary:
			continue
		var number := int(money.get("level_number", 0))
		var day := int(world.get("day", 0))
		if (number == 1 and day >= 1 and day <= 3) or (number == 2 and day >= 4 and day <= 7):
			return config
	return null

func _has_save() -> bool:
	return _read_save() != null

func _exit_tree() -> void:
	SoundFX.stop_all()
	if is_instance_valid(music):
		music.stop()
		music.stream = null

func quit_game() -> void:
	SoundFX.stop_all()
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	var deadline := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	get_tree().quit()
