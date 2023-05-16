extends Node

@onready var note_scene = preload("res://scenes/NoteSprite.tscn")

var note_index = 0

func _ready():
	for note in Flux.current_map.diffs["default"]:
		note["st"] = note["ms"] - ((Flux.settings["note"]["approach_time"]) * Flux.mods["speed"]) * 1000.0
	
func _process(_delta):
	if Flux.current_map == {}:
		return
	
	if note_index + 1 >= len(Flux.current_map.diffs.default):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	
	var noteset = Flux.notesets[Flux.settings.sets.noteset]
	
	if Flux.audio_manager.current_time > Flux.current_map.diffs["default"][note_index].st:
		var ndata = Flux.current_map.diffs["default"][note_index]
		var note = note_scene.instantiate()
		note.spawn_time = Flux.current_map.diffs["default"][note_index].st
		note.index = note_index
		note.hittable = false
		note.ms = ndata.ms
		note.texture = noteset[note_index % len(noteset)]
		add_child(note)
		note_index += 1
	for child in get_children():
		child.update(Flux.audio_manager.current_time)
