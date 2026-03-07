class_name AgentInterface extends CharacterBody2D

# Contract: Returns exactly 204 floats
func get_observations() -> Array[float]:
	push_error("AgentInterface: get_observations() not implemented.")
	return []

# Contract: Receives a length-2 array from the RL algorithm
func apply_action(_action: Array[float]) -> void:
	push_error("AgentInterface: apply_action() not implemented.")

# Contract: Resets kinematics
func reset_agent(_start_pos: Vector2) -> void:
	push_error("AgentInterface: reset_agent() not implemented.")
