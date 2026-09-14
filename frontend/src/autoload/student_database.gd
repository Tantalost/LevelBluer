extends Node
## Autoload singleton, registered as "StudentDatabase".
## Local SQLite cache of the `students` row. First login still needs the API;
## after that the signed-in student can play offline from this file.

const DB_PATH := "user://levelblue_students"
const CREATE_STUDENTS_SQL := """
CREATE TABLE IF NOT EXISTS students (
	id TEXT NOT NULL PRIMARY KEY,
	name TEXT NOT NULL,
	section TEXT NOT NULL,
	pre INTEGER DEFAULT 0,
	post INTEGER DEFAULT 0,
	sessions INTEGER DEFAULT 0,
	points INTEGER DEFAULT 0,
	last_active TEXT DEFAULT 'Just now',
	technical INTEGER DEFAULT 0,
	status TEXT DEFAULT 'Needs Review' CHECK (status IN ('On Track', 'Needs Review', 'At Risk')),
	mastery_phishing REAL DEFAULT 0,
	mastery_smishing REAL DEFAULT 0,
	mastery_vishing REAL DEFAULT 0,
	mastery_pretexting REAL DEFAULT 0,
	mastery_baiting REAL DEFAULT 0,
	created_at TEXT DEFAULT (datetime('now')),
	updated_at TEXT DEFAULT (datetime('now')),
	threat_points INTEGER DEFAULT 0,
	upgrade_materials INTEGER DEFAULT 0,
	highest_unlocked_stage INTEGER DEFAULT 1,
	tower_level INTEGER DEFAULT 1,
	glade_level INTEGER DEFAULT 1,
	forge_level INTEGER DEFAULT 1,
	intervention_status TEXT DEFAULT 'NORMAL' CHECK (
		intervention_status IN (
			'NORMAL',
			'AT_RISK',
			'SYSTEM_REMEDIATION',
			'MANUAL_INTERVENTION_REQUIRED'
		)
	),
	requires_password_change INTEGER DEFAULT 1,
	email TEXT UNIQUE,
	first_name TEXT,
	last_name TEXT,
	middle_initial TEXT,
	auth_token TEXT DEFAULT '',
	signed_in INTEGER DEFAULT 0,
	pre_test_completed INTEGER DEFAULT 0,
	module_pretests TEXT DEFAULT '',
	pending_pretest_submits TEXT DEFAULT '',
	pending_password_change INTEGER DEFAULT 0,
	display_name TEXT DEFAULT '',
	needs_cloud_sync INTEGER DEFAULT 0
);
"""

var _db: SQLite
var _ready_ok: bool = false


func _ready() -> void:
	if not ClassDB.class_exists("SQLite"):
		push_warning("StudentDatabase: SQLite addon is not loaded.")
		return
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.verbosity_level = 0
	if not _db.open_db():
		push_warning("StudentDatabase: could not open %s. %s" % [DB_PATH, _db.error_message])
		return
	if not _db.query(CREATE_STUDENTS_SQL):
		push_warning("StudentDatabase: create table failed. %s" % _db.error_message)
		return
	_ensure_column("needs_cloud_sync", "INTEGER DEFAULT 0")
	_ensure_column("module_pretests", "TEXT DEFAULT ''")
	_ensure_column("pending_pretest_submits", "TEXT DEFAULT ''")
	_ready_ok = true


func is_available() -> bool:
	return _ready_ok and _db != null


func load_signed_in_student() -> Dictionary:
	if not is_available():
		return {}
	if not _db.query_with_bindings(
		"SELECT * FROM students WHERE signed_in = ? AND auth_token != '' LIMIT 1;",
		[1],
	):
		push_warning("StudentDatabase: load signed-in failed. %s" % _db.error_message)
		return {}
	var rows: Array = _db.query_result
	if rows.is_empty():
		return {}
	var row: Variant = rows[0]
	if typeof(row) != TYPE_DICTIONARY:
		return {}
	return row


func load_student(student_id: String) -> Dictionary:
	if not is_available() or student_id.is_empty():
		return {}
	if not _db.query_with_bindings("SELECT * FROM students WHERE id = ? LIMIT 1;", [student_id]):
		return {}
	var rows: Array = _db.query_result
	if rows.is_empty():
		return {}
	var row: Variant = rows[0]
	if typeof(row) != TYPE_DICTIONARY:
		return {}
	return row


