extends ParallaxBackground

# The direction and speed the camera appears to move through space
# Negative X moves stars left, Negative Y moves stars up
@export var scroll_speed: Vector2 = Vector2(-15, -5) 

func _process(delta: float) -> void:
	# Continuously shift the base offset to create infinite scrolling
	scroll_offset += scroll_speed * delta
