class_name HoldRepeat
extends RefCounted
## Accelerating hold-to-repeat used by undo/redo on HUD, playtest, and editor.
##
## The button's pressed signal still fires the first action. After INITIAL_DELAY,
## tick() returns true on each accelerating interval until REPEAT_MIN.

const INITIAL_DELAY := 0.4
const REPEAT_START := 0.3
const REPEAT_MIN := 0.05
const REPEAT_ACCEL := 0.82

enum Side { NONE, UNDO, REDO }

var side: int = Side.NONE
var elapsed: float = 0.0
var interval: float = REPEAT_START

## Begins an undo hold. Resets elapsed time and the starting repeat interval.
func start_undo() -> void:
	side = Side.UNDO
	elapsed = 0.0
	interval = REPEAT_START


## Begins a redo hold. Resets elapsed time and the starting repeat interval.
func start_redo() -> void:
	side = Side.REDO
	elapsed = 0.0
	interval = REPEAT_START


## Clears undo hold without touching an active redo hold.
func stop_undo() -> void:
	if side == Side.UNDO:
		side = Side.NONE


## Clears redo hold without touching an active undo hold.
func stop_redo() -> void:
	if side == Side.REDO:
		side = Side.NONE


## True while either undo or redo is held.
func is_active() -> bool:
	return side != Side.NONE


## True while the current hold is undo.
func is_undo() -> bool:
	return side == Side.UNDO


## True while the current hold is redo.
func is_redo() -> bool:
	return side == Side.REDO


## Advances by delta. True when a repeat action should fire this frame.
func tick(delta: float) -> bool:
	if side == Side.NONE:
		return false
	elapsed += delta
	if elapsed < INITIAL_DELAY:
		return false
	var time_since_start := elapsed - INITIAL_DELAY
	if time_since_start < interval:
		return false
	elapsed = INITIAL_DELAY
	interval = maxf(interval * REPEAT_ACCEL, REPEAT_MIN)
	return true
