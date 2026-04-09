extends CharacterBody3D

enum STATE { FALL, FLOOR, JUMP, LEDGE_GRAB, LEDGE_CLIMB, LEDGE_JUMP }

@export var FALL_GRAVITY := 30.0
@export var FALL_VELOCITY := -20.0
@export var WALK_VELOCITY := 10.0
@export var JUMP_VELOCITY := 20.0
@export var JUMP_DECELERATION := 30.0

@onready var player_sprite: AnimatedSprite3D = %PlayerSprite
@onready var coyote_timer: Timer = %CoyoteTimer

var activeState := STATE.FALL

func _ready() -> void:
	SwitchState(activeState)

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

func ProcessState(delta: float) -> void:
	match activeState:
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			HandleMovement()
			
			if is_on_floor():
				SwitchState(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump") and coyote_timer.time_left > 0:
				SwitchState(STATE.JUMP)
		
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
		
		STATE.JUMP:
			velocity.y = move_toward(velocity.y, 0, JUMP_DECELERATION * delta)
			HandleMovement()
			
			if Input.is_action_just_released("jump") or velocity.y <= 0:
				velocity.y = 0
				SwitchState(STATE.FALL)

func HandleMovement() -> void:
	var inputDirection := signf(Input.get_axis("moveLeft", "moveRight"))
	
	if inputDirection:
		player_sprite.flip_h = inputDirection < 0
	
	velocity.x = inputDirection * WALK_VELOCITY
