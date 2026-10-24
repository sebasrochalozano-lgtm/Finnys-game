extends CanvasLayer

@onready var wallet_label: Label = $LabelWallet
@onready var business_label: Label = $LabelBusinnes
@onready var king_label: Label = $LabelKing

func _ready() -> void:
	Economy.money_changed.connect(_update)
	_update(Economy.wallet, Economy.business_box, Economy.king_chest)

func _update(wallet: int, business: int, king: int) -> void:
	wallet_label.text = "Wallet: " + str(wallet)
	business_label.text = "Business box: " + str(business)
	king_label.text = "King's chest: " + str(king) + " / " + str(Economy.target())
