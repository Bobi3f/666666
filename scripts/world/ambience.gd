extends Node3D
## Звуки и дождь вокруг игрока: птицы днём, сверчки ночью, шум дождя
## и капли, которые летят вокруг активной камеры.

var _crickets: AudioStreamPlayer
var _rain_snd: AudioStreamPlayer
var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _bird_timer := 3.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_crickets = AudioStreamPlayer.new()
	_crickets.stream = SoundLibrary.stream("crickets")
	_crickets.volume_db = -80.0
	add_child(_crickets)
	_crickets.play()
	_rain_snd = AudioStreamPlayer.new()
	_rain_snd.stream = SoundLibrary.stream("rain")
	_rain_snd.volume_db = -80.0
	add_child(_rain_snd)
	_rain_snd.play()
	_rain = _make_rain()
	add_child(_rain)
	_snow = _make_snow()
	add_child(_snow)


## Снегопад: крупные хлопья медленно кружат вокруг камеры.
func _make_snow() -> CPUParticles3D:
	var r := CPUParticles3D.new()
	r.amount = 900
	r.lifetime = 5.0
	r.local_coords = false
	r.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	r.emission_box_extents = Vector3(16, 0.5, 16)
	r.direction = Vector3(0.2, -1, 0.1)
	r.spread = 25.0
	r.gravity = Vector3(0, -0.6, 0)
	r.initial_velocity_min = 1.2
	r.initial_velocity_max = 2.0
	var flake := QuadMesh.new()
	flake.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.96, 1.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.material = mat
	r.mesh = flake
	r.emitting = false
	return r


func _make_rain() -> CPUParticles3D:
	var r := CPUParticles3D.new()
	r.amount = 1400
	r.lifetime = 0.9
	r.local_coords = false
	r.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	r.emission_box_extents = Vector3(18, 0.5, 18)
	r.direction = Vector3(0.08, -1, 0)
	r.spread = 2.0
	r.gravity = Vector3(0, -9.8, 0)
	r.initial_velocity_min = 16.0
	r.initial_velocity_max = 20.0
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.75, 0.85, 0.6)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = mat
	r.mesh = drop
	r.emitting = false
	return r


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var h := TimeManager.hour()
	var night := h < 5.0 or h > 21.0
	var rain := WeatherManager.rain
	# Под крышей машины дождь стучит по крыше сам; на мотоцикле — как пешком
	var car := GameManager.vehicle as Vehicle
	var in_car: bool = car != null and car.spec.roof

	# Дождь: капли над головой, шум — снаружи (в машине стучит по крыше сама машина)
	var snowing := WeatherManager.snowing()
	_rain.global_position = cam.global_position + Vector3(0, 9, 0)
	_rain.emitting = rain > 0.25 and not snowing
	_snow.global_position = cam.global_position + Vector3(0, 7, 0)
	_snow.emitting = rain > 0.25 and snowing
	_fade(_rain_snd, -4.0 if rain > 0.1 and not in_car and not snowing else -80.0, rain, delta)

	# Сверчки — ночью и без дождя
	_fade(_crickets, -10.0 if night and rain < 0.3 and WeatherManager.season() != 2 else -80.0, 1.0, delta)

	# Птицы — днём, в хорошую погоду, где-нибудь неподалёку
	if not night and rain < 0.3 and not in_car:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = _rng.randf_range(4.0, 11.0)
			var off := Vector3(_rng.randf_range(-15, 15), _rng.randf_range(3, 8), _rng.randf_range(-15, 15))
			SoundLibrary.play_at("bird", cam.global_position + off, -6.0, _rng.randf_range(0.85, 1.2))


## Плавно подводит громкость к цели, чтобы звук не обрывался.
func _fade(p: AudioStreamPlayer, target_db: float, strength: float, delta: float) -> void:
	var target := target_db if target_db <= -79.0 else target_db + linear_to_db(maxf(strength, 0.05))
	p.volume_db = move_toward(p.volume_db, target, 40.0 * delta)
