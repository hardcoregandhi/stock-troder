class_name OptionContract
extends RefCounted

const CALL := "CALL"
const PUT := "PUT"

var option_type: String
var symbol: String
var strike_price_pence: int
var premium_pence: int
var quantity: int
var opened_day: int

func _init(new_type: String, new_symbol: String, new_strike: int, new_premium: int, new_quantity: int, new_day: int) -> void:
	option_type = new_type
	symbol = new_symbol
	strike_price_pence = new_strike
	premium_pence = new_premium
	quantity = new_quantity
	opened_day = new_day

func payoff_pence(closing_price_pence: int) -> int:
	var intrinsic_value := maxi(0, closing_price_pence - strike_price_pence) if option_type == CALL else maxi(0, strike_price_pence - closing_price_pence)
	return intrinsic_value * quantity

func to_dictionary() -> Dictionary:
	return {
		"type": option_type,
		"symbol": symbol,
		"strike_price_pence": strike_price_pence,
		"premium_pence": premium_pence,
		"quantity": quantity,
		"opened_day": opened_day,
	}
