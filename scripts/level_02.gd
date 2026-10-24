extends "res://scripts/level_01.gd"
const HeroScene = preload("res://level/costumers/royal_hero.tscn")
const StageScript = preload("res://scripts/business_stage.gd")
func get_level_number() -> int:
	return 2
func _ready() -> void:
	daily_customer_counts.assign([6, 7, 7, 8])
	super._ready()
	stage = Node2D.new()
	stage.set_script(StageScript)
	stage.name = "BusinessStage"
	stage.position = extent * Vector2(0.65, 0.80)
	add_child(stage)
func day_events() -> void:
	phase = Phase.EVENT
	if current_day == 4:
		await host.ask("LEVEL 2 / EXPAND OR BURN", "Four days remain. Pay the King [b]5,000 in total[/b]; your earlier payments count.\nShows earn 200 and cost 50. Build a second stage and hire staff to earn more.\nCompare loans, check payments, limit credit and keep 400 for emergencies.", [{"id":"ok", "label":"Review the business ledger"}])
	await host.business_menu()
	if current_day == 6:
		var can_open: bool = await royal_attack()
		if not can_open:
			next_customer = day_customer_count
func before_customer(index: int) -> String:
	if Economy.available() < Economy.SHOW_COST:
		await host.ask("SUPPLIES ARE RUNNING LOW", "Each show needs 50 coins. Use your business reserve or wallet.\nThe King's chest is locked; withdrawals cost 20%.", [{"id":"ok", "label":"Manage the business"}])
		await host.business_menu()
		if Economy.available() < Economy.SHOW_COST:
			Economy.decisions.append("Day %d: closed early; no cash for supplies." % current_day)
			return "closed"
	if index == 1:
		return await credit_event()
	if index == 3 and current_day in [5, 7]:
		return await coin_event()
	return "cash"

func credit_event() -> String:
	var price := Economy.ticket_price()
	var deadline_note := "Tomorrow is after the King's deadline!" if current_day == 7 else "Payment arrives tomorrow; supplies cost 50 today."
	var answer: String = await host.ask("THE KNIGHT ASKS FOR CREDIT", '"Let me enjoy the show. I will pay tomorrow!"\n%s\n[b]Ticket: %d   |   Pending credit: %d customers[/b]' % [deadline_note, price, Economy.receivables.size()], [
		{"id":"cash", "label":"Ask for cash now - he agrees"},
		{"id":"credit", "label":"Allow one show on credit", "disabled":Economy.receivables.size() >= 2},
		{"id":"skip", "label":"Decline this customer"}
	])
	return answer

func coin_event() -> String:
	var answer: String = await host.ask("A STRANGE GOLD COIN", "An adventurer offers a coin wrapped in shiny gold foil.\nCheck the payment before spending money on a show.", [
		{"id":"check", "label":"Inspect the coin before the show"},
		{"id":"fake", "label":"Trust the adventurer and accept it"}
	])
	if answer == "check":
		Economy.scams_avoided += 1
		Economy.decisions.append("Day %d: detected a chocolate coin before spending on supplies." % current_day)
		await host.ask("CHOCOLATE, NOT GOLD", "You caught the fake coin. The adventurer leaves.\nYou lose this sale, but keep the 50 coins for supplies.", [{"id":"ok", "label":"Keep the business open"}])
		return "skip"
	return "fake"

func royal_attack() -> bool:
	await host.ask("DAY 6  /  THE ROYAL HERO", "The King's champion is coming for your stage!\nGet close, face him and press [b]R[/b] to defend it.\nIf he succeeds, reopening costs [b]400[/b].", [{"id":"defend", "label":"Defend the cave"}])
	var hero = HeroScene.instantiate()
	hero.position = spawn_point.position
	hero.destination = extent * Vector2(0.65, 0.80)
	add_child(hero)
	var destroyed: bool = await hero.raid_finished
	if not destroyed:
		Economy.decisions.append("Day 6: defeated the Royal Hero and protected the stage.")
		await host.ask("THE STAGE IS SAFE", "Finny drove away the Royal Hero. Your emergency savings are intact.", [{"id":"ok", "label":"Welcome today's customers"}])
		return true
	while Economy.stage_broken:
		var choice: String = await host.ask("THE STAGE IS BROKEN", "Reopen now for 400, or rebuild it yourself and lose today's customers.\nAvailable cash: %d   |   King's chest: %d (locked)" % [Economy.available(), Economy.king_chest], [
			{"id":"repair", "label":"Spend 400 and reopen now", "disabled":Economy.available() < 400},
			{"id":"manage", "label":"Manage money and loans"},
			{"id":"close", "label":"Rebuild overnight - lose all day 6 customers"}
		])
		if choice == "repair":
			Economy.repair_stage()
		elif choice == "manage":
			await host.business_menu()
		else:
			Economy.stage_broken = false
			Economy.decisions.append("Day 6: rebuilt the stage personally; lost a full day of sales.")
			return false
	return true

