extends AIController2D
class_name RobotAIController

@onready var robot: Robot = $".." 
@onready var env_manager: EnvironmentManager = get_node("/root/World/EnvironmentManager") 

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
	
	robot.apply_action(formatted_action)

