class_name DialogueEmotion
extends RefCounted
## Data-driven emotional presentation for decision-story dialogue lines.
## Every dialogue line may optionally carry an "emotion" string; this class
## is the single place that validates/normalizes it and holds the ONE
## centralized table of presentation numbers (typing pace, pauses, shake).
## Nothing here touches gameplay state — decision outcomes, mastery/BKT,
## Tower Defense, or save/progression — this is presentation-only, read
## purely from authored dialogue data.
##
## STORY AUTHORING RULE (Module 3-5): use strong emotions sparingly.
##   - neutral / worried / frustrated may appear often — they're the
##     everyday register of a tense conversation.
##   - angry / shocked / scared belong at meaningful escalation points,
##     not on every line of a tense scene.
##   - crying is reserved for a stage's earned emotional peak, not a
##     routine reaction — use it once a scene, if at all.
##   - determined / relieved mark recovery/resolution beats.
## Emotion must NEVER indicate SAFE/RISKY/CRITICAL correctness. There is no
## outcome-based emotion mapping anywhere in this system, and authors must
## not invent one (e.g. always tagging RISKY lines "worried").

const NEUTRAL := "neutral"
const VALID_EMOTIONS: PackedStringArray = [
	"neutral", "worried", "shocked", "scared", "angry",
	"crying", "sad", "frustrated", "determined", "relieved",
]

## The ONE centralized table of presentation defaults per emotion. Story and
## engine code always read a value through profile()/typing_speed()/
## pause_before()/pause_after() rather than hardcoding a number inline, so
## every tuning pass touches exactly this table.
##   typing_speed  — multiplier on the normal per-character reveal rate.
##   pause_before  — brief hold (seconds) before a line starts revealing;
##                   a tap/click during it still jumps straight to the full
##                   line, exactly like skipping mid-type (see
##                   decision_workspace.gd's existing skip handling).
##   pause_after   — a short beat (seconds) folded into that same hold
##                   budget for how "weighty" a line should feel; kept as
##                   authored data for callers that want it, but nothing in
##                   this milestone blocks player input on it — the brief is
##                   explicit that no line should make the player wait.
const PROFILES: Dictionary = {
	"neutral":    {"typing_speed": 1.00, "pause_before": 0.00, "pause_after": 0.00},
	"worried":    {"typing_speed": 0.90, "pause_before": 0.00, "pause_after": 0.00},
	"shocked":    {"typing_speed": 1.00, "pause_before": 0.10, "pause_after": 0.15},
	"scared":     {"typing_speed": 0.88, "pause_before": 0.00, "pause_after": 0.00},
	"angry":      {"typing_speed": 1.15, "pause_before": 0.00, "pause_after": 0.05},
	"crying":     {"typing_speed": 0.75, "pause_before": 0.05, "pause_after": 0.30},
	"sad":        {"typing_speed": 0.85, "pause_before": 0.00, "pause_after": 0.10},
	"frustrated": {"typing_speed": 1.05, "pause_before": 0.00, "pause_after": 0.00},
	"determined": {"typing_speed": 1.05, "pause_before": 0.00, "pause_after": 0.05},
	"relieved":   {"typing_speed": 0.95, "pause_before": 0.00, "pause_after": 0.15},
}


## Reads and validates the "emotion" field from a dialogue line dictionary.
## A missing key (every Module 1/2 line authored before this system existed)
## or an unrecognized value both fall back to NEUTRAL — no existing story
## content needs to be rewritten.
static func of(line: Dictionary) -> String:
	return normalize(str(line.get("emotion", "")))


static func normalize(emotion: String) -> String:
	var trimmed: String = emotion.strip_edges().to_lower()
	return trimmed if VALID_EMOTIONS.has(trimmed) else NEUTRAL


## The full presentation profile for an emotion. Always returns a valid
## dictionary — an unrecognized emotion resolves to the neutral profile.
static func profile(emotion: String) -> Dictionary:
	var key: String = normalize(emotion)
	return PROFILES.get(key, PROFILES[NEUTRAL])


static func typing_speed(emotion: String) -> float:
	return float(profile(emotion).get("typing_speed", 1.0))


static func pause_before(emotion: String) -> float:
	return float(profile(emotion).get("pause_before", 0.0))


static func pause_after(emotion: String) -> float:
	return float(profile(emotion).get("pause_after", 0.0))


## The emotions whose presentation includes a brief, generic screen-level
## shake (see DialogueScreenShake). Every other emotion is portrait-only.
## angry gets a short, small shake; shocked gets a much tinier one, per the
## brief's "very tiny screen impact" for shocked vs. angry's own shake.
static func shake_profile(emotion: String) -> Dictionary:
	match normalize(emotion):
		"angry":
			return {"intensity": 6.0, "duration": 0.22}
		"shocked":
			return {"intensity": 2.0, "duration": 0.12}
		_:
			return {}
