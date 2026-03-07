extends AgentInterface
class_name Robot

const RAY_COUNT: int = 200
const MAP_SIZE: float = 1000.0
var max_lidar_distance: float = MAP_SIZE * 0.2 

var _lidar_rays: Array[RayCast2D] = []
var goal_node: Node2D = null

@export var env_manager: EnvironmentManager
@export var ai_controller: Node2D

func _ready() -> void:
	var angle_step: float = TAU / float(RAY_COUNT) 
	
	for i in range(RAY_COUNT):
		var ray: RayCast2D = RayCast2D.new()
		
		var direction: Vector2 = Vector2(cos(i * angle_step), sin(i * angle_step))
		ray.target_position = direction * max_lidar_distance
		
		ray.collide_with_bodies = true
		ray.collide_with_areas = false
		
		add_child(ray)
		_lidar_rays.append(ray)

func get_observations() -> Array[float]:
	var obs: Array[float] = []
	obs.resize(204)
	
	for i in range(RAY_COUNT):
		if _lidar_rays[i].is_colliding():
			var distance: float = global_position.distance_to(_lidar_rays[i].get_collision_point())
			obs[i] = distance / max_lidar_distance
		else:
			obs[i] = 1.0 
			
	obs[200] = global_position.x / MAP_SIZE
	obs[201] = global_position.y / MAP_SIZE
	
	if is_instance_valid(goal_node):
		obs[202] = goal_node.global_position.x / MAP_SIZE
		obs[203] = goal_node.global_position.y / MAP_SIZE
	else:
		obs[202] = 0.0
		obs[203] = 0.0
		
	return obs

func apply_action(action: Array[float]) -> void:
	var max_speed: float = 300.0
	var input_velocity: Vector2 = Vector2(action[0], action[1])
	
	if input_velocity.length() > 1.0:
		input_velocity = input_velocity.normalized()
		
	velocity = input_velocity * max_speed
	move_and_slide()
	
	if is_instance_valid(env_manager) and is_instance_valid(ai_controller):
		var state: Dictionary = env_manager.step_environment()
		
		ai_controller.reward = state["reward"]
		ai_controller.done = state["done"]
		
		if state["done"] == true:
			env_manager.reset_episode()

func reset_agent(start_pos: Vector2) -> void:
	global_position = start_pos
	velocity = Vector2.ZERO
