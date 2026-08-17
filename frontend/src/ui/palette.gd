class_name Palette
extends RefCounted
## Every colour in Level Blue lives here. Sampled from the MVP screens.
##
## Nothing else in the project should contain a hex literal. When the art
## direction shifts, this is the only file that changes.

# Surfaces
const BG_DEEP := Color("080D18")        # page background, behind everything
const GAMEPLAY_BG := Color("0f0f15")    # opaque TD floor; blocks UI bleed under the grid
const FOREST_NIGHT := Color("12081C")   # gameplay clearing sky / deep shade
const FOREST_FLOOR := Color("1A1430")   # grass in the playable clearing
const PATH_DIRT := Color("5C3A32")      # enemy track
const PATH_DIRT_LIT := Color("7A5244")  # path highlight
const CASTLE_STONE := Color("6A6E78")   # player base keep
const CASTLE_SHADOW := Color("3A3E48")  # keep recesses
const HEART := Color("E889B8")          # base-health pip over the castle
const BG_STARFIELD := Color("0B0714")   # stage-select / skill-tree night sky
const BG_PANEL := Color("14263C")       # standard card / panel fill
const BG_PANEL_ALT := Color("0F1E30")   # recessed panel, input backgrounds
const BG_HEADER := Color("0B1524")      # screen header bar
const PINE := Color("1C4F4A")           # stage-dock tree fill
const PINE_LIT := Color("2F7A6A")       # stage-dock tree highlight
const SKILL_AURA := Color("7EF0FF")     # selected skill-node glow

# Accents
const CYAN := Color("4EC3F7")           # lessons, primary borders, links
const CYAN_DIM := Color("2A7BA0")       # inactive / disabled cyan
const GOLD := Color("F0B23C")           # primary actions, codex, currency
const GOLD_DIM := Color("8A6520")       # disabled gold
const YELLOW := Color("E8C84A")         # fast packets
const ORANGE := Color("D97A2A")         # heavy packets
const RED := Color("C94B4B")            # security alert, errors
const RED_DEEP := Color("5E1A1A")       # alert header fill
const GREEN := Color("4CD98A")          # success, rank, satisfied rules
const MAGENTA := Color("C64FD9")        # streak / tertiary stat

# Text
const TEXT_PRIMARY := Color("F2F5F8")
const TEXT_SECONDARY := Color("8FA3B8")
const TEXT_MUTED := Color("5A6E85")
const TEXT_ON_GOLD := Color("1A1206")   # dark text on the gold buttons

# Input fields — the near-white boxes in the login and password screens
const FIELD_BG := Color("F2F0E9")
const FIELD_TEXT := Color("1A2333")
const FIELD_PLACEHOLDER := Color("6FA8C7")
