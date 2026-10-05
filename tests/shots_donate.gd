extends SceneTree
## Скриншоты «Поддержать игру»: главное меню и страница со ссылками.
var W
func pf(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOTS").path_join(name))
func _initialize() -> void:
	load("res://scripts/ui/pause_menu.gd").donate_links = [["PayPal", "https://paypal.me/x"], ["Buy Me a Coffee", "https://buymeacoffee.com/x"]]
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await pf(30)
	var menu
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): menu = c
	await shot("donate_main.png")
	menu._show("support")
	await pf(5)
	await shot("donate_page.png")
	quit()
