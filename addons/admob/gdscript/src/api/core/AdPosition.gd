
class_name AdPosition

enum Values {
	TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT, CENTER, CUSTOM = -1
}

static var TOP := AdPosition.new(Values.TOP)
static var BOTTOM := AdPosition.new(Values.BOTTOM)
static var LEFT := AdPosition.new(Values.LEFT)
static var RIGHT := AdPosition.new(Values.RIGHT)
static var TOP_LEFT := AdPosition.new(Values.TOP_LEFT)
static var TOP_RIGHT := AdPosition.new(Values.TOP_RIGHT)
static var BOTTOM_LEFT := AdPosition.new(Values.BOTTOM_LEFT)
static var BOTTOM_RIGHT := AdPosition.new(Values.BOTTOM_RIGHT)
static var CENTER := AdPosition.new(Values.CENTER)

var value: int
var offset := Vector2i(Values.CUSTOM, Values.CUSTOM)


func _init(value: int, offset := Vector2i(Values.CUSTOM, Values.CUSTOM)) -> void:
	self.value = value
	self.offset = offset


static func custom(x: int, y: int) -> AdPosition:
	return AdPosition.new(Values.CUSTOM, Vector2i(x, y))
