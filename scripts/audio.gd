extends Node
## Music with crossfades, ambience beds and a small pool of sound-effect players.
## Audio files live in res://assets/audio/{music,ambience,sfx}/<name>.wav

var muted := false
var _music: Array[AudioStreamPlayer] = []
var _amb: AudioStreamPlayer
var _cur := 0
var _music_name := ""
var _amb_name := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80
		add_child(p)
		_music.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.volume_db = -12
	add_child(_amb)
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func _stream(kind: String, name: String) -> AudioStream:
	var key := kind + "/" + name
	if not _cache.has(key):
		var path := "res://assets/audio/%s/%s.wav" % [kind, name]
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


func music(name: String, fade := 1.2) -> void:
	if name == _music_name:
		return
	_music_name = name
	var old := _music[_cur]
	_cur = 1 - _cur
	var nxt := _music[_cur]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, fade)
	var s := _stream("music", name) if name != "" else null
	if s:
		if s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
		nxt.stream = s
		nxt.volume_db = -40
		nxt.play()
		tw.tween_property(nxt, "volume_db", -6.0 if not muted else -80.0, fade)


func ambience(name: String) -> void:
	if name == _amb_name:
		return
	_amb_name = name
	var s := _stream("ambience", name) if name != "" else null
	if s == null:
		_amb.stop()
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	_amb.stream = s
	_amb.volume_db = -14 if not muted else -80
	_amb.play()


func play(name: String, volume := 0.0, pitch_jitter := 0.06) -> void:
	if muted:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -1000)) < 30:
		return
	_last_play[name] = now
	var s := _stream("sfx", name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func toggle_mute() -> void:
	muted = not muted
	_music[_cur].volume_db = -80.0 if muted else -6.0
	_amb.volume_db = -80.0 if muted else -14.0
