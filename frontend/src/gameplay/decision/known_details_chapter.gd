extends RefCounted
## Coached source comparison. Completion never submits a BKT observation.
const ID: String = "mod_03_ch_02"
const NUMBER: int = 2
const TITLE: String = "They Know My Name"
const PROTAGONIST: String = "Liza"
const PHONE_PATH: String = "res://src/gameplay/decision/known_details_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod3_library_research_v1"
const NIGHT_BACKGROUND: String = "mod3_library_research_v1"
const MORNING: bool = true
const DAY_LABEL: String = "AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "Knowing your name is not permission."
const FIRST_PHASE: String = "sources"
const NEXT_CHAPTER: String = "mod_03_ch_03"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "sources":{"title":"01 / Match the public details","tip":"Select a caller detail, then its matching field in the public club post. Name, role and date were all public.","line":"Who else could have seen this?","field":"flags","total":1,"next":"permission"},
 "permission":{"title":"02 / Knowledge or permission?","tip":"Knowing a public detail does not verify a role or grant access to an account.","line":"A name is not an access pass.","field":"domains","total":1,"next":"preserve"},
 "preserve":{"title":"03 / Preserve the comparison","tip":"The post shows the details could be copied. It does not show who copied them or identify the caller.","line":"Record what the sources support.","field":"captures","total":1,"next":"seal"}
}
const CALLER_EXCERPT: String = "Liza, event expense coordinator for 6 November? We have your event details on file. You're speaking with the right security team. Authorize us to access your wallet so we can protect the event funds."
const PUBLIC_POST: String = "SCHOOL CLUB / PUBLIC ANNOUNCEMENT\nPublished before the unexpected call\nEvent volunteer: Liza\nRole: Event expense coordinator\nEvent date: 6 November"
const DETAILS: Array[Dictionary] = [
 {"id":"name","caller":"Liza","post":"Event volunteer: Liza"},
 {"id":"role","caller":"Event expenses","post":"Role: Event expense coordinator"},
 {"id":"date","caller":"6 November","post":"Event date: 6 November"}
]
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"public","sender":"Account Security (unverified)","address":"New voicemail","subject":"Public details / claimed permission","body":CALLER_EXCERPT,"phrase":"Knowing details does not authorize account access.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Liza","face":4,"bg":"mod3_covered_walkway_v1","cast":["liza"],"caption":"After the call. The covered walkway outside the briefing room.","line":"I chose the wallet app's Support route. Before I could check with them, a new voicemail arrived. My phone apparently doesn't believe in breathing room.","art":"story_bg_mod3_covered_walkway_v1"},
 {"who":"Liza","face":3,"bg":"mod3_covered_walkway_v1","cast":["liza"],"line":"Another message under Account Security. Still just a displayed label.","mail":true,"art":"story_bg_mod3_covered_walkway_v1"},
 {"who":"Liza","face":2,"bg":"mod3_covered_walkway_v1","cast":["liza","john"],"line":"They knew the event. I didn't tell them that.","art":"story_bg_mod3_covered_walkway_v1"},
 {"who":"John","face":4,"bg":"mod3_covered_walkway_v1","cast":["liza","john"],"line":"Who else could have seen it?","art":"story_bg_mod3_covered_walkway_v1"},
 {"who":"Liza","face":4,"bg":"mod3_library_research_v1","cast":["liza","john"],"caption":"The library research corner. A few minutes later.","line":"Here's the club announcement. Public. My name, my role, the date. I was worried about a secret. We made it a poster.","art":"story_bg_mod3_library_research_v1"},
 {"who":"Liza","face":1,"bg":"mod3_library_research_v1","cast":["liza"],"line":"So they did their homework. That doesn't make them the teacher.","art":"story_bg_mod3_library_research_v1"},
 {"who":"John","face":0,"bg":"mod3_library_research_v1","cast":["liza","john"],"line":"The post explains where someone could find those details. It doesn't tell us who called.","art":"story_bg_mod3_library_research_v1"},
 {"who":"Liza","face":5,"bg":"mod3_library_research_v1","cast":["liza"],"line":"Let's save the comparison. Knowing about me isn't permission to get into my account.","art":"story_bg_mod3_library_research_v1"}
]
const EVIDENCE: String = "01 · Liza's name, event role and date were in the public club announcement before the voicemail.\n02 · The caller uses that knowledge to claim a security role and ask for account access. Neither is verified by public details.\n03 · Liza preserves the independently opened post beside the new voicemail.\n\nThe comparison shows a possible public source, not proof of how the caller obtained it. The caller's identity remains unknown; the post's author is not implicated."
const SEAL_LINE: String = "They know the announcement. They don't own my trust."
const SLEEP_LINE: String = "The public post and the voicemail are saved together. No permission to access my wallet was given.\n\nI still need the service's independent response. A familiar detail doesn't answer for them."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "public" else {}

static func suspicious_ids() -> Array[String]:
	return ["public"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("public"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var preceding: bool = true
	for field: String in ["read","flags","domains","captures"]:
		var values: Variant = raw.get(field, [])
		if field == "flags":
			var matches: Variant = raw.get("sorted", [])
			preceding = preceding and matches is Array and matches.has("name") and matches.has("role") and matches.has("date")
		if field == "captures":
			var matches: Variant = raw.get("sorted", [])
			preceding = preceding and matches is Array and matches.has("limits")
		preceding = preceding and values is Array and values.has("public")
		if preceding: state[field] = ["public"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	var saved_matches: Variant = raw.get("sorted", [])
	if saved_matches is Array and not state.read.is_empty():
		for item: String in ["name","role","date","limits"]:
			if saved_matches.has(item) and (item != "limits" or not state.domains.is_empty()): state.sorted.append(item)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","sources","permission","preserve","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["permission","preserve","seal","sleep","done"] and state.flags.is_empty(): state.phase = "sources"
	if state.phase in ["preserve","seal","sleep","done"] and state.domains.is_empty(): state.phase = "permission"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "preserve"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
