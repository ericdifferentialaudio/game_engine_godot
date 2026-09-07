## Player faction's intel journal: grouped by subject, shows reliability,
## staleness, provenance chain and contradictions. Filter by category/tag.
extends PanelContainer

@onready var _list: RichTextLabel = %JournalText
@onready var _filter: LineEdit = %FilterEdit


func _ready() -> void:
	_filter.text_changed.connect(func(_t): refresh())


func refresh() -> void:
	var holder := GameManager.player_faction_id
	var journal := IntelRegistry.journal_for(holder)
	if journal == null:
		_list.text = "No journal."
		return
	var now := GameClock.now()
	var filter := _filter.text.strip_edges().to_lower()
	var by_subject := {}
	for tok in journal.tokens.values():
		if filter != "" and not (filter in tok.title.to_lower() or filter in tok.subject.to_lower() or filter in tok.category.to_lower() or filter in ",".join(tok.tags).to_lower()):
			continue
		if not by_subject.has(tok.subject):
			by_subject[tok.subject] = []
		by_subject[tok.subject].append(tok)
	var contradictions := journal.contradictions()
	var out := "[b]Intel Journal — %d tokens, %d contradictions[/b]\n\n" % [journal.tokens.size(), contradictions.size()]
	var subjects := by_subject.keys()
	subjects.sort()
	for subject in subjects:
		out += "[color=#ffd166][b]%s[/b][/color]\n" % subject
		for tok in by_subject[subject]:
			var flags := PackedStringArray()
			if tok.known_false:
				flags.append("[color=#ff6b6b]FALSE[/color]")
			if tok.is_stale(now):
				flags.append("[color=#aaaaaa]stale[/color]")
			for c in tok.conflicts:
				if journal.has(c):
					flags.append("[color=#ff9f43]conflicts: %s[/color]" % c)
			out += "  • [b]%s[/b] (%s, %s) — %.0f%% %s\n" % [tok.title, tok.category, tok.scope, tok.reliability * 100.0, " ".join(flags)]
			if tok.summary != "":
				out += "      [i]%s[/i]\n" % tok.summary
			var prov := PackedStringArray()
			for p in tok.provenance:
				prov.append("%s via %s @T%d" % [p.source_id if p.source_id != "" else "?", p.channel, int(p.turn)])
			if not prov.is_empty():
				out += "      [color=#8ecae6]%s[/color]\n" % " → ".join(prov)
			if not tok.facts.is_empty():
				out += "      facts: %s\n" % JSON.stringify(tok.facts)
		out += "\n"
	_list.text = out
