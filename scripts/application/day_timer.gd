class_name DayTimer
extends Node

signal time_updated(seconds_remaining: float)
signal timed_out

var duration_seconds: float = 10.0
var seconds_remaining: float = 0.0
var running: bool = false

func start(new_duration_seconds: float = 10.0) -> void:
	duration_seconds = maxf(0.1, new_duration_seconds)
	seconds_remaining = duration_seconds
	running = true
	time_updated.emit(seconds_remaining)

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running:
		return
	seconds_remaining = maxf(0.0, seconds_remaining - delta)
	time_updated.emit(seconds_remaining)
	if seconds_remaining <= 0.0:
		running = false
		timed_out.emit()