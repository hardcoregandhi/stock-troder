class_name RunSetupService
extends RefCounted

const STARTING_STAKE_TARGET_PENCE: int = 30_000
const COOPERATIVE_FLOOR_RATIO: float = 0.8
const COOPERATIVE_TARGET_RATIO: float = 1.15
const COOPERATIVE_REWARD_PENCE: int = 10_000
const MARKET_CRASH_PERCENT: float = 0.15

# Deals role, home stake, and personal goals. Uses its own stream so market rolls stay unchanged.
static func deal_starting_hand(state: GameState, run_seed: int, player_index: int, role_id: String) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = run_seed * 92_821 + player_index * 7_919 + 17
	state.role = role_id if PlayerRole.is_valid(role_id) else PlayerRole.NONE
	var home := _home_stock(state, random, player_index)
	state.home_symbol = home.symbol
	state.grant_starting_shares(home.symbol, maxi(1, STARTING_STAKE_TARGET_PENCE / home.current_price_pence))
	state.goals = PlayerGoals.deal(state, random)

static func cooperative_goal(state: GameState, run_seed: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = run_seed * 31 + 5
	var stock: StockData = state.stocks[random.randi_range(0, state.stocks.size() - 1)]
	return {
		"symbol": stock.symbol,
		"start_price_pence": stock.current_price_pence,
		"floor_ratio": COOPERATIVE_FLOOR_RATIO,
		"floor_pence": roundi(float(stock.current_price_pence) * COOPERATIVE_FLOOR_RATIO),
		"target_pence": roundi(float(stock.current_price_pence) * COOPERATIVE_TARGET_RATIO),
		"reward_pence": COOPERATIVE_REWARD_PENCE,
		"crash_percent": MARKET_CRASH_PERCENT,
		"crash_count": 0,
	}

static func network_roles(run_seed: int, player_count: int) -> Array[String]:
	var random := RandomNumberGenerator.new()
	random.seed = run_seed * 13 + 3
	var deck: Array = PlayerRole.PLAYABLE.duplicate()
	var roles: Array[String] = []
	for index in player_count:
		if deck.is_empty():
			deck = PlayerRole.PLAYABLE.duplicate()
		roles.append(str(deck.pop_at(random.randi_range(0, deck.size() - 1))))
	return roles

static func _home_stock(state: GameState, random: RandomNumberGenerator, player_index: int) -> StockData:
	var candidates: Array[StockData] = []
	for stock in state.stocks:
		if stock.current_price_pence <= STARTING_STAKE_TARGET_PENCE:
			candidates.append(stock)
	if candidates.is_empty():
		candidates.append(state.stocks[0])
	return candidates[(random.randi_range(0, candidates.size() - 1) + player_index) % candidates.size()]
