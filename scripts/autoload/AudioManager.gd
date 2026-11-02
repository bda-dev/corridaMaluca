extends Node
## AudioManager (autoload) — efeitos sonoros, música e motor.
##
## Ordem de busca de cada som "nome":
##   assets/custom/audio/nome.(ogg|wav|mp3) -> assets/kenney/audio/nome.(...) -> Synth (placeholder)
## Músicas: arquivo "music_<nome>" (ex.: assets/kenney/audio/music_race.ogg) ou chiptune sintetizado.
## O motor do jogador usa "engine" (loop) ou um zumbido sintetizado.
##
## Com threads (celular/PC): música e efeitos placeholder são sintetizados numa Thread.
## Sem threads (exportação web "nothreads"): tudo é sintetizado em FATIAS dentro de
## _process(), respeitando um orçamento de milissegundos por frame, para não travar.

const SFX_POOL_SIZE := 12

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _streams := {}
var _cooldowns := {}

var _music_player: AudioStreamPlayer
var _music_name := ""
var _music_cache := {}
var _music_thread: Thread
var _rendering_name := ""
var _music_tween: Tween
var _sfx_thread: Thread
var _use_threads := OS.has_feature("threads")
var _prewarm_queue: Array[String] = []
var _song_job: SongRender

## Orçamento de síntese por frame quando não há threads (web).
const SLICE_BUDGET_USEC := 4000

## Efeitos pré-gerados numa thread ao abrir o jogo (evita engasgos no celular).
const PREWARM_SFX: Array[String] = ["type", "whoosh", "boom", "honk", "boost", "click", "count", "go",
	"pickup", "roll", "crash", "boing", "spin", "rocket", "explosion", "zap", "steam", "magnet",
	"land", "lap", "finish", "record", "teleport", "banana", "splat", "clank", "ops", "star"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	# só sintetiza o que não tem arquivo (a checagem de arquivos fica na thread principal)
	var todo: Array[String] = []
	for n in PREWARM_SFX:
		if AssetLib.audio(n) == null:
			todo.append(n)
	if _use_threads:
		_sfx_thread = Thread.new()
		_sfx_thread.start(_prewarm_sfx.bind(todo))
	else:
		_prewarm_queue = todo
		_prewarm_queue.append("__engine")


func _prewarm_sfx(names: Array[String]) -> Dictionary:
	var out := {}
	for n in names:
		out[n] = Synth.make_sfx(n)
	out["__engine"] = Synth.engine_loop()
	return out


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


## Volume linear 0..1 do barramento ("Music" ou "SFX").
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


## Toca um efeito. pitch permite variações (ex.: randf_range(0.9, 1.1)).
func play_sfx(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	var until: int = _cooldowns.get(sfx_name, 0)
	if until > now:
		return
	_cooldowns[sfx_name] = now + 45 # evita o mesmo som 2x no mesmo instante
	var stream := _get_stream(sfx_name)
	if stream == null:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _get_stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var s := AssetLib.audio(sfx_name)
	if s == null:
		s = Synth.make_sfx(sfx_name)
	_streams[sfx_name] = s
	return s


## Cria um player de motor em loop (o dono controla pitch_scale/volume e o adiciona à árvore).
func make_engine_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	var custom := AssetLib.audio("engine")
	if custom != null:
		_force_loop(custom)
		p.stream = custom
	else:
		if not _streams.has("__engine"):
			_streams["__engine"] = Synth.engine_loop()
		p.stream = _streams["__engine"]
	p.volume_db = -10.0
	return p


# ---------------------------------------------------------------- música

## Toca a música "menu" ou "race". Sem arquivo, gera chiptune numa thread (não trava o jogo).
func play_music(song_name: String) -> void:
	if song_name == _music_name and _music_player.playing:
		return
	_music_name = song_name
	var custom := AssetLib.audio("music_" + song_name)
	if custom != null:
		_force_loop(custom)
		_start_music(custom)
		return
	if _music_cache.has(song_name):
		_start_music(_music_cache[song_name])
		return
	_fade_out_music()
	_start_render_if_idle()


func stop_music() -> void:
	_music_name = ""
	_fade_out_music()


func _start_render_if_idle() -> void:
	if _music_thread != null or _song_job != null or _music_name == "" or _music_cache.has(_music_name):
		return
	_rendering_name = _music_name
	if _use_threads:
		_music_thread = Thread.new()
		_music_thread.start(_render_song.bind(_rendering_name))
	else:
		_song_job = SongRender.new(Synth.song(_rendering_name))


func _render_song(song_name: String) -> AudioStreamWAV:
	return Synth.render_song(Synth.song(song_name))


func _process(_delta: float) -> void:
	if not _use_threads:
		_process_slices()
		return
	if _sfx_thread != null and not _sfx_thread.is_alive():
		var done: Dictionary = _sfx_thread.wait_to_finish()
		_sfx_thread = null
		for k in done:
			if not _streams.has(k):
				_streams[k] = done[k]
	if _music_thread != null and not _music_thread.is_alive():
		var stream: AudioStream = _music_thread.wait_to_finish()
		_music_thread = null
		_on_song_ready(stream)


func _on_song_ready(stream: AudioStream) -> void:
	_music_cache[_rendering_name] = stream
	if _rendering_name == _music_name:
		_start_music(stream)
	else:
		_start_render_if_idle()


## Sem threads: sintetiza um pouco por frame (primeiro os efeitos, depois a música).
func _process_slices() -> void:
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < SLICE_BUDGET_USEC:
		if not _prewarm_queue.is_empty():
			var n: String = _prewarm_queue.pop_front()
			if not _streams.has(n):
				_streams[n] = Synth.engine_loop() if n == "__engine" else Synth.make_sfx(n)
		elif _song_job != null:
			if _song_job.process(1):
				var job := _song_job
				_song_job = null
				_on_song_ready(job.get_stream())
		else:
			return


func _start_music(stream: AudioStream) -> void:
	_kill_music_tween()
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = -30.0
	_music_player.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -6.0, 0.8)


func _fade_out_music() -> void:
	_kill_music_tween()
	if not _music_player.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, 0.4)
	_music_tween.tween_callback(_music_player.stop)


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _force_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)


func _exit_tree() -> void:
	if _music_thread != null:
		_music_thread.wait_to_finish()
	if _sfx_thread != null:
		_sfx_thread.wait_to_finish()
