class_name UiScale
extends RefCounted
## Responsive scaling helper — mirrors the React Native dashboard's BASE_WIDTH = 932.

const BASE_WIDTH := 932.0


static func factor(viewport_width: float) -> float:
	if viewport_width <= 0.0:
		return 1.0
	return viewport_width / BASE_WIDTH


static func n(size: float, viewport_width: float) -> int:
	return int(round(size * factor(viewport_width)))


static func bw(size: float, viewport_width: float) -> int:
	return maxi(1, n(size, viewport_width))
