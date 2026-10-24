extends Node

const LOG_DIRECTORY := "user://logs"

class PlayerFileLogger extends Logger:
	var log_file: FileAccess

	func _init(file: FileAccess) -> void:
		log_file = file

	func _log_message(message: String, error: bool) -> void:
		_write_line("ERROR" if error else "INFO", message)

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array,
	) -> void:
		var message := code
		if not rationale.is_empty():
			message += " | " + rationale
		var location := "%s:%d @ %s" % [file, line, function]
		_write_line("ERROR", "Runtime error (%d): %s (%s)" % [error_type, message, location])

	func _write_line(level: String, message: String) -> void:
		if log_file == null:
			return
		log_file.store_line("[%s] %s: %s" % [Time.get_datetime_string_from_system(), level, message])
		log_file.flush()


var _file_logger: PlayerFileLogger
var _session_log_path := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var absolute_directory := ProjectSettings.globalize_path(LOG_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return
	_session_log_path = _make_session_log_path()
	var log_file := FileAccess.open(_session_log_path, FileAccess.WRITE)
	if log_file == null:
		return
	_file_logger = PlayerFileLogger.new(log_file)
	OS.add_logger(_file_logger)
	print("StockTroder runtime log started")


func log_directory_path() -> String:
	return ProjectSettings.globalize_path(LOG_DIRECTORY)


func session_log_filename() -> String:
	return _session_log_path.get_file()


func _make_session_log_path() -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var base_name := "session-%s-%d" % [timestamp, OS.get_process_id()]
	var log_path := LOG_DIRECTORY + "/" + base_name + ".log"
	var suffix := 1
	while FileAccess.file_exists(log_path):
		log_path = LOG_DIRECTORY + "/%s-%d.log" % [base_name, suffix]
		suffix += 1
	return log_path