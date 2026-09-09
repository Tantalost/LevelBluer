@tool
extends ImageTexture
## Shared native TileSet/AtlasTexture dependency backed by the Cloudinary cache.
## A transparent size-only placeholder preserves tile coordinates before sync.
const CACHE_PATH := "user://assets/map_industrial_atlas.png"
const ATLAS_SIZE := Vector2i(2048, 2048)

func _init() -> void:
	if not refresh_from_cache():
		set_image(Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8))

func refresh_from_cache() -> bool:
	if not FileAccess.file_exists(CACHE_PATH):
		return false
	var image := Image.load_from_file(CACHE_PATH)
	if image == null or image.is_empty() or image.get_size() != ATLAS_SIZE:
		return false
	set_image(image)
	return true
