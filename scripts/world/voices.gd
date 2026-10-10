extends Node3D
## Голоса вокруг: где люди — там и слышно. У лавочек в Каменке бабки
## смеются, у клуба вечером шумят и кричат «Эге-гей!», на пруду летом
## визжат дети, на рынке и на вокзале гомон, на стадионе болеют, в роще
## аукаются. Каждые несколько секунд — один голос из ближнего живого
## места; гомон толпы — один общий звук, переезжает к ближнему месту.

## Места: где (город — в своих координатах, town; свалка — от её середины,
## junk), радиус, часы (до 25 —
## за полночь), какие голоса, есть ли гомон (crowd), под крышей ли (roof —
## и в дождь), только летом (summer).
const SPOTS := [
	{"name": "benches", "pos": Vector3(-95, 0, -36.5), "r": 12.0, "hours": [8, 21], "sounds": ["laugh_woman", "laugh_man", "laugh_woman"], "crowd": true},
	{"name": "shop", "pos": Vector3(-50, 0, -25), "r": 8.0, "hours": [8, 20], "sounds": ["laugh_man", "shout_hey", "laugh_woman"]},
	{"name": "club_village", "pos": Vector3(-24, 0, -20), "r": 14.0, "hours": [19, 25], "sounds": ["laugh_man", "laugh_woman", "shout_yahoo", "laugh_woman"], "crowd": true, "roof": true},
	{"name": "kamenka_north", "pos": Vector3(-62, 0, -221), "r": 14.0, "hours": [9, 21], "sounds": ["kids_play", "laugh_kid", "laugh_woman"]},
	{"name": "depot", "pos": Vector3(-19, 0, -111), "r": 14.0, "hours": [7, 19], "sounds": ["shout_hey", "laugh_man"]},
	{"name": "backlot", "pos": Vector3(306, 0, 132), "town": true, "r": 12.0, "hours": [16, 26], "sounds": ["laugh_man", "shout_hey", "shout_yahoo", "laugh_man"], "crowd": true},
	{"name": "pond", "pos": Vector3(-178, 0, -40), "r": 10.0, "hours": [10, 19], "sounds": ["kids_play", "laugh_kid", "kids_play"], "summer": true},
	{"name": "farm", "pos": Vector3(18, 0, 46), "r": 20.0, "hours": [7, 19], "sounds": ["shout_hey", "laugh_man"]},
	{"name": "junkyard", "pos": Vector3(0, 0, 2), "junk": true, "r": 14.0, "hours": [8, 18], "sounds": ["shout_hey", "laugh_man"]},
	{"name": "grove", "pos": Vector3(124, 0, 112), "r": 14.0, "hours": [10, 21], "sounds": ["auu", "laugh_woman", "laugh_man", "auu"]},
	{"name": "cafe", "pos": Vector3(-1380, 0, -22), "r": 12.0, "hours": [8, 22], "sounds": ["laugh_man", "laugh_woman"], "crowd": true, "roof": true},
	{"name": "market", "pos": Vector3(64, 0, 144), "town": true, "r": 18.0, "hours": [7, 17], "sounds": ["shout_hey", "laugh_woman", "laugh_man"], "crowd": true},
	{"name": "square", "pos": Vector3(122, 0, 21), "town": true, "r": 16.0, "hours": [8, 22], "sounds": ["laugh_woman", "laugh_man", "laugh_kid"], "crowd": true},
	{"name": "park", "pos": Vector3(-2, 0, 165), "town": true, "r": 25.0, "hours": [9, 21], "sounds": ["laugh_kid", "kids_play", "laugh_woman", "shout_yahoo"]},
	{"name": "school", "pos": Vector3(11, 0, 99), "town": true, "r": 22.0, "hours": [8, 15], "sounds": ["kids_play", "laugh_kid", "kids_play"]},
	{"name": "stadium", "pos": Vector3(160, 0, 160), "town": true, "r": 26.0, "hours": [10, 20], "sounds": ["cheer", "shout_yahoo", "cheer"], "crowd": true},
	{"name": "club_town", "pos": Vector3(125, 0, 118), "town": true, "r": 14.0, "hours": [19, 25], "sounds": ["laugh_man", "laugh_woman", "shout_yahoo"], "crowd": true, "roof": true},
	{"name": "station", "pos": Vector3(97, 0, 193), "town": true, "r": 14.0, "hours": [6, 22], "sounds": ["shout_hey", "laugh_man"], "crowd": true, "roof": true},
	{"name": "sto", "pos": Vector3(248, 0, 67), "town": true, "r": 10.0, "hours": [8, 19], "sounds": ["shout_hey", "laugh_man"]},
]
## Откуда ещё слышно: к радиусу места.
const HEAR := 45.0