func upsert_student(row: Dictionary) -> bool:
	if not is_available():
		return false
	var student_id := str(row.get("id", "")).strip_edges()
	if student_id.is_empty():
		return false
	var email := str(row.get("email", "")).strip_edges().to_lower()
	var email_value: Variant = email if not email.is_empty() else null
	var signed_in := 1 if bool(row.get("signed_in", false)) else 0
	if signed_in == 1:
		if not _db.query_with_bindings(
			"UPDATE students SET signed_in = 0 WHERE id != ? AND signed_in = 1;",
			[student_id],
		):
			push_warning("StudentDatabase: clear other sessions failed. %s" % _db.error_message)
	var sql := """
INSERT INTO students (
	id, name, section, pre, post, sessions, points, last_active, technical, status,
	mastery_phishing, mastery_smishing, mastery_vishing, mastery_pretexting, mastery_baiting,
	threat_points, upgrade_materials, highest_unlocked_stage, tower_level, glade_level, forge_level,
	intervention_status, requires_password_change, email, first_name, last_name, middle_initial,
	auth_token, signed_in, pre_test_completed, module_pretests, pending_pretest_submits, pending_password_change, display_name, needs_cloud_sync, updated_at
) VALUES (
	?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
	?, ?, ?, ?, ?,
	?, ?, ?, ?, ?, ?,
	?, ?, ?, ?, ?, ?,
	?, ?, ?, ?, ?, ?, ?, ?, datetime('now')
)
ON CONFLICT(id) DO UPDATE SET
	name = excluded.name,
	section = excluded.section,
	pre = excluded.pre,
	post = excluded.post,
	sessions = excluded.sessions,
	points = excluded.points,
	last_active = excluded.last_active,
	technical = excluded.technical,
	status = excluded.status,
	mastery_phishing = excluded.mastery_phishing,
	mastery_smishing = excluded.mastery_smishing,
	mastery_vishing = excluded.mastery_vishing,
	mastery_pretexting = excluded.mastery_pretexting,
	mastery_baiting = excluded.mastery_baiting,
	threat_points = excluded.threat_points,
	upgrade_materials = excluded.upgrade_materials,
	highest_unlocked_stage = excluded.highest_unlocked_stage,
	tower_level = excluded.tower_level,
	glade_level = excluded.glade_level,
	forge_level = excluded.forge_level,
	intervention_status = excluded.intervention_status,
	requires_password_change = excluded.requires_password_change,
	email = excluded.email,
	first_name = excluded.first_name,
	last_name = excluded.last_name,
	middle_initial = excluded.middle_initial,
	auth_token = excluded.auth_token,
	signed_in = excluded.signed_in,
	pre_test_completed = excluded.pre_test_completed,
	module_pretests = excluded.module_pretests,
	pending_pretest_submits = excluded.pending_pretest_submits,
	pending_password_change = excluded.pending_password_change,
	display_name = excluded.display_name,
	needs_cloud_sync = excluded.needs_cloud_sync,
	updated_at = datetime('now');
"""
	var bindings: Array = [
		student_id,
		str(row.get("name", "Student")),
		str(row.get("section", "")),
		int(row.get("pre", 0)),
		int(row.get("post", 0)),
		int(row.get("sessions", 0)),
		int(row.get("points", 0)),
		str(row.get("last_active", "Just now")),
		1 if bool(row.get("technical", false)) else 0,
		_clamp_status(str(row.get("status", "Needs Review"))),
		float(row.get("mastery_phishing", 0.0)),
		float(row.get("mastery_smishing", 0.0)),
		float(row.get("mastery_vishing", 0.0)),
		float(row.get("mastery_pretexting", 0.0)),
		float(row.get("mastery_baiting", 0.0)),
		int(row.get("threat_points", 0)),
		int(row.get("upgrade_materials", 0)),
		int(row.get("highest_unlocked_stage", 1)),
		int(row.get("tower_level", 1)),
		int(row.get("glade_level", 1)),
		int(row.get("forge_level", 1)),
		_clamp_intervention(str(row.get("intervention_status", "NORMAL"))),
		1 if bool(row.get("requires_password_change", false)) else 0,
		email_value,
		str(row.get("first_name", "")),
		str(row.get("last_name", "")),
		str(row.get("middle_initial", "")),
		str(row.get("auth_token", "")),
		signed_in,
		1 if bool(row.get("pre_test_completed", false)) else 0,
		str(row.get("module_pretests", "")),
		str(row.get("pending_pretest_submits", "")),
		1 if bool(row.get("pending_password_change", false)) else 0,
		str(row.get("display_name", "")),
		1 if bool(row.get("needs_cloud_sync", false)) else 0,
	]
	if not _db.query_with_bindings(sql, bindings):
		push_warning("StudentDatabase: upsert failed. %s" % _db.error_message)
		return false
	return true


func has_pending_sync(student_id: String = "") -> bool:
	if not is_available():
		return false
	if student_id.is_empty():
		if not _db.query("SELECT 1 FROM students WHERE signed_in = 1 AND needs_cloud_sync = 1 LIMIT 1;"):
			return false
	elif not _db.query_with_bindings(
		"SELECT 1 FROM students WHERE id = ? AND needs_cloud_sync = 1 LIMIT 1;",
		[student_id],
	):
		return false
	return not _db.query_result.is_empty()


func mark_needs_sync(student_id: String) -> void:
	if not is_available() or student_id.is_empty():
		return
	if not _db.query_with_bindings(
		"UPDATE students SET needs_cloud_sync = 1 WHERE id = ?;",
		[student_id],
	):
		push_warning("StudentDatabase: mark needs sync failed. %s" % _db.error_message)


func mark_synced(student_id: String) -> void:
	if not is_available() or student_id.is_empty():
		return
	if not _db.query_with_bindings(
		"UPDATE students SET needs_cloud_sync = 0 WHERE id = ?;",
		[student_id],
	):
		push_warning("StudentDatabase: mark synced failed. %s" % _db.error_message)


func clear_session() -> void:
	if not is_available():
		return
	if not _db.query("UPDATE students SET signed_in = 0, auth_token = '', pending_password_change = 0 WHERE signed_in = 1;"):
		push_warning("StudentDatabase: clear session failed. %s" % _db.error_message)


func _ensure_column(column_name: String, declaration: String) -> void:
	if not _db.query("PRAGMA table_info(students);"):
		return
	var rows: Array = _db.query_result
	for i in rows.size():
		var info: Variant = rows[i]
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = info
		if str(row.get("name", "")) == column_name:
			return
	if not _db.query("ALTER TABLE students ADD COLUMN %s %s;" % [column_name, declaration]):
		push_warning("StudentDatabase: add column %s failed. %s" % [column_name, _db.error_message])


static func _clamp_status(status: String) -> String:
	match status:
		"On Track", "Needs Review", "At Risk":
			return status
		_:
			return "Needs Review"


static func _clamp_intervention(status: String) -> String:
	match status:
		"NORMAL", "AT_RISK", "SYSTEM_REMEDIATION", "MANUAL_INTERVENTION_REQUIRED":
			return status
		_:
			return "NORMAL"
