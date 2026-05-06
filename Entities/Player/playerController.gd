extends CharacterBody3D

enum STATE { FALL, FLOOR, JUMP, LEDGE_CLIMB, LEDGE_HANG, LEDGE_JUMP }

#Player Physics variables

# # Vertical Physics
@export var FALL_GRAVITY := 30.0
@export var FALL_VELOCITY := -20.0
@export var JUMP_VELOCITY := 15.0
var MIN_JUMP_VELOCITY := 5.0
@export var JUMP_DECELERATION := 35.0
@export var LEDGE_JUMP_VELOCITY := 17.0

# # Horizontal Physics
@export var MAX_SPEED := 12.0
@export var T_MAX_SPEED := 0.25 #time taken to reach max speed in secs
@export var T_STOP := 0.12 #time taken to stop
@export var BREAK_MULTI := 0.5 #strength of the overall brake when turning

#Misc variables
@onready var player_sprite: AnimatedSprite3D = %PlayerSprite
@onready var coyote_timer: Timer = %CoyoteTimer
@onready var ledge_grab_timer: Timer = %LedgeGrabTimer
@onready var state_debug: Label3D = %StateDebug

#Ledge grab variables
@onready var player_collider: CollisionShape3D = %PlayerCollider
@onready var rc_head_check: RayCast3D = %rcHeadCheck
@onready var rc_ledge_grab: RayCast3D = %rcLedgeGrab
@onready var rc_ledge_space: RayCast3D = %rcLedgeSpace


var activeState := STATE.FALL
var facingDirection := 1.0

func _ready() -> void:
	SwitchState(activeState)
	rc_ledge_grab.add_exception(self) #prevents the raycast from detecting the player's hitbox

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
			MIN_JUMP_VELOCITY = 5.0 #sets the min jump when on ground
			player_sprite.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
		
		STATE.LEDGE_CLIMB:
			player_sprite.play("ledgeClimb")
			velocity = Vector3.ZERO
			global_position.y = rc_ledge_grab.get_collision_point().y - (player_collider.shape.height * 0.5)
			#refresh any cooldown for movement functions here i.e. double jump, air dash etc
		
		STATE.LEDGE_HANG:
			player_sprite.play("ledgeGrab")
			velocity = Vector3.ZERO
			global_position.y = rc_ledge_grab.get_collision_point().y - (player_collider.shape.height * 0.5)
		
		STATE.LEDGE_JUMP:
			MIN_JUMP_VELOCITY = 7.5 #sets the min jump when entering a ledge jump
			player_sprite.play("jump") #this should be a different animation from the regular jump #should it??
			velocity.y = JUMP_VELOCITY
	
	state_debug.text = str(STATE.keys()[activeState])

func ProcessState(delta: float) -> void:
	match activeState:
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			HandleMovement(delta)
			
			if is_on_floor():
				SwitchState(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump") and coyote_timer.time_left > 0:
				SwitchState(STATE.JUMP)
			elif ledge_grab_timer.time_left == 0.0 and IsInputTowardFacing() and IsLedge():
				if IsSpace():
					SwitchState(STATE.LEDGE_CLIMB)
				elif not IsSpace():
					SwitchState(STATE.LEDGE_HANG)
		
		STATE.FLOOR:
			if Input.get_axis("moveLeft", "moveRight"):
				player_sprite.play("walk")
			else:
				player_sprite.play("idle")
			HandleMovement(delta)
			
			if not is_on_floor():
				SwitchState(STATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				SwitchState(STATE.JUMP)
		
		STATE.JUMP, STATE.LEDGE_JUMP:
			velocity.y = move_toward(velocity.y, 0, JUMP_DECELERATION * delta)
			HandleMovement(delta)
			
			if Input.is_action_just_released("jump") or velocity.y <= 0:
				velocity.y = min(velocity.y, MIN_JUMP_VELOCITY)
				SwitchState(STATE.FALL)
		
		STATE.LEDGE_CLIMB:
			if not player_sprite.is_playing():
				var offset := LedgeClimbOffset()
				offset.x *= facingDirection
				position += offset
				SwitchState(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump"):
				SwitchState(STATE.LEDGE_JUMP)
		
		STATE.LEDGE_HANG:
			if Input.is_action_just_pressed("jump"):
				SwitchState(STATE.LEDGE_JUMP)
			#lets the player drop down
			elif Input.is_action_just_pressed("down"):
				ledge_grab_timer.start()
				SwitchState(STATE.FALL)

func HandleMovement(delta: float) -> void:
	var inputDirection : float = Input.get_axis("moveLeft", "moveRight")
	
	var currentSpeed : float = velocity.x
	var absSpeed : float = abs(currentSpeed)
	var speedRatio : float = clamp(absSpeed / MAX_SPEED, 0.0, 1.0)
	
	#New horizontal movement code with momentum calculation
	if inputDirection:
		player_sprite.flip_h = inputDirection < 0
		facingDirection = signf(inputDirection)
		
		#Mirrors the raycast direction based on the input direction
		rc_ledge_grab.position.x = facingDirection * absf(rc_ledge_grab.position.x)
		rc_ledge_grab.target_position.x = facingDirection * absf(rc_ledge_grab.target_position.x)
		rc_ledge_grab.force_raycast_update()
		
		var isReversing: bool = inputDirection != 0 \
		and signf(currentSpeed) != signf(inputDirection) \
		and abs(currentSpeed) > 0.1
		
		if isReversing:
			#Braking calculation when making hard turn
			var brakeForce: float = (MAX_SPEED / T_STOP) * BREAK_MULTI  # tweak multiplier
			currentSpeed = move_toward(currentSpeed, 0, brakeForce * delta)
		else:
			#Acceleration Curve Calculation
			var normalizedSpeed: float = speedRatio
			var curve: float = 1.0 - pow(1.0 - normalizedSpeed, 2.0)

			var accel: float = MAX_SPEED / T_MAX_SPEED
			var deltaSpeed: float = accel * (1.0 - curve) * delta

			currentSpeed += deltaSpeed * inputDirection
	else:
		#Deceleration Curve Calculation
		var normalizedSpeed : float = speedRatio
		var curve : float = pow(1.0 - normalizedSpeed, 2.0)

		var decel : float = MAX_SPEED / T_STOP
		var deltaSpeed :float = decel * (1.0 - curve) * delta

		currentSpeed = move_toward(currentSpeed, 0, deltaSpeed)
	
	#Clamped final speed
	currentSpeed = clamp(currentSpeed, -MAX_SPEED, MAX_SPEED)
	velocity.x = currentSpeed

#Prevents ledge grab if no input is detected when passing a ledge
func IsInputTowardFacing() -> bool:
	return signf(Input.get_axis("moveLeft", "moveRight")) == facingDirection

#Checks if the ledge is grabbable
func IsLedge() -> bool:
	return is_on_wall_only() and \
	rc_ledge_grab.is_colliding() and \
	not rc_head_check.is_colliding() and \
	rc_ledge_grab.get_collision_normal().is_equal_approx(Vector3.UP)

#Checks if there is space for the player to climb up
#Determined by the height of the Ledge Space Raycast, which is the height of the player's hitbox
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
