extends Node3D
## Wires the MVP loop together: spawns junk items on a timer, listens for
## shredded items to award money, and keeps the HUD/shop buttons in sync
## with Economy state.

const BuildInfo := preload("res://scripts/BuildInfo.gd")

@export var item_scenes: Array[PackedScene] = []
@export var item_names: Array[String] = []
@export var spawn_interval: float = 1.5
@export var max_items_on_tray: int = 6

@onready var spawn_point: Marker3D = $ItemSpawner
@onready var conveyor_end: Marker3D = $ConveyorEnd
@onready var shredder_mouth: Area3D = $ShredderMouth
@onready var money_label: Label = $HUD/MoneyLabel
@onready var tier_label: Label = $HUD/TierLabel
@onready var build_label: Label = $HUD/BuildLabel
@onready var power_button: Button = $HUD/ShopPanel/PowerUpgradeButton
@onready var tier_button: Button = $HUD/ShopPanel/TierUpgradeButton
@onready var reset_button: Button = $HUD/ShopPanel/ResetButton
@onready var item_toggle_list: VBoxContainer = $HUD/ItemTogglePanel
@onready var spawn_timer: Timer = $SpawnTimer
@onready var ground_kill_zone: Area3D = $Ground/GroundKillZone

var _items_on_tray: int = 0
var _item_enabled: Array[bool] = []


func _ready() -> void:
	get_viewport().physics_object_picking = true
	build_label.text = "Build %d" % BuildInfo.BUILD_NUMBER

	SaveManager.load_game()

	Economy.money_changed.connect(_on_money_changed)
	Economy.upgrade_purchased.connect(_refresh_shop)
	shredder_mouth.item_shredded.connect(_on_item_shredded)
	power_button.pressed.connect(_on_power_button_pressed)
	tier_button.pressed.connect(_on_tier_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	ground_kill_zone.body_entered.connect(_on_ground_kill_zone_body_entered)

	_build_item_toggles()

	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()

	_on_money_changed(Economy.money)
	_refresh_shop()
	_spawn_item()


func _build_item_toggles() -> void:
	_item_enabled.resize(item_scenes.size())
	_item_enabled.fill(true)
	# Reuse the theme's actual Button background so the toggle rows visually
	# match the shop buttons instead of guessing a color by hand. Main is a
	# Node3D (no theme lookup of its own), so borrow it from a Control.
	var row_style: StyleBox = power_button.get_theme_stylebox("normal", "Button")
	for i in item_scenes.size():
		var label: String = item_names[i] if i < item_names.size() else "Item %d" % (i + 1)
		var check_box := CheckBox.new()
		check_box.text = label
		check_box.button_pressed = true
		check_box.toggled.connect(_on_item_toggled.bind(i))

		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", row_style)
		row.add_child(check_box)
		item_toggle_list.add_child(row)


func _on_item_toggled(pressed: bool, index: int) -> void:
	_item_enabled[index] = pressed


func _spawn_item() -> void:
	if _items_on_tray >= max_items_on_tray:
		return
	var enabled_indices: Array[int] = []
	for i in item_scenes.size():
		if _item_enabled[i]:
			enabled_indices.append(i)
	if enabled_indices.is_empty():
		return
	var chosen_scene: PackedScene = item_scenes[enabled_indices[randi() % enabled_indices.size()]]
	var item: ShreddableItem = chosen_scene.instantiate()
	add_child(item)
	# Rest the item's own collision bottom exactly on the belt surface — the
	# spawn marker sits AT that surface, so a bare offset of 0 would spawn
	# the item's center there, embedding half of it inside the belt's
	# collider and popping out violently the moment it's picked up.
	item.global_position = spawn_point.global_position + Vector3(
		randf_range(-0.3, 0.3), item.get_rest_height_offset() + 0.02, randf_range(-0.15, 0.15)
	)
	item.rotation.y = randf_range(0.0, TAU)
	# Same rest-height offset as the spawn position above — belt_target is
	# what move_toward() actually drives the item's Y toward too (it
	# interpolates all three axes, not just X/Z), so without this the item
	# would sink back down into the belt over the course of the ride even
	# though it spawned sitting correctly on top.
	item.belt_target = conveyor_end.global_position + Vector3(
		0.0, item.get_rest_height_offset() + 0.02, 0.0
	)
	item.tree_exited.connect(_on_item_removed)
	_items_on_tray += 1


func _on_item_removed() -> void:
	_items_on_tray -= 1


func _on_spawn_timer_timeout() -> void:
	_spawn_item()


func _on_item_shredded(_value: float) -> void:
	SaveManager.save_game()


func _on_ground_kill_zone_body_entered(body: Node3D) -> void:
	if body is ShreddableItem:
		body.queue_free()


func _on_money_changed(new_amount: float) -> void:
	money_label.text = "$ %.2f" % new_amount
	tier_label.text = Economy.current_tier_name()
	_refresh_shop()


func _on_power_button_pressed() -> void:
	Economy.buy_power_upgrade()


func _on_tier_button_pressed() -> void:
	Economy.buy_tier_upgrade()


func _on_reset_button_pressed() -> void:
	Economy.reset()
	SaveManager.save_game()
	get_tree().reload_current_scene()


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
