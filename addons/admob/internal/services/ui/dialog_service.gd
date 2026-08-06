




func show_confirmation(text: String, on_confirmed: Callable, ok_text := "OK") -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "AdMob"
	dialog.dialog_text = text
	dialog.ok_button_text = ok_text
	dialog.exclusive = false

	EditorInterface.get_base_control().add_child(dialog)
	dialog.get_cancel_button().text = "Close"

	dialog.confirmed.connect(on_confirmed)
	dialog.visibility_changed.connect(
		func() -> void:
			if not dialog.visible:
				dialog.queue_free()
	)

	dialog.popup_centered()


func show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "AdMob"
	dialog.dialog_text = text
	dialog.exclusive = false

	EditorInterface.get_base_control().add_child(dialog)
	dialog.visibility_changed.connect(
		func() -> void:
			if not dialog.visible:
				dialog.queue_free()
	)

	dialog.popup_centered()
