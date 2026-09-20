## CoreIntelQuery: legacy aliases and the `era` key.
##
## Guards the fix for CR-001. The isometric engine's older `IntelQuery` knew
## `faction_flag`, `turn` and `era`; core did not. Identical query JSON could
## therefore pass in one engine and silently return false in the other,
## because `_leaf()` falls through to `false` for an unrecognised key - a
## failure with no error message anywhere.
##
## Core now owns all three: `era` outright, and the other two as aliases.
extends GutTest


func test_aliases_resolve_to_canonical_keys() -> void:
	assert_eq(CoreIntelQuery.canonical_key({"faction_flag": "met_elders"}),
		"holder_flag", "faction_flag is the old spelling of holder_flag")
	assert_eq(CoreIntelQuery.canonical_key({"turn": [">=", 10]}),
		"time", "turn is the old spelling of time")


func test_canonical_keys_resolve_to_themselves() -> void:
	assert_eq(CoreIntelQuery.canonical_key({"holder_flag": "x"}), "holder_flag")
	assert_eq(CoreIntelQuery.canonical_key({"time": [">=", 1]}), "time")
	assert_eq(CoreIntelQuery.canonical_key({"era": "classical"}), "era")
	assert_eq(CoreIntelQuery.canonical_key({"has": "token"}), "has")


func test_unknown_key_has_no_canonical_form() -> void:
	assert_eq(CoreIntelQuery.canonical_key({"nonsense": 1}), "",
		"an unrecognised key must not masquerade as valid")
	assert_eq(CoreIntelQuery.canonical_key({}), "")


func test_value_for_accepts_either_spelling() -> void:
	assert_eq(CoreIntelQuery.value_for({"faction_flag": "met"}, "holder_flag"),
		"met", "legacy spelling yields the same value")
	assert_eq(CoreIntelQuery.value_for({"holder_flag": "met"}, "holder_flag"),
		"met", "canonical spelling yields the same value")
	assert_eq(CoreIntelQuery.value_for({"turn": [">=", 5]}, "time"), [">=", 5])


func test_era_is_a_known_key() -> void:
	assert_true("era" in CoreIntelQuery.KEYS,
		"era must be in KEYS or {\"era\": ...} silently evaluates false")


func test_shape_check_accepts_legacy_spellings() -> void:
	# Authored data in aevum, paragon and example_realm_iso uses faction_flag;
	# it must keep validating.
	assert_true(CoreIntelQuery.is_valid_shape({"faction_flag": "met_elders"}))
	assert_true(CoreIntelQuery.is_valid_shape({"turn": [">=", 10]}))
	assert_true(CoreIntelQuery.is_valid_shape({"era": "classical"}))


func test_shape_check_still_rejects_nonsense() -> void:
	assert_false(CoreIntelQuery.is_valid_shape({"not_a_key": true}),
		"accepting aliases must not make the shape check permissive")


func test_shape_check_handles_nesting() -> void:
	assert_true(CoreIntelQuery.is_valid_shape(
		{"all": [{"faction_flag": "a"}, {"not": {"turn": [">=", 3]}}]}),
		"aliases must resolve inside all/any/not too")


func test_aliases_do_not_collide_with_canonical_keys() -> void:
	for legacy in CoreIntelQuery.ALIASES:
		assert_false(legacy in CoreIntelQuery.KEYS,
			"'%s' cannot be both an alias and a canonical key" % legacy)
		assert_true(String(CoreIntelQuery.ALIASES[legacy]) in CoreIntelQuery.KEYS,
			"alias '%s' must point at a real key" % legacy)
