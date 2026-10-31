@tool
extends ImageTexture
## Shared native TileSet/AtlasTexture dependency backed by the Cloudinary cache.
## Falls back to the APK-bundled atlas; a transparent size-only placeholder preserves
## tile coordinates only when neither is usable.
const CACHE_PATH := "user://assets/map_industrial_atlas.png"
const BUNDLED_PATH := "res://assets/bundled/map_industrial_atlas.png"
const ATLAS_SIZE := Vector2i(2048, 2048)

func _init() -> void:
	if not refresh_from_cache():
		set_image(Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8))

func refresh_from_cache(cache_path: String = CACHE_PATH) -> bool:
	var image: Image = Image.load_from_file(cache_path) if FileAccess.file_exists(cache_path) else null
	if image == null or image.is_empty() or image.get_size() != ATLAS_SIZE:
		var bundled: Texture2D = load(BUNDLED_PATH) as Texture2D if ResourceLoader.exists(BUNDLED_PATH) else null
		image = bundled.get_image() if bundled != null else null
	if image == null or image.is_empty() or image.get_size() != ATLAS_SIZE:
		return false
	set_image(image)
	return true
