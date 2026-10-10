class_name TextInput
extends RefCounted
## Ввод текста на телефоне в браузере: поле Godot там клавиатуру не
## открывает — по касанию спрашиваем окном браузера (prompt), ответ
## кладём в поле. На компьютере и в APK поле работает как обычно.


## Когда закрылось последнее окно: касание даёт и «палец», и «мышь» —
## второе событие окно не открывает.
static var _closed_ms := -10000


## Нужен ли ввод через окно браузера.
static func needed() -> bool:
	return OS.has_feature("web") and GameManager.touch_mode


## Подключить поле: касание — окно браузера с вопросом title.
static func attach(edit: LineEdit, title: String) -> void:
	if not needed():
		return
	edit.editable = false
	edit.gui_input.connect(func(e: InputEvent) -> void:
		var tap := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
		if not tap or Time.get_ticks_msec() - _closed_ms < 700:
			return
		var got: Variant = ask(title, edit.text)
		_closed_ms = Time.get_ticks_msec()
		if got != null:
			edit.text = String(got).left(edit.max_length if edit.max_length > 0 else 64)
			edit.text_changed.emit(edit.text))


## Окно браузера: введённый текст или null (отмена).
static func ask(title: String, current: String) -> Variant:
	if not OS.has_feature("web"):
		return null
	var js := "prompt(%s, %s)" % [JSON.stringify(SettingsManager.t(title)), JSON.stringify(current)]
	return JavaScriptBridge.eval(js, true)
