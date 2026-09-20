## Validation for context-gated narrative.
##
## A conventional "can the player reach the end?" graph walk is not enough here,
## because our dialogue does not gate on a linear prerequisite chain — it gates
## on the *state of the world* (assets, belief, standing, stats, flags). A knot
## can be perfectly reachable on the graph and still be dead content because no
## achievable combination of context ever satisfies its condition.
##
## So there are two passes:
##
##   static_check()  — cheap structural checks on the compiled story and its
##                     sources: unsatisfied EXTERNALs, diverts to knots that do
##                     not exist, knots nothing ever diverts to (orphans).
##
##   simulate()      — plays the story repeatedly across a generated grid of
##                     context states and records what was actually reached.
##                     Catches content that is unreachable only under specific
##                     conditions.
##
## Both return plain Dictionaries; `format_report()` turns them into something a
## writer can read without opening a raw log.
class_name CoreInkValidator
extends RefCounted

## Targets the runtime provides implicitly; not a missing knot.
const BUILTIN_TARGETS := ["DONE", "END"]


# --- Static pass ---------------------------------------------------------------

## Structural check of a compiled `.ink.json` plus the `.ink` sources that
## produced it. The compiled container does not retain EXTERNAL declarations in
## a readable form, so the source files are where those are checked.
static func static_check(compiled_path: String, source_paths: Array,
		bound_functions: Array) -> Dictionary:
	var findings: Array[Dictionary] = []

	var json := _read(compiled_path)
	if json == "":
		findings.append(_finding("error", "story", compiled_path,
				"Compiled story could not be read. Has it been compiled?"))
		return _result(findings, {})

	if JSON.parse_string(json) == null:
		findings.append(_finding("error", "story", compiled_path,
				"Compiled story is not valid JSON."))
		return _result(findings, {})

	# EXTERNALs the story declares but the game never binds: a guaranteed
	# runtime failure the moment the story reaches that call.
	var declared := _declared_externals(source_paths)
	for fn_name in declared:
		if fn_name not in bound_functions:
			findings.append(_finding("error", "external", fn_name,
					"Story declares EXTERNAL %s(...) but nothing binds it." % fn_name))

	var knots := _declared_knots(source_paths)
	var targets := _divert_targets(source_paths)

	# Knots nothing ever points at.
	for knot in knots:
		if knot in BUILTIN_TARGETS:
			continue
		if not targets.has(knot):
			findings.append(_finding("warning", "orphan", knot,
					"Knot '%s' is never diverted to. Dead content, or only " % knot
					+ "ever entered dynamically?"))

	# Diverts pointing at something that does not exist.
	for target in targets:
		if target in BUILTIN_TARGETS:
			continue
		var root: String = target.split(".")[0]
		if root not in knots:
			findings.append(_finding("error", "broken_divert", target,
					"Divert to '%s', which is not a knot in these files." % target))

	return _result(findings, {"knots": knots.size(), "externals": declared.size()})


# --- Context simulation --------------------------------------------------------

## Build the cross-product of context axes, e.g.
##   {
##     "assets":    {"zorkmid": [0, 3]},
##     "knowledge": {"know_trapdoor": [false, true]},
##     "standing":  {"fence": [0.0, 40.0]},
##   }
## Capped by [param max_cases] so a wide game cannot accidentally request a
## million playthroughs.
static func build_cases(axes: Dictionary, max_cases: int = 256) -> Array:
	var dimensions: Array = []
	for group in axes:
		# Authored axes files carry "_comment" keys and other scalars; only
		# dictionaries-of-lists describe real dimensions.
		if not (axes[group] is Dictionary):
			continue
		for key in axes[group]:
			if axes[group][key] is Array:
				dimensions.append({"group": group, "key": key, "values": axes[group][key]})

	var cases: Array = [{}]
	for dim in dimensions:
		var expanded: Array = []
		for base in cases:
			for value in dim["values"]:
				if expanded.size() >= max_cases:
					break
				var next: Dictionary = base.duplicate(true)
				if not next.has(dim["group"]):
					next[dim["group"]] = {}
				next[dim["group"]][dim["key"]] = value
				expanded.append(next)
		cases = expanded
		if cases.size() >= max_cases:
			break
	return cases


## Play the story once per context case and record what each one reached.
##
## [param play] is a Callable taking one context Dictionary and returning the
## Array of labels (knot names, choice texts) that case visited. Keeping the
## playing itself in the caller is deliberate: the validator stays agnostic
## about how a given game seeds its world.
static func simulate(cases: Array, play: Callable) -> Dictionary:
	var reached := {}
	var per_case: Array[Dictionary] = []

	for context in cases:
		var visited = play.call(context)
		var labels: Array = visited if visited is Array else []
		for label in labels:
			if not reached.has(label):
				reached[label] = []
			reached[label].append(context)
		per_case.append({"context": context, "reached": labels})

	return {"reached": reached, "cases": per_case, "case_count": cases.size()}


