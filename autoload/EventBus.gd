extends Node

# Fisico & Strutturale
signal block_damaged(block: Node3D, amount: float, hit_pos: Vector3, normal: Vector3)
signal block_destroyed(block: Node3D, by_gravity: bool, material_data: MaterialData, pos: Vector3)
signal chain_collapse_triggered(count: int, total_mass: float)
signal debris_registered(debris_node: RigidBody3D)
signal debris_despawned(debris_node: RigidBody3D, value_credited: float)

# Economia & Progressione
signal currency_changed(new_amount: float, delta: float)
signal contract_progress_updated(ratio: float, destroyed_mass: float, total_mass: float)
signal contract_completed(contract_data: ContractData)
signal contract_selected(contract_data: ContractData)
signal upgrade_purchased(upgrade_id: StringName, new_level: int, current_cost: float)
signal tool_unlocked(tool_id: StringName)
signal tool_equipped(tool_data: ToolData)
signal tier_unlocked(tier: int)
signal prestige_performed(prestige_count: int, permanent_multiplier: float)

# Game Feel & Feedback
signal request_camera_shake(trauma_amount: float)
signal request_hitstop(duration_seconds: float)
signal show_floating_text(text: String, world_pos: Vector3, color: Color)
signal show_notification(message: String, color: Color)
