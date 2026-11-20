extends Node

# Eventi di distruzione e fisica
signal block_damaged(block: Node3D, amount: float, hit_position: Vector3, normal: Vector3)
signal block_ricochet(block: Node3D, hit_position: Vector3, normal: Vector3, required_tier: int)
signal block_destroyed(block: Node3D, by_gravity: bool)
signal chain_collapse_triggered(blocks_count: int, total_mass_kg: float)
signal explosion_triggered(world_pos: Vector3, radius: float)
signal floor_cleared(floor_index: int, floor_name: String, bonus_money: float)

# Eventi di economia e progressione
signal currency_changed(new_amount: float, delta: float)
signal upgrade_purchased(upgrade_id: StringName, new_level: int, cost: float)
signal tool_unlocked(tool_id: StringName)
signal tool_equipped(tool_data: Resource)
signal tool_swung(tool_data: Resource)
signal tier_unlocked(new_tier: int)
signal difficulty_changed(difficulty_id: String)

# Eventi di gioco e contratti
signal contract_selected(contract_data: Resource)
signal contract_progress_updated(ratio: float, destroyed_mass: float, total_mass: float)
signal contract_threshold_reached(contract_data: Resource)
signal contract_completed(contract_data: Resource)
signal prestige_performed(new_prestige_count: int, new_multiplier: float)
signal game_state_changed(state_name: String)

# Eventi UI / HUD / Impostazioni / Audio
signal show_floating_text(text: String, world_pos: Vector3, color: Color)
signal show_notification(message: String, color: Color)
signal target_block_hovered(block: Node3D)
signal explosives_count_changed(count: int)
signal settings_changed()
signal ui_click()
signal ui_error()
