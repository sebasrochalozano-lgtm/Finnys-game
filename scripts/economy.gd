extends Node

signal money_changed(wallet, business, king)

const GOAL: int = 1200
var wallet: int = 0
var business_box: int = 0
var king_chest: int = 0
var start_new_on_load: bool = false

func earn(amount: int) -> void:
	wallet += amount
	print("Wallet: ", wallet)
	money_changed.emit(wallet, business_box, king_chest)

func deposit_to_business() -> void:
	print("Deposit business: ", wallet)
	business_box += wallet
	wallet = 0
	money_changed.emit(wallet, business_box, king_chest)

func deposit_to_king() -> void:
	print("Deposit king: ", wallet)
	king_chest += wallet
	wallet = 0
	money_changed.emit(wallet, business_box, king_chest)

func reset() -> void:
	wallet = 0
	business_box = 0
	king_chest = 0
	money_changed.emit(wallet, business_box, king_chest)

func goal_reached() -> bool:
	return king_chest >= GOAL
