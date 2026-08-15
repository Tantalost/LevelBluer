extends Node
## Autoload singleton registered as "SettingsService".
## Manages user preferences for Audio, Gameplay, Notifications, and Display.

signal settings_changed

const SAVE_PATH := "user://settings.cfg"

var master_volume: int = 80
var sound_enabled: bool = true
var sfx_volume: int = 70
var music_enabled: bool = true

var vibration_enabled: bool = true
var auto_deploy: bool = false
var show_damage_numbers: bool = true

var push_notifications: bool = true
var mission_reminders: bool = true

var high_quality_graphics: bool = true
var show_fps_counter: bool = false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return

	master_volume = cfg.get_value("audio", "master_volume", 80)
	sound_enabled = cfg.get_value("audio", "sound_enabled", true)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 70)
	music_enabled = cfg.get_value("audio", "music_enabled", true)

	vibration_enabled = cfg.get_value("gameplay", "vibration_enabled", true)
	auto_deploy = cfg.get_value("gameplay", "auto_deploy", false)
	show_damage_numbers = cfg.get_value("gameplay", "show_damage_numbers", true)

	push_notifications = cfg.get_value("notifications", "push_notifications", true)
	mission_reminders = cfg.get_value("notifications", "mission_reminders", true)

	high_quality_graphics = cfg.get_value("display", "high_quality_graphics", true)
	show_fps_counter = cfg.get_value("display", "show_fps_counter", false)


func save_settings() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sound_enabled", sound_enabled)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_enabled", music_enabled)

	cfg.set_value("gameplay", "vibration_enabled", vibration_enabled)
	cfg.set_value("gameplay", "auto_deploy", auto_deploy)
	cfg.set_value("gameplay", "show_damage_numbers", show_damage_numbers)

	cfg.set_value("notifications", "push_notifications", push_notifications)
	cfg.set_value("notifications", "mission_reminders", mission_reminders)

	cfg.set_value("display", "high_quality_graphics", high_quality_graphics)
	cfg.set_value("display", "show_fps_counter", show_fps_counter)

	cfg.save(SAVE_PATH)
	settings_changed.emit()


func load_local() -> void:
	load_settings()
