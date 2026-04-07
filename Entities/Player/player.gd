extends CharacterBody3D

enum STATE { FALL, FLOOR, JUMP, LEDGE_GRAB, LEDGE_CLIMB, LEDGE_JUMP }

@export var FALL_GRAVITY := 1500.0
@export var FALL_VELOCITY := 500.0
@export var WALK_VELOCITY := 200.0

@onready var player_sprite: AnimatedSprite3D = %PlayerSprite

var activeState := STATE.FALL

func _ready() -> void:
	SwitchState(activeState)

func _physics_process(delta: float) -> void:
	ProcessState(delta)
	move_and_slide()

func SwitchState(toState: STATE) -> void:
	activeState = toState
	
	#State specific things that only need to run once upon entering the next state
	match activeState:
		STATE.FALL:
			player_sprite.play("fall")

func ProcessState(delta: float) -> void:
	match activeState:
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			HandleMovement()
		STATE.FLOOR:
			if Input.get_axis("moveLeft", "moveRight"):
				player_sprite.play("walk") #make walk anim
			else:
				player_sprite.play("idle")
			HandleMovement()

func HandleMovement() -> void:
	var inputDirection := signf(Input.get_axis("moveLeft", "moveRight"))
	
	if inputDirection:
		player_sprite.flip_h = inputDirection < 0
	
	velocity.x = inputDirection * WALK_VELOCITY
