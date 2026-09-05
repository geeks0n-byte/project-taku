class_name UndoStack
extends RefCounted

# Generic undo/redo stack that stores board-state snapshots (Dictionaries).
# Each call to record() pushes the previous state onto _undo and clears _redo,
# preserving the standard "undo invalidates redo history" contract.

# Maximum number of states kept on the undo stack; oldest entries are dropped
# when the limit is exceeded. 0 means unlimited.
var max_size: int = GameConstants.UNDO_STACK_LIMIT
var _undo: Array = []
var _redo: Array = []
# The live state — not yet on the undo stack; returned as the restored state
# when the player undoes back to it.
var current: Dictionary = {}

# Clears both stacks and sets the starting state (the "clean slate" snapshot).
func reset(initial_state: Dictionary) -> void:
	_undo.clear()
	_redo.clear()
	current = initial_state.duplicate(true)

# Saves the current state so it can be restored by undo(), then moves to new_state.
# Clears the redo stack because a new branch of history has begun.
# Snapshots are deep-copied so later board mutations cannot corrupt history.
func record(new_state: Dictionary) -> void:
	_undo.append(current.duplicate(true))
	_trim_undo_if_needed()
	_redo.clear()
	current = new_state.duplicate(true)

# Pops the most recent state from the undo stack and makes it current.
# The state that was current moves onto the redo stack.
# Returns an empty dict (no-op signal) when there is nothing to undo.
func undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	_redo.append(current.duplicate(true))
	current = _undo.pop_back()
	return current.duplicate(true)

# Re-applies the most recently undone state. Puts the current state back onto
# the undo stack first (respecting max_size) so undo still works afterwards.
# Returns an empty dict when there is nothing to redo.
func redo() -> Dictionary:
	if _redo.is_empty():
		return {}
	_undo.append(current.duplicate(true))
	_trim_undo_if_needed()
	current = _redo.pop_back()
	return current.duplicate(true)

# Removes the oldest undo entries until the stack is within max_size.
# Called after every push to _undo so memory use stays bounded.
func _trim_undo_if_needed() -> void:
	if max_size <= 0:
		return
	while _undo.size() > max_size:
		_undo.pop_front()

## True when at least one snapshot sits on the undo stack.
func can_undo() -> bool:
	return not _undo.is_empty()

## True when at least one snapshot sits on the redo stack.
func can_redo() -> bool:
	return not _redo.is_empty()

# Serialises the full undo/redo history as a deep-copied dictionary, suitable
# for saving to disk or transferring between sessions.
func export_history() -> Dictionary:
	return {
		"current": current.duplicate(true),
		"undo": _undo.duplicate(true),
		"redo": _redo.duplicate(true),
	}

# Restores a previously exported history. Deep-copies every snapshot so the
# stack is independent of the source dict after import.
func import_history(data: Dictionary) -> void:
	_undo.clear()
	_redo.clear()
	current = data.get("current", {}).duplicate(true)
	var undo_src: Array = data.get("undo", [])
	var redo_src: Array = data.get("redo", [])
	for snap in undo_src:
		if snap is Dictionary:
			_undo.append(snap.duplicate(true))
	for snap in redo_src:
		if snap is Dictionary:
			_redo.append(snap.duplicate(true))
