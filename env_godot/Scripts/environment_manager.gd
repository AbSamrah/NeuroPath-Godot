class_name EnvironmentManager extends Node

# --- Environment Constants ---
const MAP_SIZE: float = 1000.0
const CREATURE_SPEED: float = 150.0
const ORBIT_RADIUS: float = 100.0
const ORBIT_SPEED: float = 1.5 

# --- Node References ---
@export var robot: Robot
@export var goal: Area2D

# --- Curriculum Learning Variables ---
@export var current_static_count: int = 0
@export var current_roam_count: int = 0
@export var spawn_orbit_creature: bool = false 

var _consecutive_wins: int = 0
var _curriculum_level: int = 0

@export var max_steps_per_episode: int = 2000
var _current_steps: int = 0

# --- Packed Scenes (Prefabs to spawn) ---
@export var static_obstacle_scene: PackedScene
@export var roam_creature_scene: PackedScene
@export var orbit_creature_scene: PackedScene

# --- Internal State ---
var _active_obstacles: Array[Node2D] = []
var _orbit_creature_ref: CharacterBody2D = null
var _roaming_creatures: Array[CharacterBody2D] = []

var _orbit_angle: float = 0.0
var _roam_targets: Dictionary = {} 

func _ready() -> void:
	if is_instance_valid(robot) and is_instance_valid(goal):
		robot.goal_node = goal

func _physics_process(delta: float) -> void:
	_update_dynamic_entities(delta)


func reset_episode() -> void:
	_current_steps = 0
	
	_check_curriculum_progression()
	_clear_obstacles()
	
	goal.global_position = _get_random_valid_position()
	
	var robot_start: Vector2 = _get_random_valid_position()
	while robot_start.distance_to(goal.global_position) < 200.0:
		robot_start = _get_random_valid_position()
	robot.reset_agent(robot_start)
	
	var safe_distance: float = 120.0 
	
	for i in range(current_static_count):
		var obs_pos: Vector2 = _get_random_valid_position()
		
		while obs_pos.distance_to(robot_start) < safe_distance or obs_pos.distance_to(goal.global_position) < safe_distance:
			obs_pos = _get_random_valid_position()
			
		_spawn_entity(static_obstacle_scene, obs_pos)
		
	for i in range(current_roam_count):
		var roam_pos: Vector2 = _get_random_valid_position()
		while roam_pos.distance_to(robot_start) < safe_distance:
			roam_pos = _get_random_valid_position()
			
		var roamer = _spawn_entity(roam_creature_scene, roam_pos)
		if roamer is CharacterBody2D:
			_roaming_creatures.append(roamer)
			_roam_targets[roamer] = _get_random_valid_position()
		
	if spawn_orbit_creature and is_instance_valid(orbit_creature_scene):
		_orbit_creature_ref = orbit_creature_scene.instantiate()
		_orbit_angle = 0.0
		
		var initial_orbit_pos: Vector2 = goal.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * ORBIT_RADIUS
		_orbit_creature_ref.global_position = initial_orbit_pos
		
		add_child(_orbit_creature_ref)
		_active_obstacles.append(_orbit_creature_ref)

func _clear_obstacles() -> void:
	for obs in _active_obstacles:
		if is_instance_valid(obs):
			obs.queue_free()
	_active_obstacles.clear()
	_roaming_creatures.clear()
	_roam_targets.clear()
	_orbit_creature_ref = null

func _spawn_entity(scene_prefab: PackedScene, spawn_pos: Vector2) -> Node2D:
	if not is_instance_valid(scene_prefab):
		return null
		
	var entity = scene_prefab.instantiate()
	entity.global_position = spawn_pos
	add_child(entity)
	_active_obstacles.append(entity)
	return entity

func step_environment() -> Dictionary:
	var is_terminated: bool = false
	var reward: float = -0.05 
	
	
	if robot.global_position.distance_to(goal.global_position) < 40.0:
		_consecutive_wins += 1
		return {"done": true, "reward": 100.0}
	
	if _current_steps >= max_steps_per_episode:
		_consecutive_wins = 0
		return {"done": true, "reward": -50.0}
		
	if robot.get_slide_collision_count() > 0:
		is_terminated = true
		_consecutive_wins = 0
		var collision = robot.get_last_slide_collision()
		var collider = collision.get_collider()
		
		if collider.is_in_group("walls"):
			reward = -50.0
		elif collider.is_in_group("static_obstacles"):
			reward = -75.0
		elif collider is CharacterBody2D: 
			reward = -150.0
		else:
			reward = -100.0 
			
		return {"done": is_terminated, "reward": reward}
		
	return {"done": is_terminated, "reward": reward}


func _check_curriculum_progression() -> void:
	if _consecutive_wins >= 20:
		_consecutive_wins = 0
		_curriculum_level += 1
		print("Curriculum Level Up! Now at level: ", _curriculum_level)
		
		match _curriculum_level:
			1:
				current_static_count = 5
			2:
				current_static_count = 10
			3:
				current_roam_count = 1   
			4:
				current_roam_count = 3   
			5:
				spawn_orbit_creature = true 


func _update_dynamic_entities(delta: float) -> void:
	_update_orbit_creature(delta)
	_update_roam_creatures(delta)

func _update_orbit_creature(delta: float) -> void:
	if not is_instance_valid(_orbit_creature_ref):
		return
		
	_orbit_angle += ORBIT_SPEED * delta
	if _orbit_angle >= TAU:
		_orbit_angle -= TAU
		
	var offset: Vector2 = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * ORBIT_RADIUS
	_orbit_creature_ref.global_position = goal.global_position + offset

func _update_roam_creatures(_delta: float) -> void:
	for roamer in _roaming_creatures:
		if not is_instance_valid(roamer):
			continue
			
		var target: Vector2 = _roam_targets[roamer]
		var direction: Vector2 = roamer.global_position.direction_to(target)
		var distance_to_target: float = roamer.global_position.distance_to(target)
		
		if distance_to_target < 10.0:
			_roam_targets[roamer] = _get_random_valid_position()
		else:
			roamer.velocity = direction * CREATURE_SPEED
			roamer.move_and_slide()
			
			if roamer.get_slide_collision_count() > 0:
				_roam_targets[roamer] = _get_random_valid_position()

func _get_random_valid_position() -> Vector2:
	var padding: float = ORBIT_RADIUS + 50.0 
	var rand_x: float = randf_range(padding, MAP_SIZE - padding)
	var rand_y: float = randf_range(padding, MAP_SIZE - padding)
	return Vector2(rand_x, rand_y)
