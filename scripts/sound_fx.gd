extends Node

signal cue_played(cue: StringName, player_number: int)

const FIRE_PATH = "res://assets/sfx/fire.wav"
var fire_stream: AudioStream
var story_streams: Dictionary = {}
const STORY = {
	&"treasure": "res://assets/sfx/treasure.wav",
	&"chest": "res://assets/sfx/chest.wav",
	&"disappointment": "res://assets/sfx/disappointment.wav",
	&"royal": "res://assets/sfx/royal.wav",
	&"idea": "res://assets/sfx/idea.wav"
}
var fire_voices: Array[AudioStreamPlayer] = []
var story_voices: Array[AudioStreamPlayer] = []
var fire_index: int = 0
var story_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fire_stream = load(FIRE_PATH)
	for cue in STORY: story_streams[cue] = load(STORY[cue])
	for i in range(6):
		var voice := AudioStreamPlayer.new()
		voice.stream = fire_stream
		voice.volume_db = -9
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		fire_voices.append(voice)
	for i in range(3):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -6
		add_child(voice)
		story_voices.append(voice)

func play_fire(player_number: int = 1) -> void:
	var voice := fire_voices[fire_index]
	fire_index = (fire_index + 1) % fire_voices.size()
	voice.pitch_scale = 0.97 if player_number == 1 else 1.04
	voice.play()
	cue_played.emit(&"fire", player_number)

func play_cue(cue: StringName) -> void:
	if not STORY.has(cue): return
	var voice := story_voices[story_index]
	story_index = (story_index + 1) % story_voices.size()
	voice.stream = story_streams[cue]
	voice.play()
	cue_played.emit(cue, 0)

func stop_story() -> void:
	for voice in story_voices: voice.stop()

func stop_all() -> void:
	stop_story()
	for voice in fire_voices: voice.stop()
