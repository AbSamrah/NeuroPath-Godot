extends AIController2D
class_name RobotAIController

@onready var robot: Robot = $".." 
@onready var env_manager: EnvironmentManager = get_node("/root/World/EnvironmentManager") 

# --- Internal State for RL Synchronization ---
var _current_reward: float = 0.0
var _is_done: bool = false

func _ready() -> void:
	super._ready()

func get_obs() -> Dictionary:
	var obs_array: Array[float] = robot.get_observations()
	return {"obs": obs_array}

func get_action_space() -> Dictionary:
	return {
		"action": {
			"size": 2,
			"action_type": "continuous"
		}
	}

func set_action(action: Dictionary) -> void:
	var continuous_action: Array = action["action"]
	var formatted_action: Array[float] = [float(continuous_action[0]), float(continuous_action[1])]
	
	# ONLY update the target action. Do not execute movement here.
	robot.update_target_action(formatted_action)

# --- Reward & Done Overrides (The Zero Reward Fix) ---

# Godot RL calls this when Python requests a step update.
func get_reward() -> float:
	var r: float = _current_reward
	_current_reward = 0.0 # Reset only after Python has safely read it
	return r

# Godot RL calls this to check if the episode should terminate.
func get_done() -> bool:
	var d: bool = _is_done
	_is_done = false # Reset only after Python has safely read it
	return d

# --- Helper functions to be called by robot.gd or environment_manager.gd ---

func add_reward(amount: float) -> void:
	# Accumulate reward in case multiple physics frames pass between Python steps
	_current_reward += amount

func set_done(done: bool) -> void:
	_is_done = done
