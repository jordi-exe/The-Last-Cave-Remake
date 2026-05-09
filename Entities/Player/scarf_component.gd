@tool
extends Node3D

class_name ScarfComponent

@export var characterBody: CharacterBody3D
@export var sprite_with_flip_h: AnimatedSprite3D
var current_flip_h: bool = false
@export var startingScarfTexture: Texture2D
@export var scarfSegmentTexture: Texture2D

@export var totalScarfSegments: int = 5
@export var scarfSegmentOffset: Vector3 = Vector3(-0.5, 2, 0) #rest position
@export var scarfSizeMAX: float = 1.0
@export var scarfSizeMIN: float = 0.2
@export var maxSegmentDistance: float = 4.0

@export var velocityMult: Vector3 = Vector3(1.0, 1.45, 0.0)
@export var scarf_pos_lerp_speed: float = 10.0

@export_range(-1.0, 1.0) var windStrengthX: float = 0.0
@export_range(-1.0, 1.0) var windStrengthY: float = 0.0
@export var maxWindVelocity: float = 100.0
@export_range(0.0, 1.0) var minWindInfluence: float = 0.25 #how much player velocity affects zero-wind axis

var skip_next_physics: bool = false

@export_tool_button("Generate Scarf") var generateScarfButton: Callable = func():
	_generate_scarf()

func _ready() -> void:
	sprite_with_flip_h.sorting_offset = 0 #will replace this to only be tail-based, rather than using a starting segment
	_generate_scarf()

func _generate_scarf() -> void:
	if get_child_count() > 0:
		for i in get_children():
			i.queue_free()
	
	if !startingScarfTexture or !scarfSegmentTexture:
		return
	
	var previousScarfSegmentPOS: Vector3 = Vector3.ZERO
	for i in range(totalScarfSegments+1):
		var newScarfSegment: Sprite3D = Sprite3D.new()
		newScarfSegment.texture = startingScarfTexture if i == 0 else scarfSegmentTexture
		newScarfSegment.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		
		newScarfSegment.position = previousScarfSegmentPOS + (Vector3.ZERO if i == 0 else scarfSegmentOffset)
		previousScarfSegmentPOS = newScarfSegment.position
		
		var scalePercent: float = float(i) / totalScarfSegments
		newScarfSegment.scale = Vector3.ONE * lerp(scarfSizeMAX, scarfSizeMIN, scalePercent)
		
		if i == 0:
			newScarfSegment.sorting_offset = 1 #sets the starting segment in front of player
		else:
			newScarfSegment.sorting_offset = -1 #sets the following segments behind the player
		add_child(newScarfSegment)
	skip_next_physics = true

func _physics_process(delta: float) -> void:
	if get_child_count() == 0 or skip_next_physics:
		skip_next_physics = false
		return
	
	if sprite_with_flip_h and current_flip_h != sprite_with_flip_h.flip_h:
		_set_hair_flip_h(sprite_with_flip_h.flip_h)
		current_flip_h = sprite_with_flip_h.flip_h
	
	var windStrength: Vector3 = Vector3(windStrengthX, windStrengthY, 0.0)
	var windVelocity: Vector3 = -windStrength * maxWindVelocity
	var windMagnitude: float = clamp(windStrength.length(), 0.0, 1.0)
	
	for i in range(1, get_child_count()):
		var prevChild: Sprite3D = get_child(i - 1)
		var currentChild: Sprite3D = get_child(i)
		
		var playerVelocity: Vector3 = characterBody.velocity * velocityMult
		var playerScale: float = lerp(1.0, minWindInfluence, windMagnitude) #higher wind = less influence
		var finalVelocity: Vector3 = (playerVelocity * playerScale) + windVelocity
		
		var posOffset = lerp(scarfSegmentOffset, abs(scarfSegmentOffset) * windStrength, windMagnitude)
		var targetPos: Vector3 = prevChild.position + posOffset
		
		targetPos += -finalVelocity * 0.05
		var scarfPosWeight: float = 1.0 - exp(-scarf_pos_lerp_speed * delta)
		currentChild.position = lerp(currentChild.position, targetPos, scarfPosWeight)
		
		var directionToLastChild: Vector3 = currentChild.position - prevChild.position
		var distanceToLastChild: float = directionToLastChild.length()
		var pieceScale: float = currentChild.scale.x
		if distanceToLastChild > maxSegmentDistance * pieceScale:
			directionToLastChild = directionToLastChild.normalized() * maxSegmentDistance * pieceScale
			currentChild.position = prevChild.position + directionToLastChild

func _set_hair_flip_h(flip_h: bool) -> void:
	scarfSegmentOffset.x = abs(scarfSegmentOffset.x) * (1 if flip_h else -1)
	
	for i in get_children():
		i.flip_h = flip_h
