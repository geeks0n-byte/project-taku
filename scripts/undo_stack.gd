class_name UndoStack
extends RefCounted

var max_size: int = GameConstants.UNDO_STACK_LIMIT
var _undo: Array = []
var _redo: Array = []
var current: Dictionary = {}

func reset(initial_state: Dictionary) -> void:
	_undo.clear()
	_redo.clear()
	current = initial_state

func record(new_state: Dictionary) -> void:
	_undo.append(current)
	if _undo.size() > max_size:
		_undo.pop_front()
	_redo.clear()
	current = new_state

func undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	_redo.append(current)
	current = _undo.pop_back()
	return current

func redo() -> Dictionary:
	if _redo.is_empty():
		return {}
	_undo.append(current)
	if _undo.size() > max_size:
		_undo.pop_front()
	current = _redo.pop_back()
	return current

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()