## Everything the story contains, minus everything the simulation reached.
## This is the finding a static graph walk cannot produce.
static func unreachable_report(all_labels: Array, simulation: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var reached: Dictionary = simulation.get("reached", {})
	for label in all_labels:
		if not reached.has(label):
			findings.append(_finding("warning", "context_unreachable", str(label),
					"'%s' was not reached under any of the %d simulated context states."
					% [label, int(simulation.get("case_count", 0))]))
	return findings


## For content that *was* reached, describe the narrowest conditions that did
## it — so a writer can see "this only ever fires when standing is 40".
static func conditions_for(label: String, simulation: Dictionary) -> Array:
	var reached: Dictionary = simulation.get("reached", {})
	return reached.get(label, [])


# --- Reporting -----------------------------------------------------------------

## Render findings as plain text a writer can act on without reading raw logs.
static func format_report(title: String, findings: Array, summary: Dictionary = {}) -> String:
	var errors: Array = []
	var warnings: Array = []
	for f in findings:
		if str(f.get("severity", "")) == "error":
			errors.append(f)
		else:
			warnings.append(f)

	var lines: Array[String] = []
	lines.append("=".repeat(72))
	lines.append(title)
	lines.append("=".repeat(72))
	if not summary.is_empty():
		var bits: Array[String] = []
		for k in summary:
			bits.append("%s: %s" % [k, summary[k]])
		lines.append("  " + "    ".join(bits))
	lines.append("")

	if errors.is_empty() and warnings.is_empty():
		lines.append("  No problems found.")
		lines.append("")

	for group in [["ERRORS", errors], ["WARNINGS", warnings]]:
		var items: Array = group[1]
		if items.is_empty():
			continue
		lines.append("%s (%d)" % [group[0], items.size()])
		lines.append("-".repeat(72))
		for f in items:
			lines.append("  [%s] %s" % [f.get("kind", "?"), f.get("subject", "?")])
			lines.append("      %s" % f.get("message", ""))
		lines.append("")

	return "\n".join(lines)


static func has_errors(findings: Array) -> bool:
	for f in findings:
		if str(f.get("severity", "")) == "error":
			return true
	return false


# --- Internals -----------------------------------------------------------------

static func _result(findings: Array[Dictionary], summary: Dictionary) -> Dictionary:
	return {"findings": findings, "summary": summary}


static func _finding(severity: String, kind: String, subject: String,
		message: String) -> Dictionary:
	return {"severity": severity, "kind": kind, "subject": subject, "message": message}


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


static func _declared_externals(source_paths: Array) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("^\\s*EXTERNAL\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(")
	for path in source_paths:
		for line in _read(str(path)).split("\n"):
			var m := re.search(line)
			if m != null and m.get_string(1) not in out:
				out.append(m.get_string(1))
	return out


## Every divertable target declared in the sources. Ink offers three, and all
## three are legitimate divert destinations:
##
##   === name ===     a knot
##   = name           a stitch, addressable from inside its parent knot
##   - (name)         a gather label, the usual way to write a hub
##
## Recognising only knots made any file built from stitches and gathers - the
## normal shape for a conversation hub - look like a wall of broken diverts.
static func _declared_knots(source_paths: Array) -> Array[String]:
	var out: Array[String] = []
	var knot_re := RegEx.create_from_string("^\\s*===+\\s*([A-Za-z_][A-Za-z0-9_]*)")
	var stitch_re := RegEx.create_from_string("^\\s*=\\s*([A-Za-z_][A-Za-z0-9_]*)")
	var label_re := RegEx.create_from_string("^\\s*[-*+]+\\s*\\(([A-Za-z_][A-Za-z0-9_]*)\\)")
	for path in source_paths:
		for line in _read(str(path)).split("\n"):
			var m := knot_re.search(line)
			if m == null:
				# A stitch: one leading '=', not two or more.
				m = stitch_re.search(line)
			if m == null:
				# A gather or choice label: - (hub), * (opt), + (opt).
				m = label_re.search(line)
			if m != null and m.get_string(1) not in out:
				out.append(m.get_string(1))
	return out


## Every divert/tunnel target mentioned in the sources. Comment lines are
## skipped so documentation examples do not register as broken diverts.
static func _divert_targets(source_paths: Array) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("->\\s*([A-Za-z_][A-Za-z0-9_.]*)")
	for path in source_paths:
		for line in _read(str(path)).split("\n"):
			if line.strip_edges().begins_with("//"):
				continue
			for m in re.search_all(line):
				out[m.get_string(1)] = true
	return out
