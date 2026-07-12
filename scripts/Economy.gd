extends Node
## Autoload singleton. Owns money, upgrade levels, and the cost/value curves
## for the incremental loop. Tune the constants below to rebalance the game.

signal money_changed(new_amount: float)
signal upgrade_purchased

const TIER_NAMES: Array[String] = [
	"Mini Shredder",
	"Home Shredder",
	"Industrial Shredder",
	"Mega Shredder",
	"Titan Shredder",
]
const TIER_MULTIPLIERS: Array[float] = [1.0, 3.0, 8.0, 20.0, 50.0]
const MAX_TIER: int = 5  # keep in sync with TIER_NAMES / TIER_MULTIPLIERS length

const BASE_ITEM_VALUE: float = 5.0

const BASE_POWER_COST: float = 10.0
const POWER_COST_GROWTH: float = 1.15

const BASE_TIER_COST: float = 250.0
const TIER_COST_GROWTH: float = 4.0

var money: float = 0.0
var power_level: int = 1
var tier_level: int = 1


func reset() -> void:
	money = 0.0
	power_level = 1
	tier_level = 1
	money_changed.emit(money)


func add_money(amount: float) -> void:
	money += amount
	money_changed.emit(money)


func item_value() -> float:
	return BASE_ITEM_VALUE * power_level * TIER_MULTIPLIERS[tier_level - 1]


func power_upgrade_cost() -> float:
	return BASE_POWER_COST * pow(POWER_COST_GROWTH, power_level - 1)


func tier_upgrade_cost() -> float:
	if tier_level >= MAX_TIER:
		return -1.0
	return BASE_TIER_COST * pow(TIER_COST_GROWTH, tier_level - 1)


func can_afford(cost: float) -> bool:
	return cost >= 0.0 and money >= cost


func buy_power_upgrade() -> bool:
	var cost: float = power_upgrade_cost()
	if not can_afford(cost):
		return false
	money -= cost
	power_level += 1
	money_changed.emit(money)
	upgrade_purchased.emit()
	return true


func buy_tier_upgrade() -> bool:
	var cost: float = tier_upgrade_cost()
	if not can_afford(cost):
		return false
	money -= cost
	tier_level += 1
	power_level = 1
	money_changed.emit(money)
	upgrade_purchased.emit()
	return true


func current_tier_name() -> String:
	return TIER_NAMES[tier_level - 1]


func to_dict() -> Dictionary:
	return {
		"money": money,
		"power_level": power_level,
		"tier_level": tier_level,
	}


func from_dict(data: Dictionary) -> void:
	money = data.get("money", 0.0)
	power_level = data.get("power_level", 1)
	tier_level = data.get("tier_level", 1)
	money_changed.emit(money)
