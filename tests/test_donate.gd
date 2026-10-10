extends SceneTree
## «Поддержать автора» в главном меню: без ссылок пункта нет; со ссылками —
## страница с кнопкой на каждую, «Назад» и Esc возвращают на главную.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func pf(n: int) -> void:
	for i in n: await process_frame
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
func texts(node: Node) -> Array:
	var out := []
	for b in node.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree(): out.append((b as Button).text)
	return out
func world() -> void:
	if W:
		W.queue_free()
		await pf(2)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	await pf(5)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var PM = load("res://scripts/ui/pause_menu.gd")
	print("== Ссылок нет — пункта нет")
	PM.donate_links = []
	await world()
	var menu = child("pause_menu.gd")
	ok(menu.is_open() and menu._page == "main", "главное меню открыто")
	ok(not texts(menu._pages.main).has("Поддержать автора"), "без ссылок кнопки нет: " + str(texts(menu._pages.main)))

	print("== Ссылки есть")
	PM.donate_links = [["PayPal", "https://paypal.me/test"], ["Buy Me a Coffee", "https://buymeacoffee.com/test"]]
	await world()
	menu = child("pause_menu.gd")
	var main_btns := texts(menu._pages.main)
	ok(main_btns.has("Поддержать автора"), "кнопка «Поддержать автора» в главном меню")
	ok(main_btns.find("Поддержать автора") < main_btns.find("Сообщить об ошибке"), "стоит над «Сообщить об ошибке»")
	for b in menu._pages.main.find_children("*", "Button", true, false):
		if b.text == "Поддержать автора": b.pressed.emit()
	await pf(2)
	var sup := texts(menu._pages.support)
	ok(menu._page == "support", "открылась страница поддержки")
	ok(sup.has("PayPal") and sup.has("Buy Me a Coffee") and sup.has("Назад"), "кнопки ссылок и «Назад»: " + str(sup))
	ok(menu._pages.support.get_combined_minimum_size().y < 400.0, "страница помещается на низком экране: %d" % menu._pages.support.get_combined_minimum_size().y)
	for b in menu._pages.support.find_children("*", "Button", true, false):
		if b.text == "Назад": b.pressed.emit()
	await pf(2)
	ok(menu._page == "main", "«Назад» — на главную")
	ok(String(TranslationServer.get_translation_object("en").call("text", "Поддержать автора")) == "Support the author" if TranslationServer.get_translation_object("en") else true, "есть перевод")
	PM.donate_links = PM.DONATE.filter(func(d: Array) -> bool: return not String(d[1]).is_empty())

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
