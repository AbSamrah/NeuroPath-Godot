extends AgentInterface # Ensure this base class extends CharacterBody2D in your project
class_name Robot

const RAY_COUNT: int = 200
const MAP_SIZE: float = 1000.0
var max_lidar_distance: float = MAP_SIZE * 0.2 

var _lidar_rays: Array[RayCast2D] = []
var goal_node: Node2D = null

@export var env_manager: Node
@export var ai_controller: RobotAIController

# --- Decoupled State Variable ---
var _current_action: Array[float] = [0.0, 0.0]

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

# --- Network Setter ---
func update_target_action(action: Array[float]) -> void:
	_current_action = action

# --- Continuous Physics & Reward Loop ---
func _physics_process(delta: float) -> void:
	if not is_instance_valid(ai_controller):
		return

	# 1. Apply the continuous time penalty 
	ai_controller.add_reward(-0.05)
	
	# 2. Map continuous [-1.0, 1.0] actions to kinematics
	var max_speed: float = 300.0
	var turn_speed: float = 5.0 
	
	var forward_input: float = _current_action[0]
	var steering_input: float = _current_action[1]
	
	rotation += steering_input * turn_speed * delta
	velocity = Vector2.RIGHT.rotated(rotation) * (forward_input * max_speed)
	
	# 3. Execute movement in real-time
	move_and_slide()
	
	# 4. Handle terminal collision states (Walls & Creatures)
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Ensure your static obstacles and creatures are assigned to these Godot groups
		if collider.is_in_group("obstacle") or collider.is_in_group("creature"):
			ai_controller.add_reward(-50.0)
			ai_controller.set_done(true)
			
			# MUST trigger the physical reset on crash
			if is_instance_valid(env_manager):
				env_manager.reset_episode()
			break# Break early to prevent multiple penalties in a single physics frame

# --- Goal Reached External Trigger ---
# Note: Connect your Goal Area2D's 'body_entered' signal to call this function
func trigger_goal_reached() -> void:
	if is_instance_valid(ai_controller):
		ai_controller.add_reward(100.0)
		ai_controller.set_done(true)
