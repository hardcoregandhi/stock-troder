class_name PlayerRole
extends RefCounted

const NONE := "NONE"
const HEDGIE := "HEDGIE"
const PENSION := "PENSION"
const REDDITOR := "REDDITOR"
const BELFORD := "BELFORD"
const INSIDER := "INSIDER"
const PLAYABLE := [HEDGIE, PENSION, REDDITOR, BELFORD, INSIDER]

# Roles only list values that differ from NONE.
const DEFINITIONS := {
	NONE: {
		"name": "Trader",
		"ability": "No special ability.",
		"tradeoff": "No drawback.",
		"option_premium_multiplier": 1.0,
		"fake_news_cost_pence": 7_500,
		"fake_news_strength": 1.0,
		"fake_news_success_chance": 0.55,
		"fake_news_backfire_chance": 0.20,
		"can_plant_news": true,
		"sees_planted_news": false,
		"daily_dividend_rate": 0.0,
	},
	HEDGIE: {
		"name": "Hedgie",
		"ability": "Calls and puts cost 40% less.",
		"tradeoff": "HYPE/FUD has half strength.",
		"option_premium_multiplier": 0.6,
		"fake_news_strength": 0.5,
	},
	PENSION: {
		"name": "Pension Fund",
		"ability": "Earns 1% of held share value at every close.",
		"tradeoff": "Calls and puts cost 50% more.",
		"option_premium_multiplier": 1.5,
		"daily_dividend_rate": 0.01,
	},
	REDDITOR: {
		"name": "Redditor",
		"ability": "HYPE/FUD costs £40.00.",
		"tradeoff": "HYPE/FUD is less reliable: 45% work, 30% backfire.",
		"fake_news_cost_pence": 4_000,
		"fake_news_success_chance": 0.45,
		"fake_news_backfire_chance": 0.30,
	},
	BELFORD: {
		"name": "Belford",
		"ability": "HYPE/FUD has 1.75x strength.",
		"tradeoff": "HYPE/FUD costs £120.00.",
		"fake_news_cost_pence": 12_000,
		"fake_news_strength": 1.75,
	},
	INSIDER: {
		"name": "Insider",
		"ability": "Sees which stories are planted HYPE or FUD.",
		"tradeoff": "Cannot plant HYPE/FUD.",
		"can_plant_news": false,
		"sees_planted_news": true,
	},
}

static func is_valid(role_id: String) -> bool:
	return DEFINITIONS.has(role_id)

static func value(role_id: String, key: String) -> Variant:
	var definition: Dictionary = DEFINITIONS.get(role_id, DEFINITIONS[NONE])
	return definition.get(key, DEFINITIONS[NONE][key])

static func display_name(role_id: String) -> String:
	return str(value(role_id, "name"))

static func summary(role_id: String) -> String:
	return "%s: %s Drawback: %s" % [display_name(role_id), str(value(role_id, "ability")), str(value(role_id, "tradeoff"))]