var _rng := RandomNumberGenerator.new()
var _next := 3.0
var _crowd: AudioStreamPlayer3D
var _crowd_spot := -1
## Последний голос — для проверки: {"sound", "spot", "pos"}.
var last := {}


func _ready() -> void:
	_rng.randomize()
	_crowd = AudioStreamPlayer3D.new()
	_crowd.stream = SoundLibrary.stream("chatter")
	_crowd.unit_size = 7.0
	_crowd.max_distance = 60.0
	_crowd.volume_db = -80.0
	add_child(_crowd)


## Где место в мире.
static func spot_pos(s: Dictionary) -> Vector3:
	var p: Vector3 = s.pos
	if s.get("junk", false):
		return Landmarks.junk_center() + p
	return Town.w(p) if s.get("town", false) else p


## Живо ли место сейчас: часы, погода, лето.
static func active(s: Dictionary, h: float, rain: float, season: int) -> bool:
	var a: float = s.hours[0]
	var b: float = s.hours[1]
	if not ((h >= a and h < b) or (b > 24.0 and h < b - 24.0)):
		return false
	if rain > 0.5 and not s.get("roof", false):
		return false
	if s.get("summer", false) and season != 0:
		return false
	return true


## Живые места, которые слышно из точки p (номера в SPOTS).
func audible(p: Vector3) -> Array[int]:
	var out: Array[int] = []
	var h := TimeManager.hour()
	for i in SPOTS.size():
		var s: Dictionary = SPOTS[i]
		if active(s, h, WeatherManager.rain, WeatherManager.season()) \
				and Vector2(p.x, p.z).distance_to(Vector2(spot_pos(s).x, spot_pos(s).z)) < float(s.r) + HEAR:
			out.append(i)
	return out


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not GameManager.in_game:
		_crowd.volume_db = -80.0
		return
	var here := audible(cam.global_position)
	_update_crowd(here, cam.global_position, delta)
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(3.0, 7.0)
		if not here.is_empty():
			speak(here[_rng.randi() % here.size()])


## Один голос из места i: случайный из его списка, где-то в его кругу,
## каждый раз чуть другой высоты — как разные люди.
func speak(i: int) -> void:
	var s: Dictionary = SPOTS[i]
	var sounds: Array = s.sounds
	var snd: String = sounds[_rng.randi() % sounds.size()]
	var a := _rng.randf() * TAU
	var d := _rng.randf() * float(s.r) * 0.7
	var p := spot_pos(s) + Vector3(cos(a) * d, 1.6, sin(a) * d)
	SoundLibrary.play_at(snd, p, _rng.randf_range(-6.0, -1.0), _rng.randf_range(0.9, 1.12))
	last = {"sound": snd, "spot": s.name, "pos": p}


## Гомон — у ближнего места с толпой; к другому — переезжает тихо.
func _update_crowd(here: Array[int], cam: Vector3, delta: float) -> void:
	var best := -1
	var bd := INF
	for i in here:
		if SPOTS[i].get("crowd", false):
			var d := cam.distance_to(spot_pos(SPOTS[i]))
			if d < bd:
				bd = d
				best = i
	var target := -80.0
	if best >= 0 and best == _crowd_spot:
		target = -8.0
	elif _crowd.volume_db <= -60.0:
		_crowd_spot = best
		if best >= 0:
			_crowd.global_position = spot_pos(SPOTS[best]) + Vector3(0, 1.6, 0)
			if not _crowd.playing:
				_crowd.play()
	_crowd.volume_db = move_toward(_crowd.volume_db, target, 30.0 * delta)
	if _crowd.volume_db <= -79.0 and _crowd_spot < 0 and _crowd.playing:
		_crowd.stop()
