extends Node

signal money_changed(wallet, business, king)

const GOAL: int = 1200
const FINAL_GOAL: int = 5000
const SHOW_COST: int = 50
const EXPANSION_COST: int = 600
const WAGE: int = 120

var wallet: int = 0
var business_box: int = 0
var king_chest: int = 0
var start_new_on_load: bool = false
var level_number: int = 1
var current_day: int = 1
var second_stage: bool = false
var stage_broken: bool = false
var employees: int = 0
var loan_kind: String = ""
var loan_due: int = 0
var bank_arrival_day: int = 0
var receivables: Array = []
var daily_income: int = 0
var daily_expenses: int = 0
var daily_borrowed: int = 0
var daily_credit: int = 0
var decisions: Array[String] = []
var shows_completed: int = 0
var scams_avoided: int = 0
var credit_losses: int = 0

func notify_money() -> void:
	money_changed.emit(wallet, business_box, king_chest)

func target() -> int:
	return GOAL if level_number == 1 else FINAL_GOAL

func available() -> int:
	return wallet + business_box

func earn(amount: int) -> void:
	wallet += maxi(amount, 0)
	daily_income += maxi(amount, 0)
	notify_money()

func transfer_to_king(amount: int) -> void:
	var moved := mini(mini(maxi(amount, 0), wallet), maxi(target() - king_chest, 0))
	wallet -= moved
	king_chest += moved
	notify_money()

func transfer_to_business(amount: int) -> void:
	var moved := mini(maxi(amount, 0), wallet)
	wallet -= moved
	business_box += moved
	notify_money()

func deposit_to_business() -> void:
	transfer_to_business(wallet)

func deposit_to_king() -> void:
	transfer_to_king(wallet)

func withdraw_business(amount: int) -> void:
	var moved := mini(maxi(amount, 0), business_box)
	business_box -= moved
	wallet += moved
	notify_money()

func withdraw_king(amount: int) -> void:
	var moved := mini(maxi(amount, 0), king_chest)
	var penalty := ceili(moved * 0.2)
	king_chest -= moved
	wallet += moved - penalty
	daily_expenses += penalty
	decisions.append("Royal withdrawal: %d coins lost to the 20%% penalty." % penalty)
	notify_money()

func spend(amount: int) -> bool:
	if amount < 0 or available() < amount:
		return false
	var from_business := mini(business_box, amount)
	business_box -= from_business
	wallet -= amount - from_business
	daily_expenses += amount
	notify_money()
	return true

func pay_show_cost() -> bool:
	return true if level_number == 1 else spend(SHOW_COST)

func ticket_price() -> int:
	if level_number == 1:
		return 100
	return 200 + (120 if second_stage and not stage_broken else 0) + employees * 60

func finish_show(amount: int, payment_mode: String) -> void:
	shows_completed += 1
	if payment_mode == "credit":
		receivables.append({"amount": amount, "day": current_day + 1})
		daily_credit += amount
		decisions.append("Day %d: granted credit of %d, due the next morning." % [current_day, amount])
	elif payment_mode == "fake":
		decisions.append("Day %d: accepted a chocolate coin; no payment received." % current_day)
	else:
		earn(amount)

func start_day(day: int) -> void:
	current_day = day
	daily_income = 0
	daily_expenses = 0
	daily_borrowed = 0
	daily_credit = 0
	if bank_arrival_day > 0 and day >= bank_arrival_day:
		business_box += 800
		daily_borrowed += 800
		bank_arrival_day = 0
		decisions.append("Day %d: the Goblin Bank delivered 800 coins." % day)
	var pending: Array = []
	for payment in receivables:
		if int(payment.day) <= day:
			earn(int(payment.amount))
		else:
			pending.append(payment)
	receivables = pending
	notify_money()

func take_loan(kind: String) -> bool:
	if not loan_kind.is_empty() or (kind == "bank" and current_day >= 7):
		return false
	if kind != "bank" and kind != "troll":
		return false
	loan_kind = kind
	if kind == "bank":
		loan_due = 880
		bank_arrival_day = current_day + 1
		decisions.append("Bank loan: borrow 800, repay 880. Arrives next morning.")
	else:
		loan_due = 1600
		business_box += 800
		daily_borrowed += 800
		decisions.append("Troll loan: borrow 800 now, repay 1600 on day 7.")
	notify_money()
	return true

func repay_loan() -> bool:
	if loan_due == 0 or bank_arrival_day > 0 or not spend(loan_due):
		return false
	decisions.append("Repaid the %s loan: %d coins." % [loan_kind, loan_due])
	loan_due = 0
	return true

func expand() -> bool:
	if second_stage or stage_broken or not spend(EXPANSION_COST):
		return false
	second_stage = true
	decisions.append("Built a second stage for 600; +120 income per paid show.")
	return true

func hire() -> bool:
	if not second_stage or employees >= 2 or stage_broken:
		return false
	employees += 1
	decisions.append("Hired a goblin: +60 income per show; 120 wages every night.")
	return true

func pay_wages() -> String:
	var amount := employees * WAGE
	if amount == 0:
		return "No employees to pay."
	if spend(amount):
		return "Paid %d in goblin wages." % amount
	decisions.append("Employees resigned: not enough cash for %d in wages." % amount)
	employees = 0
	return "The goblins resigned: their %d wages were not paid." % amount

func repair_stage() -> bool:
	if not stage_broken or not spend(400):
		return false
	stage_broken = false
	decisions.append("Paid 400 from available cash to repair after the Royal Hero attack.")
	return true

func goal_reached() -> bool:
	return king_chest >= target() and (level_number == 1 or loan_due == 0)

func snapshot() -> Dictionary:
	return {
		"daily_income":daily_income, "daily_expenses":daily_expenses, "daily_borrowed":daily_borrowed, "daily_credit":daily_credit,
		"wallet": wallet, "business_box": business_box, "king_chest": king_chest,
		"level_number": level_number, "current_day": current_day,
		"second_stage": second_stage, "stage_broken": stage_broken,
		"employees": employees, "loan_kind": loan_kind, "loan_due": loan_due,
		"bank_arrival_day": bank_arrival_day, "receivables": receivables.duplicate(true),
		"decisions": decisions.duplicate(), "shows_completed": shows_completed,
		"scams_avoided": scams_avoided, "credit_losses": credit_losses
	}

func restore(data: Dictionary) -> void:
	wallet = int(data.get("wallet", 0))
	business_box = int(data.get("business_box", 0))
	king_chest = int(data.get("king_chest", 0))
	level_number = int(data.get("level_number", 1))
	current_day = int(data.get("current_day", 1))
	second_stage = bool(data.get("second_stage", false))
	stage_broken = bool(data.get("stage_broken", false))
	employees = int(data.get("employees", 0))
	loan_kind = str(data.get("loan_kind", ""))
	loan_due = int(data.get("loan_due", 0))
	bank_arrival_day = int(data.get("bank_arrival_day", 0))
	receivables = data.get("receivables", []).duplicate(true)
	decisions.assign(data.get("decisions", []))
	shows_completed = int(data.get("shows_completed", 0))
	scams_avoided = int(data.get("scams_avoided", 0))
	credit_losses = int(data.get("credit_losses", 0))
	daily_income = int(data.get("daily_income", 0))
	daily_expenses = int(data.get("daily_expenses", 0))
	daily_borrowed = int(data.get("daily_borrowed", 0))
	daily_credit = int(data.get("daily_credit", 0))
	notify_money()

func reset() -> void:
	restore({})
