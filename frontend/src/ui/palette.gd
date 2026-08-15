class_name Palette
extends RefCounted
## Every colour in Level Blue lives here. Sampled from the MVP screens.
##
## Nothing else in the project should contain a hex literal. When the art
## direction shifts, this is the only file that changes.

# Surfaces
const BG_DEEP := Color("080D18")        # page background, behind everything
const BG_PANEL := Color("14263C")       # standard card / panel fill
const BG_PANEL_ALT := Color("0F1E30")   # recessed panel, input backgrounds
const BG_HEADER := Color("0B1524")      # screen header bar

# Accents
const CYAN := Color("4EC3F7")           # lessons, primary borders, links
const CYAN_DIM := Color("2A7BA0")       # inactive / disabled cyan
const GOLD := Color("F0B23C")           # primary actions, codex, currency
const GOLD_DIM := Color("8A6520")       # disabled gold
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
