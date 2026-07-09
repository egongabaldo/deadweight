extends Node3D
## Wires the MVP loop together: spawns junk items on a timer, listens for
## shredded items to award money, and keeps the HUD/shop buttons in sync
## with Economy state.

@export var item_scene: PackedScene
@export var spawn_interval: float = 1.5
@export var max_items_on_tray: int = 6

@onready var spawn_point: Marker3D = $ItemSpawner
@onready var conveyor_end: Marker3D = $ConveyorEnd
@onready var shredder_mouth: Area3D = $ShredderMouth
@onready var money_label: Label = $HUD/MoneyLabel
@onready var tier_label: Label = $HUD/TierLabel
@onready var power_button: Button = $HUD/ShopPanel/PowerUpgradeButton
@onready var tier_button: Button = $HUD/ShopPanel/TierUpgradeButton
@onready var spawn_timer: Timer = $SpawnTimer

var _items_on_tray: int = 0


func _ready() -> void:
	get_viewport().physics_object_picking = true

	SaveManager.load_game()

	Economy.money_changed.connect(_on_money_changed)
	Economy.upgrade_purchased.connect(_refresh_shop)
	shredder_mouth.item_shredded.connect(_on_item_shredded)
	power_button.pressed.connect(_on_power_button_pressed)
	tier_button.pressed.connect(_on_tier_button_pressed)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()

	_on_money_changed(Economy.money)
	_refresh_shop()
	_spawn_item()


func _spawn_item() -> void:
	if item_scene == null or _items_on_tray >= max_items_on_tray:
		return
	var item: ShreddableItem = item_scene.instantiate()
	add_child(item)
	item.global_position = spawn_point.global_position + Vector3(
		0.0, 0.0, randf_range(-0.15, 0.15)
	)
	item.belt_target = conveyor_end.global_position
	item.tree_exited.connect(_on_item_removed)
	_items_on_tray += 1


func _on_item_removed() -> void:
	_items_on_tray -= 1


func _on_spawn_timer_timeout() -> void:
	_spawn_item()


func _on_item_shredded(_value: float) -> void:
	SaveManager.save_game()


func _on_money_changed(new_amount: float) -> void:
	money_label.text = "$ %.2f" % new_amount
	tier_label.text = Economy.current_tier_name()
	_refresh_shop()


func _on_power_button_pressed() -> void:
	Economy.buy_power_upgrade()


func _on_tier_button_pressed() -> void:
	Economy.buy_tier_upgrade()


func _refresh_shop() -> void:
	var power_cost: float = Economy.power_upgrade_cost()
	power_button.text = "Upgrade Power (Lv %d)\n$ %.2f" % [Economy.power_level, power_cost]
	power_button.disabled = not Economy.can_afford(power_cost)

	var tier_cost: float = Economy.tier_upgrade_cost()
	if tier_cost < 0.0:
		tier_button.text = "MAX TIER"
		tier_button.disabled = true
	else:
		tier_button.text = "Upgrade Shredder (Tier %d)\n$ %.2f" % [Economy.tier_level, tier_cost]
		tier_button.disabled = not Economy.can_afford(tier_cost)
