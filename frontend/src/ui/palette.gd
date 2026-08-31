@tool
class_name Palette
extends Node
## Global color palette based on the standardized UI spec.

# Backgrounds & Surfaces
const DEEP_SPACE := Color("#050B18") # Deep background
const NAVY_900 := Color("#0A1730")   # Panel background
const NAVY_800 := Color("#102040")   # Card surface
const NAVY_700 := Color("#173058")   # Borders/raised

# Mission & Fills
const TEAL_900 := Color("#0E2A28")   # Mission fill
const TEAL_800 := Color("#153B37")   # Mission fill alt

# Accents & Interactions
const PRIMARY_BLUE := Color("#2E6BFF") # Primary CTA
const BLUE_400 := Color("#4F8CFF")     # Hover state
const CYAN_400 := Color("#4FE0D4")     # Active/glow
const CYAN_300 := Color("#8FF0E6")     # Icon tint

# Light Elements & Text
const CREAM := Color("#F3ECD6")      # HUD panels
const INK := Color("#101623")        # Text on cream

# System States
const SUCCESS := Color("#33D17A")
const DANGER := Color("#FF5C5C")     # Threat/danger
const WARNING := Color("#FFB648")

# Legacy names — same hex as the spec, so unmigrated screens still parse.
const BG_DEEP := DEEP_SPACE
const GAMEPLAY_BG := DEEP_SPACE
const FOREST_NIGHT := DEEP_SPACE
const FOREST_FLOOR := NAVY_900
const PATH_DIRT := NAVY_700
const PATH_DIRT_LIT := TEAL_800
const CASTLE_STONE := NAVY_700
const CASTLE_SHADOW := NAVY_900
const HEART := DANGER
const BG_STARFIELD := DEEP_SPACE
const BG_PANEL := NAVY_800
const BG_PANEL_ALT := NAVY_900
const BG_HEADER := NAVY_900
const PINE := TEAL_900
const PINE_LIT := TEAL_800
const SKILL_AURA := CYAN_400
const CYAN := CYAN_400
const CYAN_DIM := PRIMARY_BLUE
const GOLD := WARNING
const GOLD_DIM := WARNING
const YELLOW := WARNING
const ORANGE := WARNING
const RED := DANGER
const RED_DEEP := DANGER
const GREEN := SUCCESS
const MAGENTA := PRIMARY_BLUE
const TEXT_PRIMARY := CREAM
const TEXT_SECONDARY := CYAN_300
const TEXT_MUTED := NAVY_700
const TEXT_ON_GOLD := INK
const FIELD_BG := CREAM
const FIELD_TEXT := INK
const FIELD_PLACEHOLDER := CYAN_400
