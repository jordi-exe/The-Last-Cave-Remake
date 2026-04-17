extends CharacterBody3D

enum STATE { FALL, FLOOR, JUMP, LEDGE_GRAB, LEDGE_CLIMB, LEDGE_JUMP }

#Player Physics variables
@export var FALL_GRAVITY := 30.0
@export var FALL_VELOCITY := -20.0
@export var WALK_VELOCITY := 10.0
@export var JUMP_VELOCITY := 20.0
@export var JUMP_DECELERATION := 30.0
@export var LEDGE_JUMP_VELOCITY := 20.0

#Misc variables
@onready var player_sprite: AnimatedSprite3D = %PlayerSprite
@onready var coyote_timer: Timer = %CoyoteTimer
@onready var state_debug: Label3D = %StateDebug

#Ledge grab variables
@onready var player_collider: CollisionShape3D = %PlayerCollider
@onready var rc_ledge_grab: RayCast3D = %rcLedgeGrab
@onready var rc_ledge_space: RayCast3D = %rcLedgeSpace


var activeState := STATE.FALL
var facingDirection := 1.0

func _ready() -> void:
	SwitchState(activeState)
	rc_ledge_grab.add_exception(self)

func _physics_process(delta: float) -> void:
	ProcessState(delta)
	move_and_slide()

func SwitchState(toState: STATE) -> void:
	var previousState := activeState
	activeState = toState
	
	#State specific things that only need to run once upon entering the next state
	match activeState:
		STATE.FALL:
			player_sprite.play("fall")
			
			if previousState == STATE.FLOOR:
				coyote_timer.start()
			
		STATE.JUMP:
			player_sprite.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
		
		STATE.LEDGE_GRAB:
			player_sprite.play("ledgeGrab")
			velocity = Vector3.ZERO
			global_position.y = rc_ledge_grab.get_collision_point().y - (player_collider.shape.height * 0.5)
			#refresh any cooldown for movement functions here i.e. double jump, air dash etc
		
		STATE.LEDGE_CLIMB:
			player_sprite.play("ledgeClimb")
		
		STATE.LEDGE_JUMP:
			player_sprite.play("jump") #this should be a different animation from the regular jump
			velocity.y = LEDGE_JUMP_VELOCITY
	
	state_debug.text = str(STATE.keys()[activeState])

func ProcessState(delta: float) -> void:
	match activeState:
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			HandleMovement()
			
			if is_on_floor():
				SwitchState(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump") and coyote_timer.time_left > 0:
				SwitchState(STATE.JUMP)
			elif IsInputTowardFacing() and IsLedge() and IsSpace():
				SwitchState(STATE.LEDGE_GRAB)
		
		STATE.FLOOR:
			if Input.get_axis("moveLeft", "moveRight"):
				player_sprite.play("walk")
			else:
				player_sprite.play("idle")
			HandleMovement()
			
			if not is_on_floor():
				SwitchState(STATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				SwitchState(STATE.JUMP)
		
		STATE.JUMP, STATE.LEDGE_JUMP:
			velocity.y = move_toward(velocity.y, 0, JUMP_DECELERATION * delta)
			HandleMovement()
			
			if Input.is_action_just_released("jump") or velocity.y <= 0:
				velocity.y = 0
				SwitchState(STATE.FALL)
		
		STATE.LEDGE_GRAB:
			player_sprite.play("ledgeGrab")
			
			if Input.is_action_just_pressed("up"):
				SwitchState(STATE.LEDGE_CLIMB)
		
		STATE.LEDGE_CLIMB:			
			if not player_sprite.is_playing():
				var offset := LedgeClimbOffset()
				offset.x *= facingDirection
				position += offset
				SwitchState(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump"):
				#allows the player to jump out of the ledge climb at any point
				var progress := inverse_lerp(0, player_sprite.sprite_frames.get_frame_count("ledgeClimb"), player_sprite.frame)
				var offset := LedgeClimbOffset()
				offset.x *= facingDirection * progress
				position += offset
				SwitchState(STATE.LEDGE_JUMP)

func HandleMovement() -> void:
	var inputDirection := signf(Input.get_axis("moveLeft", "moveRight"))
	if inputDirection:
		player_sprite.flip_h = inputDirection < 0
		facingDirection = inputDirection
		
		#Mirrors the raycast direction based on the input direction
		rc_ledge_grab.position.x = inputDirection * absf(rc_ledge_grab.position.x)
		rc_ledge_grab.target_position.x = inputDirection * absf(rc_ledge_grab.target_position.x)
		rc_ledge_grab.force_raycast_update()
	
	#basic horizontal movement, need to implement proper momentum
	velocity.x = inputDirection * WALK_VELOCITY

#Prevents ledge grab if no input is detected when passing a ledge
func IsInputTowardFacing() -> bool:
	return signf(Input.get_axis("moveLeft", "moveRight")) == facingDirection

#Checks if the ledge is grabbable
func IsLedge() -> bool:
	return is_on_wall_only() and \
	rc_ledge_grab.is_colliding() and \
	rc_ledge_grab.get_collision_normal().is_equal_approx(Vector3.UP)

#Checks if the space above the ledge has enough space to allow the player to climb up
	#May change this where if there is no space available to climb, the player is
	#unable to climb, but can still jump out of the hanging state.
	
	#This could allow for interesting level design where the player has to jump from 1 block height
	#spaces without being able to climb up
func IsSpace() -> bool:
	rc_ledge_space.global_position = rc_ledge_grab.get_collision_point()
	rc_ledge_space.force_raycast_update()
	return not rc_ledge_space.is_colliding()

#Sets the offset for where the player is placed when climbing
func LedgeClimbOffset() -> Vector3:
	var shape := player_collider.shape
	if shape is CapsuleShape3D:
		return Vector3(shape.radius * 2.0, shape.height, 0.0)
	return Vector3.ZERO
