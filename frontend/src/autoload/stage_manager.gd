extends Node
## Autoload singleton, registered as "StageManager".
## Stage configs and combat tables are loaded from ContentDB JSON.


func get_stage_config(stage_id: int) -> Dictionary:
	return ContentDB.get_stage(str(stage_id))
