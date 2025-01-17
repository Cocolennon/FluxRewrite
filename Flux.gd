extends Node

var maps = []
var notesets = {}
var current_map = {}
var transition_time:float = 1
var fullscreen = false
var update_selected_map = false

const version_string = "FluxRewrite v0.3 ALPHA"

var cursor_info: Dictionary = {
	"x": 0.0, # m
	"y": 0.0, # m
	"w": 0.2625, # m
	"h": 0.2625, # m
}

var map_finished_info = {
	"max_combo": 0,
	"misses": 0,
	"accuracy": 0,
	"passed": false,
	"played": false,
}

var game_stats = {
	"misses": 0,
	"hits": 0,
	"combo": 0,
	"max_combo": 0,
	
	"hp": 0.0,
	"max_hp": 5.0,
	"hp_per_hit": 0.5,
	"hp_per_miss": 1.0,
}

var default_settings = {
	"note": {
		"ar": 10.0, # m/s
		"sd": 4.0, # m
		"approach_time": 0.0, # s
		"fade": false,
	},
	"debug": {
		"show_note_hitbox": false,
		"show_cursor_hitbox": false,
	},
	"game": {
		"hitwindow": 58, # ms
		"hitbox": 1.14, # m
		"wait_time": 1.5, # s
		"parallax": 0.25,
		"spin": false,
	},
	"cursor": {
		"sensitivity": 1.0, # m/s
		"scale": 1.9, # m
	},
	"ui": {
		"enable_ruwo": true,
	},
	"sets": {
		"noteset": "default"
	},
	"audio": {
		"music_volume": 0.5, # %
	}
}

var settings = default_settings

var mods = {
	"speed": 1.0, # %
	"seek": 0, # s
	"endseek": -1, # s
}

func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
func _process(_delta):
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		fullscreen = !fullscreen

func get_setting(category:String, setting:String):
	if setting in settings.get(category):
		return settings.get(category).get(setting)
	else:
		return default_settings.get(category).get(setting)

func reload_game():
	get_tree().change_scene_to_file("res://scenes/Loading.tscn")

func reload_game_stylish():
	if $"..".has_node("Transition"):
		$"../Transition".transition_out()
		await get_tree().create_timer(transition_time).timeout
		get_tree().change_scene_to_file("res://scenes/Loading.tscn")

func ms_to_min_sec_str(ms):
	var mins = int(float(ms) * 0.001) / 60
	var secs = int(float(ms) * 0.001) % 60
	return str(mins) + ":" + ("%02d" % secs)

func get_map_len_str(map):
	var map_len = "err:err"
	if len(map.diffs.default) > 0:
		map_len = Flux.ms_to_min_sec_str(map.diffs.default[-1].ms)
	return map_len
	
	
enum AudioFormat {
	OGG,
	WAV,
	MP3,
	UNKNOWN,
}

# got this from kermeet. Thanks :3
func get_ogg_packet_sequence(data:PackedByteArray):
	var packets = []
	var granule_positions = []
	var sampling_rate = 0
	var pos = 0
	while pos < data.size():
		var header = data.slice(pos, pos + 27)
		pos += 27
		if header.slice(0, 4) != "OggS".to_ascii_buffer():
			break

		var packet_type = header.decode_u8(5)
		var granule_position = header.decode_u64(6)

		granule_positions.append(granule_position)

		var segment_table_length = header.decode_u8(26)

		var segment_table = data.slice(pos, pos + segment_table_length)
		pos += segment_table_length

		var packet_data = []
		var appending = false
		for i in range(segment_table_length):
			var segment_size = segment_table.decode_u8(i)
			var segment = data.slice(pos, pos + segment_size)
			if appending: packet_data.back().append_array(segment)
			else: packet_data.append(segment)
			appending = segment_size == 255
			pos += segment_size

		packets.append(packet_data)
		if sampling_rate == 0 and packet_type == 2:
			var info_header = packet_data[0]
			if info_header.slice(1, 7).get_string_from_ascii() != "vorbis":
				break
			sampling_rate = info_header.decode_u32(12)
	var packet_sequence = OggPacketSequence.new()
	packet_sequence.sampling_rate = sampling_rate
	packet_sequence.granule_positions = granule_positions
	packet_sequence.packet_data = packets
	return packet_sequence

func get_audio_format(buffer:PackedByteArray):
	if buffer.slice(0,4) == PackedByteArray([0x4F,0x67,0x67,0x53]): return AudioFormat.OGG

	if (buffer.slice(0,4) == PackedByteArray([0x52,0x49,0x46,0x46])
	and buffer.slice(8,12) == PackedByteArray([0x57,0x41,0x56,0x45])): return AudioFormat.WAV

	if (buffer.slice(0,2) == PackedByteArray([0xFF,0xFB])
	or buffer.slice(0,2) == PackedByteArray([0xFF,0xF3])
	or buffer.slice(0,2) == PackedByteArray([0xFF,0xFA])
	or buffer.slice(0,2) == PackedByteArray([0xFF,0xF2])
	or buffer.slice(0,3) == PackedByteArray([0x49,0x44,0x33])): return AudioFormat.MP3

	return AudioFormat.UNKNOWN
