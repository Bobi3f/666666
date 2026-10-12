class_name Assets
extends RefCounted
## Готовые картинки и звуки из папок textures/ и sounds/.
##
## Раньше всё это рисовалось и синтезировалось кодом прямо в игре: на телефоне
## в браузере это секунды работы, и игра подвисала (особенно пока собиралась
## музыка). Теперь файлы делает заранее tools/bake_assets.gd, а игра их просто
## загружает. Нет файла — создаём кодом, как раньше (make): так любую картинку
## или звук можно заменить своим файлом с тем же именем или удалить.

const TEXTURES := "res://textures/"
const SOUNDS := "res://sounds/"


## Картинка textures/<name>.png; make: () -> Image — если файла нет.
static func texture(name: String, make: Callable, mipmaps := false) -> Texture2D:
	var path := TEXTURES + name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img: Image = make.call()
	if mipmaps and not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Звук sounds/<name>.wav; make: () -> AudioStream — если файла нет.
static func sound(name: String, make: Callable) -> AudioStream:
	var path := SOUNDS + name + ".wav"
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return make.call()


## Есть ли готовый звук (музыку без файла собираем по кусочку в фоне).
static func has_sound(name: String) -> bool:
	return ResourceLoader.exists(SOUNDS + name + ".wav")
